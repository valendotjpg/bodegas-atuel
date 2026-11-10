# Informe final — Bodegas del Atuel

TPI de Bases de Datos, UTN FRSR, Ingeniería en Sistemas, ciclo 2026. Grupo N.° 7:
Mansalve Augusto, Praderio Valentín, Quiroga Constanza.

Este informe sigue la estructura de la sección 10.2 del enunciado. Junta los
informes parciales de cada etapa y enlaza a ellos para el detalle; los números
que aparecen acá salen de esos informes y de su evidencia.

- Repositorio: <https://github.com/valendotjpg/bodegas-atuel>
- Versión en la nube: <https://bodegas-atuel.onrender.com>

---

## 1. Introducción y alcance

Bodegas del Atuel es una empresa vitivinícola con fincas propias, bodegas
elaboradoras, un depósito central y una red de salas de venta. El sistema cubre:

- **Producción:** fincas, parcelas plantadas con una cepa, lotes de cosecha por
  campaña y sus análisis de calidad.
- **Productos:** vinos con su bodega, composición por cepas (corte) y maridajes.
- **Logística:** ingresos de vino al depósito con un transportista y
  transferencias del depósito a las salas, cada uno con su ciclo de estados.
- **Ventas:** clientes socios, distribuidores y exportadores, comprobantes con
  renglones, descuentos por tipo de cliente y control de stock por sala.

El trabajo se hizo en nueve etapas: modelado, integridad y lógica en la base,
carga masiva, índices, consultas SQL, API REST, front, despliegue en la nube y
documentación. Todo el acceso a datos es SQL escrito por el grupo, sin ORM.

**Tecnologías:** PostgreSQL 16 (local, en Docker) y 18 (Neon), Python con
FastAPI y psycopg 3, React con Vite, Docker Compose, Render.

**Idea central del diseño:** las reglas de negocio viven en la base. La API y
el front no calculan totales, descuentos ni stock: los piden a la base y
muestran lo que devuelve. Así la regla vale igual para la API, para `psql` y
para cualquier otro cliente.

---

## 2. Modelo de datos

Documentación de la etapa 1, en [`etapa1_documentacion/`](etapa1_documentacion):

- [DER integrado](<etapa1_documentacion/DER Integrado.png>) y el DER por área:
  [localidades y salas](etapa1_documentacion/1_Localidades_Salas.drawio.png),
  [bodegas y vinos](etapa1_documentacion/2_Bodegas_Vinos.drawio.png),
  [fincas y lotes](etapa1_documentacion/3_Fincas_Lotes.drawio.png),
  [clientes y ventas](etapa1_documentacion/4_Clientes_Ventas.drawio.png),
  [stock y movimientos](etapa1_documentacion/5_Stock_Movimientos.drawio.png).
- [Esquema relacional](etapa1_documentacion/Esquema_Relacional.drawio.png).
- [Diccionario de datos](etapa1_documentacion/Diccionario_de_datos.md):
  campos, tipos, claves, nulos, referencias y restricciones de cada tabla.
- [Normalización y decisiones de diseño](etapa1_documentacion/Normalizacion_y_decisiones.md):
  análisis 1FN a 3FN tabla por tabla, alternativas descartadas y acciones
  referenciales. Lo que sigue es un resumen.

![DER integrado](<etapa1_documentacion/DER Integrado.png>)

### Entidades

El esquema físico (`db/migrations/001_esquema.sql`) tiene **32 tablas**:

| Área | Tablas |
|---|---|
| Geografía y salas | `Localidad`, `Encargado`, `Sala_Venta`, `Empleado`, `Sala_Venta_Vino` (stock por sala) |
| Producción | `Finca`, `Parcela`, `Cepa`, `Lote`, `Analisis_Calidad` |
| Productos | `Bodega`, `Vino`, `Composicion`, `Maridaje`, `Vino_Maridaje` |
| Clientes | `Cliente`, `Socio`, `Distribuidor`, `Exportador`, `Permiso_exportacion` |
| Ventas | `Comprobante`, `Detalle_Comprobante` |
| Logística | `Transportista`, `Transportista_Telefono`, `Transportista_Localidad`, `Deposito_Central`, `Stock_Deposito`, `Ingreso`, `Ingreso_Vino`, `Transferencia`, `Transferencia_Vino` |
| Control | `Auditoria` |

