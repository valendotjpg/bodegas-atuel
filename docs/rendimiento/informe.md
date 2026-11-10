# Etapa 4 — Índices y rendimiento

Informe consolidado. La evidencia cruda (salidas `EXPLAIN (ANALYZE, BUFFERS)`
antes y después de cada índice, la tabla comparativa y las mediciones de costo
de escritura) está en este mismo directorio; los índices creados quedaron
en `db/migrations/008_indices.sql`. La tabla que alimenta el cálculo es
`comprobante` (150.000 filas) y `detalle_comprobante` (600.000 filas
en el dataset local completo).

## 1. Método

1. Se corrió `ANALYZE` y se midió cada consulta con
   `EXPLAIN (ANALYZE, BUFFERS)` dejando solo los índices de PK y UNIQUE
   (`*_antes.txt` muestra el listado de índices del momento).
2. Se creó el índice candidato y se volvió a medir (`*_despues.txt`).
3. Se registró en `Tabla comparativa(Sheet1).csv`: tiempo antes/después,
   tipo de recorrido (Seq Scan / Index Scan / Index Only Scan), filas leídas
   de la tabla y buffers.

## 2. Índices creados (los 5 tipos pedidos)

| Índice | Tipo pedido | Qué resuelve | Justificación |
|---|---|---|---|
| `idx_ventas_trimestre ON comprobante (fecha) INCLUDE (id_sala, total)` | otra variante (INCLUDE / Index Only Scan) | S8 | un solo rango sobre `fecha`; los INCLUDE hacen que la respuesta salga del índice sin tocar la tabla (1.246 → 28 buffers) |
| `idx_comprobante_sala_fecha ON comprobante (id_sala, fecha) INCLUDE (id_cliente)` | compuesto | S3 | igualdad primero (`id_sala`), rango después (`fecha`): el orden importa; INCLUDE de `id_cliente` evita el heap (6,99 → 0,48 ms) |
| `idx_detalle_vino ON detalle_comprobante (cod_vino) INCLUDE (nro_comprobante)` | sobre clave foránea | S12 | PostgreSQL no indexa FKs automáticamente; la PK de renglones empieza por `nro_comprobante` y no sirve para buscar por vino (27,8 → 6,31 ms en la parte (a)) |
| `idx_transferencia_vino ON transferencia_vino (cod_vino) INCLUDE (nro_solicitud, cantidad)` | sobre clave foránea | S4 | misma razón que el anterior sobre el renglón de transferencias (Seq Scan → Index Only Scan) |
| `idx_transferencia_pendientes ON transferencia (id_sala) WHERE estado <> 'procesado'` | parcial | S5 y vista `v_documentos_pendientes` | solo indexa lo pendiente (~30 % más chico que un índice completo); el predicado es constante, no usa `CURRENT_DATE` (no rompería la restauración de un backup) |

## 3. Tabla comparativa antes / después

| Consulta | Índice | Antes | Después | Mejora | Recorrido | Filas de tabla | Buffers |
|---|---|---|---|---|---|---|---|
| S8 ventas por sala, último trimestre | `idx_ventas_trimestre` | 7,77 ms | 1,22 ms | **6,4x** | Parallel Seq → Index Only | 150.000 → 5.487 | 1.246 → 28 |
| S3 clientes por tipo, sala y semana | `idx_comprobante_sala_fecha` | 6,99 ms | 0,48 ms | **14,5x** | Parallel Seq → Index Only | 150.000 → 20 | 1.331 → 92 |
| S12 (a) compraron todos los vinos de una bodega | `idx_detalle_vino` | 27,8 ms | 6,31 ms | **4,4x** | Parallel Seq → Index Only | 600.000 → 528 | 6.901 → 2.389 |
| S12 (b) nunca compraron vino tinto | `idx_detalle_vino` | 155,5 ms | 93,0 ms | 1,7x | Seq → Index Only (x120) | 600.000 → 141.248 | 5.908 → 2.238 |
| S9 ficha de un vino | (`idx_vino_nombre`) | 2,08 ms | 2,11 ms | sin cambio | Index Scan (`unique_nombre`) | 1 → 1 | 93 → 93 |
| S10 rendimiento por parcela | (`idx_rendimiento_parcela`) | 933,7 ms | 929,2 ms | sin cambio | Seq Scan sobre lote + CTE | 5.000 → 5.000 | 49 → 49 |

Criterio superado: 4 consultas con mejora medida (el mínimo eran 3) más 2
sin cambio, que se documentan igual porque también enseñan algo (párrafo 5).

## 4. Índices evaluados y descartados

Quedan en `indices_descartados.sql` (NO van en la migración):

1. **`idx_vino_nombre_comercial ON vino (nombre_comercial)`** — S9. Duplica el
   índice que ya crea `unique_nombre (nombre_comercial, anada, volumen_ml)`:
   el tiempo no cambia (2,08 vs 2,11 ms) y solo cuesta escritura. Lección:
   antes de indexar, buscar si un UNIQUE que ya existe deja de servir el plan.
2. **`idx_rendimiento_parcela ON lote (id_finca, campania) INCLUDE (kilos, nro_parcela)`** — S10.
   Sin cambio (933,7 vs 929,2 ms): la CTE se materializa y las subconsultas
   correlacionadas recorren la CTE, no la tabla `lote`, así que el índice nunca
   se usa. Es además el caso de «índice existente que el planificador no usa».

## 5. Caso en que el planificador no usa el índice

El parcial `idx_transferencia_pendientes` es el ejemplo pedido: con la carga por
defecto `transferencia` tiene 5.000 filas en 32 páginas, y el planificador
prefiere el Seq Scan completo antes que un Index Scan de baja selectividad,
donde recorrer un índice que resuelve las filas pendientes no achica el trabajo.
El índice empieza a pagar cuando la tabla crece y lo pendiente es una fracción
menor. (Análogo en S12 (b): la mejora fue solo 1,7x porque el anti-join le
quedan 141.248 filas — la selectividad sigue siendo baja).

## 6. Costo de escritura

Medido con `costo_escritura.sql` (INSERT masivo de las mismas filas con y sin
índices secundarios; salida en `costo_escritura.txt` y `Costo escritura.csv`):

| Tabla | Filas | Sin índices | Con índices | Sobrecosto | Extra por fila |
|---|---|---|---|---|---|
| `comprobante` (2 índices) | 150.000 | 402 ms | 729 ms | +327 ms (+81 %) | ~2,2 µs |
| `detalle_comprobante` (1 índice) | 600.000 | 1.317 ms | 2.102 ms | +785 ms (+60 %) | ~1,3 µs |

Tamaño en disco: `idx_detalle_vino` 13 MB; los dos de `comprobante` ~9,1 MB.
Conclusión práctica: los índices suman un costo de escritura barato por fila y
devuelven ganancias de 4x–14x en lectura; se justifican, pero hay que
elegirlos mirando el plan (no indexar «por si acaso»: ver los 2 descartados).

## 7. Criterios del enunciado — checklist

- ☑ 5 índices en `008_indices.sql`, con los tipos pedidos y justificados.
- ☑ 4 consultas mejoradas y 2 sin cambio documentadas (mínimo pedido: 3).
- ☑ Tabla comparativa con recorrido y buffers.
- ☑ El orden de columnas del compuesto justificado (igualdad antes que rango).
- ☑ Índices descartados con explicación.
- ☑ Costo de escritura medido.
- ☑ Caso en que el planificador no usa un índice existente (parcial).
