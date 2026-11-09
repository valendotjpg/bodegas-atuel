# Demostración de concurrencia: la última botella

Dos sesiones intentan vender al mismo tiempo la última botella de un vino en
una sala. Se muestra qué pasa sin bloqueo, con `SELECT ... FOR UPDATE` y con el
camino real del sistema (el trigger de venta), y se justifica el nivel de
aislamiento.

Las dos sesiones se conectan con el rol de la API (`bodegas_api`), igual que lo
hará la aplicación.

## Preparación

Con la base levantada (`docker compose up -d`), cargar el escenario. Deja el
vino «Demo Ultima Botella» con **1 botella** en la «Sala Demo» y un comprobante
abierto para cada cliente (A y B). Se puede correr antes de cada escenario para
volver a dejar el stock en 1.

```bash
docker compose exec -T db sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"' < docs/etapa2_concurrencia/preparar.sql
```

Abrir dos terminales, una para cada sesión:

```bash
docker compose exec db sh -c 'psql -U "$API_DB_USER" -d "$POSTGRES_DB"'
```

En cada una, cargar los IDs en variables de psql. En la sesión B, cambiar
`Cliente Demo A` por `Cliente Demo B`:

```sql
SELECT s.id_sala, v.cod_vino, (SELECT max(nro_comprobante) FROM Comprobante c JOIN Cliente cl USING (id_cliente) WHERE cl.razon_social = 'Cliente Demo A') AS comp FROM Sala_Venta s, Vino v WHERE s.calle = 'Sala Demo' AND v.nombre_comercial = 'Demo Ultima Botella' \gset
\timing on
```

Los pasos se ejecutan en el orden numerado, alternando entre A y B.

## Escenario 1: sin bloqueo

La aplicación lee el stock, decide que alcanza y escribe el valor que calculó.

| Paso | Sesión A | Sesión B |
|---|---|---|
| 1 | `BEGIN;` | |
| 2 | `SELECT cantidad FROM Sala_Venta_Vino WHERE id_sala = :id_sala AND cod_vino = :cod_vino \gset` | |
| 3 | | `BEGIN;` |
| 4 | | `SELECT cantidad FROM Sala_Venta_Vino WHERE id_sala = :id_sala AND cod_vino = :cod_vino \gset` |
| 5 | `UPDATE Sala_Venta_Vino SET cantidad = :cantidad - 1 WHERE id_sala = :id_sala AND cod_vino = :cod_vino;` | |
| 6 | `COMMIT;` | |
| 7 | | `UPDATE Sala_Venta_Vino SET cantidad = :cantidad - 1 WHERE id_sala = :id_sala AND cod_vino = :cod_vino;` |
| 8 | | `COMMIT;` |

Resultado obtenido:

```
[A] SELECT cantidad ...                         -> 1
[B] SELECT cantidad ...                         -> 1
[A] UPDATE ... SET cantidad = 1 - 1 ...         -> UPDATE 1
[A] COMMIT;
[B] UPDATE ... SET cantidad = 1 - 1 ...         -> UPDATE 1
[B] COMMIT;
stock final: 0
```

**Las dos sesiones vendieron la misma botella.** Es una actualización perdida
(*lost update*): las dos leyeron 1 antes de que la otra escribiera, y la base
no tiene forma de saber que el valor que escribe B se calculó con un dato
viejo. El CHECK `cantidad >= 0` no lo detecta, porque el valor escrito (0) es
válido.

Si en lugar del valor calculado se escribe `cantidad = cantidad - 1`, B espera
a que A confirme y después falla por el CHECK:

```
[B] UPDATE ... SET cantidad = cantidad - 1 ...  (espera 2,0 s)
ERROR:  new row for relation "sala_venta_vino" violates check constraint "check_cantidad_sala"
DETAIL:  Failing row contains (1, 1, -1).
```

El CHECK evita el stock negativo, pero recién en el último paso y con un
mensaje que no le sirve al usuario: la aplicación ya había decidido que la
venta era posible.

## Escenario 2: con `SELECT ... FOR UPDATE`