### Decisiones de diseño

- **Jerarquía de clientes** con una tabla por subtipo (`Socio`, `Distribuidor`,
  `Exportador`) que comparte la PK de `Cliente`. Cada subtipo guarda su
  `porcentaje_descuento` (DEFAULT 10, 20 y 30) y el exportador tiene sus
  permisos en una tabla aparte, porque puede tener varios.
- **Precio único en `Vino`** y no en la sala (RN-01). El renglón copia el precio
  al momento de la venta, así un cambio de precio no altera comprobantes viejos.
- **Stock separado** en `Stock_Deposito` y `Sala_Venta_Vino`, con
  `CHECK (cantidad >= 0)`.
- **Atributos multivaluados** del transportista (teléfonos, localidades que
  cubre) en tablas propias.
- **Tipos propios:** el ENUM `estado_documento` (`en_confeccion`, `terminado`,
  `procesado`) para ingresos y transferencias, y el DOMAIN `cuit_dom` con el
  formato de 11 dígitos.
- **Cliente con apellido y nombre o razón social:** el CHECK
  `check_nombre_o_razon_social` exige al menos uno de los dos.

### Normalización

Cada tabla tiene una clave y los atributos dependen solo de ella. Los grupos
repetidos (teléfonos, cortes, maridajes, renglones) están en tablas propias
(1FN). En las claves compuestas, como renglones, composición o stock por sala,
ningún atributo depende de una parte sola de la clave (2FN). Los datos de otra
entidad se referencian por FK y no se copian, por ejemplo la localidad de una
sala o la bodega de un vino (3FN).

Hay dos excepciones a propósito, ambas con su control:

- los importes del comprobante (`subtotal`, `descuento`, `total`) son
  derivables de los renglones, pero se guardan para no recalcularlos en cada
  consulta. Los mantiene la base con triggers y nadie los carga a mano (RN-08);
- el `precio_unitario` del renglón repite el precio del vino, para conservar el
  histórico.

---

## 3. Integridad y lógica en la base

Detalle: [`etapa2_trazabilidad.md`](etapa2_trazabilidad.md) y
[`etapa2_concurrencia/informe.md`](etapa2_concurrencia/informe.md).

### Qué hay en la base

| Requisito | Mínimo | Hay |
|---|---|---|
| UNIQUE además de las PK | 4 | 8 |
| CHECK (uno entre columnas) | 8 | 42 (4 entre columnas) |
| DEFAULT | 3 | 12 |
| ENUM y DOMAIN | 1 y 1 | `estado_documento`, `cuit_dom` |
| Funciones | 4 | `fn_descuento_cliente`, `fn_total_comprobante`, `fn_stock_sala`, `fn_antiguedad_anios` |
| Procedimientos | 2 | `sp_procesar_ingreso`, `sp_procesar_transferencia` |
| Triggers (BEFORE, AFTER y diferido) | 6 | 10 |
| Vistas | 3 | `v_stock_total`, `v_ventas_mensuales`, `v_documentos_pendientes` |
| Roles | 3 | propietario, `bodegas_api`, `bodegas_report`; PUBLIC revocado |

### Trazabilidad regla → mecanismo → prueba

