# Informe de carga masiva

## Orden de carga

El orden respeta las dependencias de las claves foráneas:

```text
Localidad, Cepa, Maridaje
        |
        +--> Bodega
        +--> Sala_Venta --> Empleado, Encargado
        +--> Finca --> Parcela --> Lote --> Analisis_Calidad
        +--> Transportista --> Transportista_Telefono
        |                  --> Transportista_Localidad
        +--> Vino --> Composicion, Vino_Maridaje
        +--> Cliente --> Socio, Distribuidor, Exportador
        |                         --> Permiso_Exportacion
        +--> Deposito_Central --> Stock_Deposito
        +--> Ingreso --> Ingreso_Vino
        +--> Transferencia --> Transferencia_Vino
        +--> Comprobante --> Detalle_Comprobante
```

Los catálogos se leen desde `catalogos/*.csv`. Bodegas, fincas, clientes,
movimientos y comprobantes se generan con Faker y `random`, usando la semilla
`20261108` por defecto.

## Volúmenes por defecto

| Grupo | Filas |
|---|---:|
| Localidad, Cepa, Maridaje | 24, 12, 8 |
| Bodega, Transportista | 20, 30 |
| Sala de venta, Finca, Empleado | 30, 50, 60 |
| Parcela, Vino, Composición, Vino-Maridaje | 1.000, 500, 500, 500 |
| Stock de depósito | 500 |
| Ingreso, Transferencia | 5.000, 5.000 |
| Lote, Análisis de calidad | 5.000, 5.000 |
| Cliente | 20.000 |
| Comprobante | 150.000 |
| Renglón de comprobante | 600.000 |

## Triggers y controles

Durante la carga histórica se deshabilitan únicamente los triggers de usuario
de las tablas de hechos. Las claves foráneas y restricciones `CHECK` siguen
activas. Un bloque `finally` vuelve a habilitar los triggers incluso si ocurre
un error. Luego se ejecuta `controles.sql`, que verifica huérfanos, stocks
negativos, porcentajes de composición, totales de comprobantes, descuentos
por tipo de cliente y subtotales de renglón.

El riesgo es que los triggers de venta no recalculan datos históricos; por eso
el generador hace el mismo cálculo que la base y los controles deben devolver
cero inconsistencias:

- el precio de cada renglón es el precio del vino;
- el descuento de cada renglón es el del tipo de cliente (socio 10 %,
  distribuidor 20 %, exportador 30 %, RN-06);
- `subtotal_renglon = cantidad × precio × (1 − descuento / 100)`;
- el total del comprobante es la suma de los renglones (`fn_total_comprobante`,
  RN-08), el subtotal es la suma sin descuento y `descuento = subtotal − total`.

Para que las consultas de la etapa 5 tengan resultados:

- los comprobantes cubren los últimos 7 años hasta hoy: hay ventas de la última
  semana (S3) y de más de 5 años (D1);
- unos vinos se venden mucho más que otros (U5, S1, S11) y el 40 % de los vinos
  solo se vende en una de cada tres salas (S2);
- 1 de cada 20 clientes nunca compró (D4, D6);
- la última cepa del catálogo no se planta ni compone vinos (D2);
- los ingresos cubren los últimos 2 años, con los tres estados y transportistas
  con actividad desigual (I1, S7, D5); las transferencias cubren el último año
  con los tres estados (S4, S5);
- los lotes cubren las últimas 5 campañas, con cosecha entre febrero y abril, y
  cada parcela se cosecha una vez por campaña (RN-04);
- cada exportador tiene de 1 a 5 permisos (U6) y la antigüedad de los
  empleados varía entre 0 y 14 años (U2).

## Reproducibilidad y rendimiento

Para repetir la misma carga se usa el mismo `--seed` sobre una base vacía.
Las fechas recientes (comprobantes y campañas) se calculan desde el día de la
carga, porque las consultas usan `CURRENT_DATE`.
`medir_carga.py` compara `executemany` fila a fila con `COPY` y registra los
tiempos en la salida estándar. Los resultados deben copiarse a esta sección
después de ejecutar la medición en la base del equipo.

## Volcado

Después de cargar y validar:

```bash
pg_dump "$DATABASE_URL" --format=plain --no-owner --file=dump_completo.sql
gzip -f dump_completo.sql
```

El archivo resultante `dump_completo.sql.gz` puede restaurarse con:

```bash
gunzip -c dump_completo.sql.gz | psql "$DATABASE_URL"
```

## Verificación ejecutada

Se ejecutó una carga de prueba contra PostgreSQL con 30 clientes, 20
comprobantes y 80 renglones. `controles.sql` devolvió cero en:

- vinos sin bodega;
- stock negativo en depósito o sala;
- detalles sin comprobante;
- totales de comprobante inconsistentes;
- composiciones cuyo porcentaje no suma 100.

La comparación real con 10.000 filas fue:

| Método | Tiempo |
|---|---:|
| `executemany` | 1,894922 s |
| `COPY` | 0,067480 s |
| Mejora | 28,08x |

El dump generado fue validado con `gzip -t` y permanece ignorado por Git.
La ejecución de escala completa debe realizarse sobre una base vacía, porque
el cargador inserta los catálogos y no debe duplicarlos.

## Pruebas de reglas de negocio

Con la base inicializada, con o sin la carga masiva, se ejecuta con el rol
propietario:

```bash
docker compose cp tests/db_tests.sql db:/tmp/db_tests.sql
docker compose exec db sh -c 'psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f /tmp/db_tests.sql'
```

La suite crea sus propios datos de prueba dentro de una transacción, valida
RN-01 a RN-15, informa `PASS` para cada regla y hace `ROLLBACK` al finalizar.
La ejecución verificada produjo 15/15 reglas aprobadas, tanto en una base vacía
como después de la carga completa.