| Paso | Sesión A | Sesión B |
|---|---|---|
| 1 | `BEGIN;` | |
| 2 | `SELECT cantidad FROM Sala_Venta_Vino WHERE id_sala = :id_sala AND cod_vino = :cod_vino FOR UPDATE;` | |
| 3 | | `BEGIN;` |
| 4 | | `SELECT cantidad FROM Sala_Venta_Vino WHERE id_sala = :id_sala AND cod_vino = :cod_vino FOR UPDATE;` (queda esperando) |
| 5 | `UPDATE Sala_Venta_Vino SET cantidad = cantidad - 1 WHERE id_sala = :id_sala AND cod_vino = :cod_vino;` | |
| 6 | `COMMIT;` | (se libera y devuelve 0) |
| 7 | | `ROLLBACK;` |

Resultado obtenido:

```
[A] SELECT cantidad ... FOR UPDATE              -> 1
[B] SELECT cantidad ... FOR UPDATE              -> (espera 1,9 s) 0
stock final: 0
```

`FOR UPDATE` bloquea la fila de stock hasta el final de la transacción de A.
B no puede leerla para modificarla hasta que A confirme, y cuando la lee ya ve
el valor nuevo: no hay stock y no vende. **Se vende una sola botella.**

## Escenario 3: el sistema real

El trigger `trg_detalle_validar` (005, RN-09) hace exactamente el escenario 2:
bloquea la fila de stock con `FOR UPDATE` antes de validar. La aplicación solo
inserta el renglón; precio, descuento, stock y totales los resuelve la base.

| Paso | Sesión A | Sesión B |
|---|---|---|
| 1 | `BEGIN;` | |
| 2 | `INSERT INTO Detalle_Comprobante (nro_comprobante, cod_vino, cantidad) VALUES (:comp, :cod_vino, 1);` | |
| 3 | | `INSERT INTO Detalle_Comprobante (nro_comprobante, cod_vino, cantidad) VALUES (:comp, :cod_vino, 1);` (queda esperando) |
| 4 | `COMMIT;` | (se libera y falla) |

Resultado obtenido:

```
[A] INSERT INTO Detalle_Comprobante ...         -> INSERT 0 1
[B] INSERT INTO Detalle_Comprobante ...         (espera 2,1 s)
ERROR:  Stock insuficiente del vino 1 en la sala 1: hay 0, se piden 1 (RN-09)
stock final: 0

 nro_comprobante |  razon_social  |  total
-----------------+----------------+----------
              10 | Cliente Demo B |     0.00
               9 | Cliente Demo A | 45000.00
```

A vende la botella (total con el 10 % de socio) y B recibe un error claro, que
la API puede traducir a una respuesta HTTP. El comprobante de B queda sin
renglones y el stock nunca es negativo.

## Nivel de aislamiento

Se usa **READ COMMITTED**, el nivel por defecto de PostgreSQL
(`SHOW transaction_isolation;` devuelve `read committed`).

En READ COMMITTED cada sentencia ve los datos confirmados al momento de
empezar. Eso, solo, permite el escenario 1: las dos sesiones leen 1. Con
`FOR UPDATE`, cuando B consigue el bloqueo, PostgreSQL vuelve a leer la última
versión confirmada de la fila, por eso B ve 0 y no vende.

Con **REPEATABLE READ** y sin `FOR UPDATE`, B trabaja sobre la foto del
comienzo de su transacción. Cuando intenta modificar una fila que A cambió y
confirmó, PostgreSQL aborta la transacción:

```
[B] BEGIN ISOLATION LEVEL REPEATABLE READ;
[B] SELECT cantidad ...                         -> 1
[B] UPDATE ... SET cantidad = cantidad - 1 ...  (espera 1,8 s)
ERROR:  could not serialize access due to concurrent update
```

También es correcto, pero obliga a la aplicación a reintentar toda la
transacción, y el error no dice nada sobre el stock. Por eso se eligió READ
COMMITTED con `FOR UPDATE` dentro del trigger:
- no hace falta reintentar;
- el error explica el motivo;
- la protección está en la base, así que vale para cualquier cliente (API, psql, carga).

## Capturas

| Archivo | Qué muestra |
|---|---|
| `capturas/1_sin_bloqueo.png` | Escenario 1: las dos sesiones venden la misma botella |
| `capturas/2_for_update.png` | Escenario 2: B espera y lee 0 |
| `capturas/3_trigger_venta.png` | Escenario 3: B recibe «Stock insuficiente» |
| `capturas/4_repeatable_read.png` | REPEATABLE READ: error de serialización |
