# Demostración de concurrencia: la última botella

Dos sesiones intentan vender al mismo tiempo la última botella de un vino en
una sala. Se muestra qué pasa sin bloqueo, con `SELECT ... FOR UPDATE` y con el
camino real del sistema (el trigger de venta), y se justifica el nivel de
aislamiento.

Las dos sesiones se conectan con el rol de la API (`bodegas_api`), igual que lo
hará la aplicación.

## Antes de empezar

**1. Levantar la base y cargar el escenario.** Deja el vino «Demo Ultima
Botella» con **1 botella** en la «Sala Demo» y un comprobante abierto para cada
cliente. Hay que correrlo de nuevo **antes de cada escenario**, para volver a
dejar el stock en 1.

```bash
docker compose up -d
docker compose cp docs/etapa2_concurrencia/preparar.sql db:/tmp/preparar.sql
docker compose exec db sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f /tmp/preparar.sql'
```

Funciona igual en PowerShell, CMD y Git Bash. Para repetirlo antes de cada
escenario alcanza con el último comando.

Tiene que mostrar `stock = 1`.

**2. Abrir dos terminales lado a lado**, que llamamos **Terminal A** y
**Terminal B**. En cada una, conectarse a la base:

```bash
docker compose exec db sh -c 'psql -U "$API_DB_USER" -d "$POSTGRES_DB"'
```

**3. Cargar los IDs del escenario.** Pegar esto en cada terminal: queda
guardado en variables (`:id_sala`, `:cod_vino`, `:comp`) que se usan en los
pasos.

En la **Terminal A**:

```sql
SELECT s.id_sala, v.cod_vino, (SELECT max(nro_comprobante) FROM Comprobante c JOIN Cliente cl USING (id_cliente) WHERE cl.razon_social = 'Cliente Demo A') AS comp FROM Sala_Venta s, Vino v WHERE s.calle = 'Sala Demo' AND v.nombre_comercial = 'Demo Ultima Botella' \gset
\timing on
```

En la **Terminal B** (cambia solo el cliente):

```sql
SELECT s.id_sala, v.cod_vino, (SELECT max(nro_comprobante) FROM Comprobante c JOIN Cliente cl USING (id_cliente) WHERE cl.razon_social = 'Cliente Demo B') AS comp FROM Sala_Venta s, Vino v WHERE s.calle = 'Sala Demo' AND v.nombre_comercial = 'Demo Ultima Botella' \gset
\timing on
```

`\timing on` hace que psql muestre cuánto tardó cada comando; así se ve cuánto
esperó una sesión a la otra.

En cada escenario, seguir los pasos **en orden**, cada uno en la terminal que
indica.

---

## Escenario 1: sin bloqueo

La aplicación lee el stock, decide que alcanza y después escribe el valor que
calculó.

**Paso 1 · Terminal A:** empezar la venta y leer el stock.

```sql
BEGIN;
SELECT cantidad FROM Sala_Venta_Vino WHERE id_sala = :id_sala AND cod_vino = :cod_vino \gset
```

No muestra nada en pantalla: `\gset` guarda el stock leído (1) en la variable
`:cantidad`, como haría la aplicación en memoria.

**Paso 2 · Terminal B:** lo mismo. También lee 1, porque A todavía no escribió.

```sql
BEGIN;
SELECT cantidad FROM Sala_Venta_Vino WHERE id_sala = :id_sala AND cod_vino = :cod_vino \gset
```

**Paso 3 · Terminal A:** guardar el stock calculado (1 − 1) y confirmar.

```sql
UPDATE Sala_Venta_Vino SET cantidad = :cantidad - 1 WHERE id_sala = :id_sala AND cod_vino = :cod_vino;
COMMIT;
```

**Paso 4 · Terminal B:** lo mismo, con el 1 que había leído.

```sql
UPDATE Sala_Venta_Vino SET cantidad = :cantidad - 1 WHERE id_sala = :id_sala AND cod_vino = :cod_vino;
COMMIT;
```

**Qué pasa:** los dos `UPDATE` responden `UPDATE 1` y el stock queda en 0.

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

**Variante:** si en el paso 3 y en el 4 se escribe
`SET cantidad = cantidad - 1` en lugar del valor calculado, B espera a que A
confirme y después falla por el CHECK:

```
[B] UPDATE ... SET cantidad = cantidad - 1 ...  (espera 2,0 s)
ERROR:  new row for relation "sala_venta_vino" violates check constraint "check_cantidad_sala"
DETAIL:  Failing row contains (1, 1, -1).
```

El CHECK evita el stock negativo, pero recién en el último paso y con un
mensaje que no le sirve al usuario: la aplicación ya había decidido que la
venta era posible.

---

## Escenario 2: con `SELECT ... FOR UPDATE`

Correr de nuevo `preparar.sql` (ver «Antes de empezar», paso 1).

**Paso 1 · Terminal A:** empezar la venta y leer el stock **bloqueando la fila**.

```sql
BEGIN;
SELECT cantidad FROM Sala_Venta_Vino WHERE id_sala = :id_sala AND cod_vino = :cod_vino FOR UPDATE;
```

Devuelve 1.

**Paso 2 · Terminal B:** intentar lo mismo.

```sql
BEGIN;
SELECT cantidad FROM Sala_Venta_Vino WHERE id_sala = :id_sala AND cod_vino = :cod_vino FOR UPDATE;
```

**Se queda esperando**, sin devolver nada: A tiene la fila bloqueada.

**Paso 3 · Terminal A:** descontar la botella y confirmar.

```sql
UPDATE Sala_Venta_Vino SET cantidad = cantidad - 1 WHERE id_sala = :id_sala AND cod_vino = :cod_vino;
COMMIT;
```

