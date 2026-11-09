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
| Parcela, Vino, Composición, Vino-Maridaje | 500, 500, 500, 500 |
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
negativos, porcentajes de composición y totales de comprobantes.

El riesgo es que los triggers de venta no recalculan datos históricos; por eso
el generador calcula previamente subtotales, descuentos y stocks y los
controles deben devolver cero inconsistencias.

## Reproducibilidad y rendimiento

Para repetir la misma carga se usa el mismo `--seed` sobre una base vacía.
`medir_carga.py` compara `executemany` fila a fila con `COPY` y registra los
tiempos en la salida estándar. Los resultados deben copiarse a esta sección
después de ejecutar la medición en la base del equipo.

## Volcado

Para cargar los datos usamos:
python db/seed/generar.py --dsn "postgresql://bodegas_owner:TU_CLAVE@localhost:5432/bodegas"

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