| Regla | Mecanismo | Prueba en la base | Prueba en la API |
|---|---|---|---|
| RN-01 Precio único y > 0 | `precio` en `Vino` + CHECK | precio 0 → `check_violation` | precio −1 → 422 (validación de Pydantic) |
| RN-02 Sala en una localidad, un encargado por localidad | FK + UNIQUE | segundo encargado → `unique_violation` | — |
| RN-03 Empleado en una sola sala | FK NOT NULL | sala inexistente → `foreign_key_violation` | — |
| RN-04 Una cepa por parcela, una cosecha por campaña | FK + UNIQUE `unique_lote` | segunda cosecha → `unique_violation` | — |
| RN-05 El corte suma 100 % | constraint trigger diferido | 60 % → P0001 al confirmar | alta de vino con 60 % → 409 |
| RN-06 Descuento por tipo de cliente | columna por subtipo + `fn_descuento_cliente` + trigger | devuelve 10/20/30; 120 → `check_violation` | — |
| RN-07 Varios permisos, vencimiento > emisión | tabla propia + CHECK entre columnas | vencimiento anterior → `check_violation` | — |
| RN-08 Total calculado por la base | `fn_total_comprobante` + triggers | importes 999 → queda el calculado (180) | — |
| RN-09 Sin stock negativo | trigger BEFORE con `FOR UPDATE` + CHECK | vender 100 con stock 10 → P0001 | venta sin stock → **409** (local y nube) |
| RN-10 Ciclo de estados del ingreso | ENUM + trigger + procedimiento | volver a `en_confeccion` → P0001 | ingreso inexistente → 409 |
| RN-11 Ciclo de la transferencia, fecha actual | triggers de estado y fecha + procedimiento | fecha 2000-01-01 → queda hoy | procesar sin terminar → 409; terminar inexistente → 404 |
| RN-12 Documento cerrado no cambia sus renglones | trigger en renglones | renglón a transferencia terminada → P0001 | → 409 |
| RN-13 Cambio de precio auditado | trigger AFTER + `Auditoria` | subir el precio agrega una fila | — |
| RN-14 Sin borrar con movimientos | FK `ON DELETE RESTRICT` | borrar vino vendido → `foreign_key_violation` | — |
| RN-15 Valores positivos, graduación 5 a 20 | CHECK | graduación 21, kilos −5 → `check_violation` | — |

Las pruebas de la base están en `tests/db_tests.sql`: 15 de 15 `PASS`, en una
base vacía y con la carga completa. Las de privilegios están en
`tests/db_tests_roles.sql`: 16 de 16 `OK`. Las de la API están en
`api/tests/test_api.py` (18 pruebas).

### Dónde va cada regla

- **Constraint** (CHECK, UNIQUE, FK) cuando la regla mira una sola fila o una
  relación: es lo más barato y no se puede saltear.
- **Trigger** cuando hay que mirar otras filas o tablas (stock, estados,
  auditoría, suma del corte).
- **Función o procedimiento** cuando es un cálculo que se reutiliza (descuento,
  total) o una operación de varios pasos que tiene que ser atómica (procesar un
  ingreso o una transferencia).
- **API o front** solo para validar la forma de los datos (tipos, campos
  obligatorios), nunca reglas de negocio.

### Concurrencia

Se demostró la venta simultánea de la última botella en cuatro escenarios:

1. Sin bloqueo se venden dos botellas que no existen.
2. Con `SELECT ... FOR UPDATE` la segunda sesión espera y después ve 0.
3. Con el trigger real del sistema la segunda sesión recibe «Stock insuficiente».
4. Con REPEATABLE READ la segunda sesión falla por serialización.

Se eligió **READ COMMITTED con `FOR UPDATE` dentro del trigger**: no obliga a
reintentar, el error explica el motivo y la protección vale para cualquier
cliente.

---

## 4. Carga masiva

Detalle: [`db/seed/informe_carga.md`](../db/seed/informe_carga.md) y
[`db/seed/README.md`](../db/seed/README.md).

- **Catálogos reales** en CSV (`db/seed/catalogos/`): localidades,
  departamentos, cepas, maridajes, presentaciones y tipos de vino.
- **Datos generados** con `generar.py` (Faker, semilla fija `20261108`, fechas
  relativas al día de la carga), que es reproducible. Se corre con un solo
  comando: `docker compose run --rm seed`.