**Paso 4 · Terminal B:** apenas A confirma, el `SELECT` de B se destraba y
devuelve **0**. No hay stock, así que no vende:

```sql
ROLLBACK;
```

**Qué pasa:**

```
[A] SELECT cantidad ... FOR UPDATE              -> 1
[B] SELECT cantidad ... FOR UPDATE              -> (espera 1,9 s) 0
stock final: 0
```

`FOR UPDATE` bloquea la fila de stock hasta el final de la transacción de A.
B no puede leerla para modificarla hasta que A confirme, y cuando la lee ya ve
el valor nuevo. **Se vende una sola botella.**

---

## Escenario 3: el sistema real

El trigger `trg_detalle_validar` (005, RN-09) hace exactamente el escenario 2:
bloquea la fila de stock con `FOR UPDATE` antes de validar. La aplicación solo
inserta el renglón de la venta; precio, descuento, stock y totales los resuelve
la base.

Correr de nuevo `preparar.sql`.

**Paso 1 · Terminal A:** vender la botella, sin confirmar todavía.

```sql
BEGIN;
INSERT INTO Detalle_Comprobante (nro_comprobante, cod_vino, cantidad) VALUES (:comp, :cod_vino, 1);
```

**Paso 2 · Terminal B:** intentar vender la misma botella.

```sql
INSERT INTO Detalle_Comprobante (nro_comprobante, cod_vino, cantidad) VALUES (:comp, :cod_vino, 1);
```

**Se queda esperando.**

**Paso 3 · Terminal A:** confirmar la venta.

```sql
COMMIT;
```

Apenas A confirma, B se destraba y **falla** con un mensaje claro.

**Qué pasa:**

```
[A] INSERT INTO Detalle_Comprobante ...         -> INSERT 0 1
[B] INSERT INTO Detalle_Comprobante ...         (espera 2,1 s)
ERROR:  Stock insuficiente del vino 1 en la sala 1: hay 0, se piden 1 (RN-09)
stock final: 0
```

Para ver cómo quedaron los dos comprobantes (en cualquier terminal):

```sql
SELECT c.nro_comprobante, cl.razon_social, c.total FROM Comprobante c JOIN Cliente cl USING (id_cliente) WHERE cl.razon_social LIKE 'Cliente Demo%' ORDER BY 1 DESC LIMIT 2;
```

```
 nro_comprobante |  razon_social  |  total
-----------------+----------------+----------
              10 | Cliente Demo B |     0.00
               9 | Cliente Demo A | 45000.00
```

A vende la botella (total con el 10 % de socio) y B recibe un error que la API
puede traducir a una respuesta HTTP. El comprobante de B queda sin renglones y
el stock nunca es negativo.

---

## Escenario 4: REPEATABLE READ en lugar de FOR UPDATE

Sirve para justificar el nivel de aislamiento. Correr de nuevo `preparar.sql`.

**Paso 1 · Terminal A:** descontar la botella, sin confirmar todavía.

```sql
BEGIN;
UPDATE Sala_Venta_Vino SET cantidad = cantidad - 1 WHERE id_sala = :id_sala AND cod_vino = :cod_vino;
```

**Paso 2 · Terminal B:** empezar en REPEATABLE READ, leer y descontar.

```sql
BEGIN ISOLATION LEVEL REPEATABLE READ;
SELECT cantidad FROM Sala_Venta_Vino WHERE id_sala = :id_sala AND cod_vino = :cod_vino;
UPDATE Sala_Venta_Vino SET cantidad = cantidad - 1 WHERE id_sala = :id_sala AND cod_vino = :cod_vino;
```

El `SELECT` devuelve 1 y el `UPDATE` **se queda esperando**.

**Paso 3 · Terminal A:** confirmar.

```sql
COMMIT;
```

**Paso 4 · Terminal B:** el `UPDATE` falla. Cerrar la transacción:

```sql
ROLLBACK;
```

**Qué pasa:**

```
[B] SELECT cantidad ...                         -> 1
[B] UPDATE ... SET cantidad = cantidad - 1 ...  (espera 1,8 s)
ERROR:  could not serialize access due to concurrent update
```

---

## Nivel de aislamiento

Se usa **READ COMMITTED**, el nivel por defecto de PostgreSQL
(`SHOW transaction_isolation;` devuelve `read committed`).

En READ COMMITTED cada sentencia ve los datos confirmados al momento de
empezar. Eso, solo, permite el escenario 1: las dos sesiones leen 1. Con
`FOR UPDATE`, cuando B consigue el bloqueo, PostgreSQL vuelve a leer la última
versión confirmada de la fila, por eso B ve 0 y no vende.

En REPEATABLE READ (escenario 4), B trabaja sobre la foto del comienzo de su
transacción. Cuando intenta modificar una fila que A cambió y confirmó,
PostgreSQL aborta la transacción. También evita vender dos veces, pero obliga
a la aplicación a reintentar toda la transacción, y el error no dice nada sobre
el stock.

Por eso se eligió READ COMMITTED con `FOR UPDATE` dentro del trigger:
- no hace falta reintentar;
- el error explica el motivo;
- la protección está en la base, así que vale para cualquier cliente (API, psql, carga).

## Capturas

Una por escenario, con las dos terminales visibles después del último paso:

| Archivo | Qué tiene que verse |
|---|---|
| `capturas/1_sin_bloqueo.png` | Los dos `UPDATE 1` |
| `capturas/2_for_update.png` | B devolviendo 0 después de esperar |
| `capturas/3_trigger_venta.png` | El error «Stock insuficiente» en B |
| `capturas/4_repeatable_read.png` | El error de serialización en B |