- **Orden de carga** según las FK: catálogos, bodegas y salas, producción,
  vinos, clientes, depósito, movimientos y por último comprobantes y renglones.
- **Volumen:** 600.000 renglones de comprobante, 150.000 comprobantes, 20.000
  clientes, 5.000 lotes, 5.000 ingresos y 5.000 transferencias.
- **Triggers durante la carga:** se deshabilitan solo los triggers de usuario de
  las tablas de hechos; las FK y los CHECK siguen activos. Un `finally` los
  vuelve a habilitar aunque haya un error. Por eso la carga corre con el rol
  propietario. Como los triggers no recalculan el histórico, el generador hace
  el mismo cálculo que la base (precio del vino, descuento del tipo de cliente,
  subtotal y total).
- **Tiempos:** con `COPY` la carga es 28 veces más rápida que con `executemany`
  (0,067 s contra 1,895 s para 10.000 filas, medido con `medir_carga.py`). La carga completa
  (600.000 renglones) tarda 26,5 s, medida sobre un clon limpio del repositorio.
- **Consultas de control** (`controles.sql`): 0 vinos sin bodega, 0 stocks
  negativos, 0 renglones huérfanos, 0 totales incorrectos, 0 descuentos
  distintos al tipo de cliente y 0 subtotales incorrectos.
- **Datos pensados para las consultas:** ventas de la última semana y de más de
  5 años, clientes que nunca compraron, una bodega boutique con 3 vinos, una
  cepa sin usar, documentos en los tres estados.

---

## 5. Índices y rendimiento

Detalle: [`etapa4_rendimiento/informe.md`](etapa4_rendimiento/informe.md), con las salidas de
`EXPLAIN (ANALYZE, BUFFERS)` de cada consulta antes y después.

Hay 5 índices en `008_indices.sql`: compuesto, sobre FK (dos), parcial y con
`INCLUDE`.

| Consulta | Índice | Antes | Después | Mejora |
|---|---|---|---|---|
| S3 clientes por tipo en una sala, última semana | `idx_comprobante_sala_fecha` (compuesto) | 6,99 ms | 0,48 ms | 14,5x |
| S8 ventas por sala, último trimestre | `idx_ventas_trimestre` (INCLUDE) | 7,77 ms | 1,22 ms | 6,4x |
| S12 (a) compraron todos los vinos de una bodega | `idx_detalle_vino` (FK) | 27,8 ms | 6,31 ms | 4,4x |
| S12 (b) nunca compraron tinto | `idx_detalle_vino` (FK) | 155,5 ms | 93,0 ms | 1,7x |

- **Planes:** S3 y S8 pasan de Parallel Seq Scan a Index Only Scan. En S8 los
  buffers bajan de 1.246 a 28.
- **Orden del compuesto:** primero la igualdad (`id_sala`) y después el rango
  (`fecha`).
- **Descartados:** un índice por nombre de vino, que duplicaba el UNIQUE
  existente, y uno sobre `lote` para S10, que el planificador no usa porque la
  consulta recorre la CTE. Quedan en `indices_descartados.sql`.
- **Índice que no se usa:** con 5.000 transferencias el planificador prefiere
  el Seq Scan antes que el parcial `idx_transferencia_pendientes`.
- **Costo de escritura:** insertar 150.000 comprobantes pasa de 402 ms a 729 ms
  (+81 %); insertar 600.000 renglones, de 1.317 ms a 2.102 ms (+60 %). Son
  1 a 2 µs extra por fila a cambio de lecturas 4 a 14 veces más rápidas.

---

## 6. Consultas SQL

Archivos: [`consultas/update.sql`](../consultas/update.sql),
[`insert.sql`](../consultas/insert.sql),
[`delete.sql`](../consultas/delete.sql) y
[`select.sql`](../consultas/select.sql).

Cada consulta que modifica datos corre en su propia transacción: control antes,
sentencia, control después y `ROLLBACK`. Así el archivo se puede correr las
veces que se quiera sin cambiar la base. Cada una tiene comentada la estrategia
y las filas afectadas con la carga por defecto; los parámetros se cambian con
`\set` al comienzo del archivo.

Las más interesantes:

- **S2, vinos vendidos en todas las salas:** es una división relacional, con
  doble `NOT EXISTS` («no hay sala donde no se haya vendido»).
- **S12, clientes que compraron todos los vinos de una bodega:** otra división,
  que contrasta con su parte (b), un anti-join («nunca compraron tinto») que
  PostgreSQL resuelve con un Hash Anti Join en una sola pasada.
- **S11, ranking de vinos dentro de cada sala:** funciones de ventana
  (`RANK() OVER (PARTITION BY sala ...)`) y el acumulado de ventas.
- **S10, rendimiento por parcela y campaña:** CTE con la superficie y los kilos.
  Es la más lenta (~1,5 s) por la subconsulta correlacionada, y es la que se
  usó para mostrar un índice que no ayuda.
- **D1, comprobantes de socios de más de 5 años:** `DELETE ... USING` y borrado
  en cascada de 56.184 renglones. El stock no se devuelve, porque es historial.
- **D5, ingresos procesados de más de un año:** se explica por qué el trigger
  de bloqueo de renglones (RN-12) no impide la cascada.
- **U6, permisos de exportación:** muestra el descuento configurable por
  subtipo (35 % para un exportador puntual).

Todas las fechas se calculan desde `CURRENT_DATE`.

---

## 7. API y front

Detalle: [`api/informe_api.md`](../api/informe_api.md) y
[`front/README.md`](../front/README.md).

### Arquitectura

```text
Navegador (React)  --HTTP-->  FastAPI  --SQL parametrizado-->  PostgreSQL
  src/api.js                  main.py (rutas)                  reglas, triggers,
  sin cálculos                repositories.py (SQL)            funciones, roles
                              errors.py (SQLSTATE -> HTTP)
```

- **API:** FastAPI con psycopg 3 y un pool de conexiones. Todo el SQL está en
  `repositories.py` con parámetros `%s`. Las operaciones de varias sentencias,
  como una venta con sus renglones, van en una transacción. La API se conecta
  con `bodegas_api`, que no es propietario y no puede leer `Auditoria`.
- **Endpoints:**
  - ABM de vinos y clientes;
  - comprobantes;
  - ingresos y transferencias: crear, agregar renglones, terminar y procesar;
  - reportes de la sección 8: top 10 de vinos, ventas por sala, vinos sin
    stock, transportista más activo y trazabilidad;
  - catálogos para los formularios.

  La documentación Swagger está en `/docs`.
- **Front:** React con cinco pantallas (catálogo, alta y edición de vino,
  venta, transferencias y tablero). Todas las llamadas pasan por
  `src/api.js`. Muestra los importes tal como los devuelve la base y los
  errores de las reglas con su mensaje y SQLSTATE.

### Traducción de errores

| SQLSTATE | Origen | HTTP |
|---|---|---|
| `P0001` | regla de negocio en un trigger | 409 |
| `55000` | estado de objeto no válido | 409 |
| `23505`, `23503` | UNIQUE, FK | 409 |
| `23514`, `23502` | CHECK, NOT NULL | 422 |
| `P0002` | dato no encontrado en un procedimiento | 404 |
| `22P02` | formato inválido | 400 |
| `40001`, `40P01` | serialización, deadlock | 503 |

### Pruebas

`api/tests/test_api.py` tiene 18 pruebas: salud, paginación, filtros, 404,
422, FK traducida a 409, venta sin stock, renglón en una transferencia
terminada, corte que no suma 100 y procesar sin terminar (todas 409).
Las pruebas buscan los IDs a través de la API, así no dependen de una carga
puntual.

### Inyección SQL fallida

Evidencia: [`evidencia_inyeccion_sql.txt`](evidencia_inyeccion_sql.txt).
En la URL pública, `GET /api/vinos?q=' OR '1'='1` devuelve **0 vinos**: el texto
llega a la base como un valor y se busca literalmente; si se concatenara, la
condición sería siempre verdadera y devolvería todos. Los payloads con
`DROP TABLE` los bloquea el firewall de Render antes de llegar a la API, por eso
se muestran también en local.

---

## 8. Despliegue en la nube

Detalle: [`etapa8_despliegue/informe.md`](etapa8_despliegue/informe.md) y
[`etapa8_despliegue/evidencia/`](etapa8_despliegue/evidencia).

- **Proveedores:** base en **Neon** (PostgreSQL 18, región São Paulo); API y
  front en **Render**, con una sola imagen (`Dockerfile.deploy`) y una sola URL
  HTTPS.
- **Por qué Neon:** tiene un plan gratuito suficiente para el volumen reducido,
  es PostgreSQL sin capas propietarias encima, tiene TLS obligatorio y
  branches y snapshots para restaurar. Supabase pausa la base por inactividad
  y la base gratuita de Render vence a los 30 días.
- **Por qué Render para la API:** las funciones de Neon solo corren JavaScript
  y la API es Python.
- **Seguridad:**
  - Conexión cifrada (`sslmode=require` y `channel_binding=require`).
  - La API usa `bodegas_api` (`/salud` responde `"user":"bodegas_api"`).
  - Los secretos van en las variables de entorno de Render y nunca en el repo;
    se verificó que no hay claves en el historial.
  - El plan gratuito de Neon no permite restringir por IP: el acceso exige TLS
    y credenciales, y la lista de IPs permitidas queda como mejora si se pasa
    al plan pago.
- **Datos:** se aplicaron las migraciones 001 a 008 en orden sobre una base
  vacía y se hizo una carga reducida (30.000 comprobantes y 120.000 renglones)
  por el límite de 1 GB del plan gratuito. Los controles dan 0.
- **Backup y restauración:** `pg_dump` de Neon, restaurado en una base nueva;
  los conteos coinciden en las 32 tablas.
- **Regla en la nube:** la venta sin stock responde 409 con el mensaje de
  RN-09.
- **Limitación:** en el plan gratuito, Render apaga el servicio tras 15 minutos
  sin uso y el primer pedido después tarda entre 30 y 60 s.

---

## 9. Conclusiones

### Dificultades

- **Inicialización de Docker:** las migraciones solo corren al crear el volumen,
  así que un error a mitad de camino deja la base incompleta y obliga a
  `docker compose down -v`. Nos pasó con las variables de los roles que
  faltaban en el `.env`.
- **Carga masiva con los triggers:** desactivarlos acelera la carga, pero
  obliga a que el generador replique exactamente los cálculos de la base. Las
  consultas de control fueron las que lo verificaron.
- **Datos que den resultados:** varias consultas devolvían 0 filas o empates
  hasta que el generador incluyó casos a propósito (clientes sin compras, una
  bodega boutique, ventas desparejas).
- **Errores de reglas:** al principio una venta sin stock llegaba como 422 o
  500. Hubo que usar un SQLSTATE propio (`P0001`) en los triggers para que la
  API los traduzca a 409.

### Qué cambiaríamos

- Definir la convención de errores de los triggers desde la etapa 2 y no
  ajustarla después.
- Generar los datos de prueba de las consultas junto con las consultas, no
  después.
- Escribir las migraciones idempotentes desde el comienzo, porque en la nube
  hubo que adaptarlas.

### Aprendizajes

- Poner las reglas en la base hace que valgan para cualquier cliente, y la
  concurrencia se resuelve con un bloqueo en el lugar justo.
- Un índice hay que justificarlo con el plan de ejecución: dos de los
  candidatos no servían.
- El trabajo con ramas, pull requests y revisión entre los tres permitió
  avanzar en paralelo sin pisarnos.
