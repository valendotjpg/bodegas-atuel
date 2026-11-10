# Normalización y decisiones de diseño — Bodegas del Atuel

Etapa 1 · Modelo relacional · Grupo 7

Este documento justifica que el esquema físico (`db/migrations/001_esquema.sql` y `002_constraints.sql`: 32 tablas) está en **Tercera Forma Normal (3FN)** y explica las decisiones de diseño tomadas al pasar del DER al modelo relacional. Complementa al diccionario de datos (`Diccionario_de_datos.md`) y a los diagramas de esta carpeta.

---

## 1. Normalización

### 1.1 Primera Forma Normal (1FN)

Una tabla está en 1FN si todos sus atributos son atómicos y no hay grupos repetidos. El esquema la cumple por tres decisiones tomadas al pasar del DER al relacional:

| Problema potencial | Solución adoptada |
|---|---|
| **Atributo multivaluado**: un transportista tiene varios teléfonos | Tabla `Transportista_Telefono` con PK `(cod_transporte, telefono)` |
| **Atributo compuesto**: domicilio | Se descompone en `calle` y `numero` (Bodega, Sala_Venta, Cliente, Transportista) |
| **Grupos repetidos**: los vinos de un comprobante, de un ingreso o de una transferencia | No son columnas repetidas en la cabecera sino filas en `Detalle_Comprobante`, `Ingreso_Vino` y `Transferencia_Vino`. Lo mismo para composición de cepas (`Composicion`), maridajes (`Vino_Maridaje`), stock por sala (`Sala_Venta_Vino`) y stock del depósito (`Stock_Deposito`) |

También se resolvió la relación N:M entre transportistas y localidades con `Transportista_Localidad`.

### 1.2 Segunda Forma Normal (2FN)

Una tabla en 1FN está en 2FN si ningún atributo no clave depende solo de una parte de la clave. Solo puede fallar en tablas con **clave compuesta**; las que tienen clave simple cumplen 2FN automáticamente.

| Clave compuesta | Atributos no clave | Por qué depende de la clave completa |
|---|---|---|
| `(id_finca, nro_parcela)` — Parcela | superficie, anio_plantacion, id_cepa | El número de parcela solo identifica a la parcela *dentro de una finca* (entidad débil). |
| `(cod_vino, id_cepa)` — Composicion | porcentaje | Es el porcentaje de *esa* cepa en *ese* vino; no de la cepa ni del vino por separado. |
| `(nro_comprobante, cod_vino)` — Detalle_Comprobante | cantidad, precio_unitario, descuento_aplicado, subtotal_renglon | `precio_unitario` es el precio *al momento de esa venta* (no el precio actual del vino); depende de las dos columnas. |
| `(cod_ingreso, cod_vino)` — Ingreso_Vino | cantidad | Botellas de ese vino en ese ingreso. |
| `(nro_solicitud, cod_vino)` — Transferencia_Vino | cantidad | Botellas de ese vino en esa transferencia. |
| `(id_sala, cod_vino)` — Sala_Venta_Vino | cantidad | Stock de ese vino en esa sala. |
| `(id_deposito, cod_vino)` — Stock_Deposito | cantidad | Stock de ese vino en el depósito. |

`Vino_Maridaje`, `Transportista_Telefono` y `Transportista_Localidad` tienen clave compuesta pero **ningún atributo no clave**, por lo que cumplen 2FN trivialmente.

> Nota sobre `Detalle_Comprobante.precio_unitario`: guardar el precio en el renglón **no** viola la normalización. Si se tomara `Vino.precio` al consultar, el historial cambiaría cada vez que cambia el precio. El precio del renglón es un dato histórico propio de la venta (ver sección 2.4).

### 1.3 Tercera Forma Normal (3FN)

Una tabla en 2FN está en 3FN si ningún atributo no clave depende de otro atributo no clave (dependencia transitiva). **Las claves candidatas (columnas con `UNIQUE`) pueden determinar otros atributos sin romper la 3FN**, porque no son atributos "no clave".

| Tabla | Dependencias funcionales | 3FN |
|---|---|---|
| Localidad | `cod_postal → nombre, provincia` | Cumple |
| Encargado | `id_encargado → nombre, apellido, cod_postal`; `cod_postal` es clave candidata (UNIQUE) | Cumple |
| Sala_Venta | `id_sala → calle, numero, dia_cierre, cod_postal` | Cumple (ver 1.4) |
| Empleado | `cuit_empleado → nombre, apellido, salario, fecha_ingreso, id_sala` | Cumple (la antigüedad es calculada, no se almacena) |
| Finca | `id_finca → nombre, superficie_ha, departamento, provincia` | Cumple |
| Cepa, Maridaje, Deposito_Central | La clave determina todo lo demás; `nombre` / `nombre_maridaje` son claves candidatas | Cumplen |
| Parcela | `(id_finca, nro_parcela) → superficie, anio_plantacion, id_cepa` | Cumple |
| Lote | `nro_lote → campania, fecha_cosecha, kilos, cuit_bodega, id_finca, nro_parcela`; `(id_finca, nro_parcela, campania)` es clave candidata (RN-04) | Cumple |
| Analisis_Calidad | `id_analisis → fecha, grado_brix, ph, acidez_total, nro_lote` | Cumple |
| Bodega | `cuit_bodega → razon_social, calle, numero` | Cumple |
| Vino | `cod_vino → nombre_comercial, tipo, anada, volumen_ml, graduacion, precio, cuit_bodega`; `(nombre_comercial, anada, volumen_ml)` es clave candidata | Cumple |
| Composicion / Vino_Maridaje | La clave compuesta determina `porcentaje` (o no hay atributos no clave) | Cumplen |
| Cliente | `id_cliente → todos los atributos`; `(tipo_documento, nro_documento)` es clave candidata | Cumple |
| Socio, Distribuidor, Exportador | `id_cliente →` atributos del subtipo (incluido `porcentaje_descuento`) | Cumplen (ver 2.1) |
| Permiso_exportacion | `cod_permiso → fecha_emision, fecha_vencimiento, id_cliente` | Cumple |
| Comprobante | `nro_comprobante → fecha, id_cliente, id_sala, subtotal, descuento, total` | Cumple (derivados controlados, ver 2.4) |
| Detalle_Comprobante | `(nro_comprobante, cod_vino) → cantidad, precio_unitario, descuento_aplicado, subtotal_renglon` | Cumple (derivado controlado, ver 2.4) |
| Transportista | `cod_transporte → razon_social, email, cuit, calle, numero`; `cuit` es clave candidata | Cumple |
| Ingreso | `cod_ingreso → estado, fecha_ingreso, cuit_bodega, cod_transporte` | Cumple |
| Transferencia | `nro_solicitud → estado, fecha, id_sala` | Cumple |
| Auditoria | `id_auditoria → cod_vino, usuario, precio_anterior, precio_nuevo, fecha_hora` | Cumple |

### 1.4 El caso `localidad → encargado regional`

Esta es la dependencia funcional que más podía romper la 3FN. La regla de negocio (RN-02) dice que **hay un único encargado regional por localidad y está afectado a todas las salas de esa localidad**.

Si se hubiera guardado `id_encargado` en `Sala_Venta`, aparecería:

```
id_sala → cod_postal → id_encargado        (dependencia transitiva)
```

es decir, el encargado dependería de la localidad y no de la sala: se repetiría en cada sala de la misma localidad (redundancia) y podría quedar inconsistente (dos salas de una misma localidad con encargados distintos).

**Solución adoptada:** `Sala_Venta` solo guarda `cod_postal`. La relación con el encargado vive en `Encargado`, que tiene la FK `cod_postal → Localidad` con restricción `UNIQUE` (`unique_localidad`), garantizando un encargado por localidad. El encargado de una sala se obtiene por join: `Sala_Venta → Localidad → Encargado`. Así la dependencia `cod_postal → encargado` queda en una única tabla cuya clave candidata es justamente `cod_postal`, y la 3FN se cumple.

### 1.5 Atributos derivados y 3FN

`subtotal`, `descuento` y `total` (Comprobante) y `subtotal_renglon` (Detalle_Comprobante) son **derivados**: se pueden calcular a partir de otros datos. Técnicamente un derivado almacenado introduce redundancia. Se decidió conservarlos y garantizar su consistencia desde la base (ver 2.4); no hay dependencia transitiva en sentido estricto porque su valor lo fija la base y no puede ser modificado de forma independiente. La **antigüedad del empleado**, en cambio, no se almacena: cambia con el tiempo, y guardarla la dejaría desactualizada.

---

## 2. Decisiones de diseño

### 2.1 Jerarquía de clientes (supertipo / subtipos)

**Situación:** un cliente puede ser socio, distribuidor o exportador. Cada tipo tiene atributos propios (zona de cobertura y nº de habilitación; país de destino y permisos de exportación) y un porcentaje de descuento distinto (10 / 20 / 30 %, RN-06).

**Alternativas evaluadas**

| Alternativa | Ventaja | Problema |
|---|---|---|
| Una sola tabla `Cliente` con todas las columnas y un campo `tipo` | Simple, sin joins | Muchos `NULL` (cada fila usa solo una parte de las columnas); no se pueden marcar como `NOT NULL` los atributos propios de un tipo |
| Una tabla por subtipo, sin supertipo | Sin nulos | Se duplican los datos comunes (documento, domicilio) y `Comprobante` no puede tener una única FK a "cliente" |
| **Supertipo + una tabla por subtipo (elegida)** | Datos comunes una sola vez; atributos propios `NOT NULL`; `Comprobante` referencia un único `id_cliente` | Requiere join para conocer los atributos del subtipo |

**Implementación:** `Cliente(id_cliente PK, …)` con `Socio`, `Distribuidor` y `Exportador`, cuya PK es a su vez FK a `Cliente(id_cliente)` con `ON DELETE CASCADE` (el subtipo no existe sin su cliente). `Permiso_exportacion` referencia a `Exportador`, no a `Cliente`, de modo que solo un exportador puede tener permisos (RN-07).

**Exclusividad:** un cliente pertenece a un solo subtipo. La FK compartida por sí sola no lo impide; lo controla `fn_descuento_cliente`, que lanza una excepción si el cliente figura en más de un subtipo o en ninguno, de modo que no se puede registrar una venta a un cliente inconsistente. (Un constraint trigger que lo valide al insertar el subtipo sería una mejora posible.)

**Descuento:** cada subtipo guarda su `porcentaje_descuento` con un `DEFAULT` (10, 20, 30) y un `CHECK` entre 0 y 100. La función `fn_descuento_cliente(id_cliente)` devuelve el porcentaje según el subtipo, y el trigger lo copia a `Detalle_Comprobante.descuento_aplicado`.

**Nombre / razón social:** `Cliente` tiene `apellido`, `nombre` y `razon_social`, todas opcionales, con el `CHECK` `check_nombre_o_razon_social`: o hay razón social, o hay apellido **y** nombre. Esto cubre personas físicas y empresas sin forzar datos falsos.

### 2.2 Claves naturales vs. subrogadas

**Criterio:** se usa clave natural solo cuando el dato es un identificador **estable, único y propio del dominio**; en el resto se usa una clave subrogada autoincremental.

| Tabla | Clave | Tipo | Justificación |
|---|---|---|---|
| Bodega | `cuit_bodega` | Natural (`cuit_dom`) | El CUIT es único, legalmente asignado y no cambia |
| Empleado | `cuit_empleado` | Natural (`cuit_dom`) | Ídem |
| Localidad | `cod_postal` | Natural (`INT`) | Identifica a la localidad en el dominio |
| Parcela | `(id_finca, nro_parcela)` | Natural compuesta | Entidad débil: el nº de parcela solo existe dentro de su finca |
| Tablas N:M (Composicion, Vino_Maridaje, Detalle_Comprobante, Ingreso_Vino, Transferencia_Vino, Stock_Deposito, Sala_Venta_Vino, Transportista_*) | Compuesta por las FKs | Natural compuesta | La combinación identifica la fila; evita una clave extra sin significado |
| Vino, Cliente, Sala_Venta, Encargado, Finca, Cepa, Maridaje, Lote, Analisis_Calidad, Comprobante, Transportista, Ingreso, Transferencia, Permiso_exportacion, Deposito_Central, Auditoria | `id_*` / `cod_*` / `nro_*` | Subrogada (`IDENTITY` o `SERIAL`) | No hay un identificador natural estable (ej.: dos vinos pueden compartir nombre; un cliente puede identificarse con DNI, CUIT, CUIL o pasaporte) |

**Claves candidatas** que no son PK se protegen con `UNIQUE`: `Vino(nombre_comercial, anada, volumen_ml)`, `Cliente(tipo_documento, nro_documento)`, `Lote(id_finca, nro_parcela, campania)`, `Transportista.cuit`, `Distribuidor.nro_habilitacion`, `Cepa.nombre`, `Maridaje.nombre_maridaje`, `Encargado.cod_postal`.

**Por qué subrogada en Cliente:** el documento puede ser de cuatro tipos distintos y podría corregirse; usarlo como PK obligaría a propagar el cambio a todas las FKs. Con `id_cliente`, el documento se mantiene como clave candidata `UNIQUE`.

### 2.3 Tipos de datos

| Dato | Tipo elegido | Justificación |
|---|---|---|
| Importes (precio, subtotal, total, descuento, salario) | `NUMERIC(p,s)`, p. ej. `NUMERIC(10,2)` / `NUMERIC(12,2)` | Precisión exacta. **Nunca `FLOAT`/`REAL`**: el punto flotante binario introduce errores de redondeo inaceptables en dinero |
| Porcentajes, graduación, pH, °Brix, superficie, kilos | `NUMERIC` con escala acotada | Valores decimales exactos con rango acotado por `CHECK` |
| Cantidades de botellas | `INT` con `CHECK (> 0)` o `(>= 0)` en stock | Son enteros; el stock puede ser 0 pero nunca negativo |
| Fechas de negocio (venta, cosecha, ingreso, emisión) | `DATE` | Solo interesa el día |
| Momento de un cambio de precio (`Auditoria.fecha_hora`) | `TIMESTAMP` | Se necesita hora para ordenar cambios dentro del mismo día |
| Año de añada / plantación / campaña | `SMALLINT` | Rango pequeño, ocupa menos espacio; acotado por `CHECK` |
| CUIT | `DOMAIN cuit_dom AS CHAR(11)` con `CHECK (VALUE ~ '^[0-9]{11}$')` | Longitud fija; el dominio reutiliza la validación en Bodega, Empleado y Transportista |
| Estado de ingreso/transferencia | `ENUM estado_documento ('en_confeccion','terminado','procesado')` | Conjunto cerrado y ordenado de valores; el motor rechaza cualquier otro. Las transiciones se controlan con trigger (RN-10 / RN-11) |
| Tipo de vino, tipo de cepa, tipo de documento, día de cierre, volumen | `VARCHAR` + `CHECK ... IN (...)` | Listas cortas y verificables; más fáciles de cambiar que un `ENUM` (que requiere `ALTER TYPE`) |
| Documento, teléfono, nº de habilitación | `VARCHAR` | No se operan aritméticamente y pueden tener ceros a la izquierda o formato |
| Claves subrogadas | `INT GENERATED ALWAYS AS IDENTITY` / `SERIAL` | Autoincrementales, simples de indexar |

**Por qué `ENUM` solo para estados:** es el único atributo con un ciclo de vida (en_confección → terminado → procesado) compartido por dos tablas, por lo que conviene un tipo único. Para el resto de las listas cerradas se prefirió `CHECK`, que se modifica con un simple `ALTER TABLE`.

### 2.4 Atributos derivados: almacenados vs. calculados

| Atributo | Decisión | Cómo se garantiza la consistencia |
|---|---|---|
| `Detalle_Comprobante.subtotal_renglon` | **Almacenado** | Lo calcula el trigger (RN-08): `cantidad × precio_unitario × (1 − descuento_aplicado/100)`. `CHECK (>= 0)` |
| `Comprobante.subtotal` | **Almacenado** | El comprobante nace con importes en 0 (`trg_comprobante_inicial`); `trg_detalle_aplicar` recalcula la suma de `cantidad × precio_unitario` de los renglones cada vez que se inserta uno |
| `Comprobante.descuento` | **Almacenado** | Importe descontado según el tipo de cliente; lo calcula el trigger. `CHECK (descuento >= 0 AND descuento <= subtotal)` |
| `Comprobante.total` | **Almacenado** | `CHECK (total = subtotal − descuento)` impide que se guarde un total incoherente; `fn_total_comprobante` lo calcula |
| `Detalle_Comprobante.precio_unitario` | **Almacenado (dato histórico)** | Se copia de `Vino.precio` al momento de la venta; el cambio posterior del precio no altera ventas pasadas. Los cambios de precio se auditan (RN-13) |
| `Detalle_Comprobante.descuento_aplicado` | **Almacenado (dato histórico)** | Porcentaje vigente al momento de la venta, obtenido con `fn_descuento_cliente` |
| Antigüedad del empleado | **Calculado, no almacenado** | `fn_antiguedad_anios(fecha_ingreso)`; cambia con el tiempo |
| Stock de la sala | Almacenado en `Sala_Venta_Vino` | Lo modifican los triggers de venta y el procedimiento de transferencia; `CHECK (cantidad >= 0)` y validación previa (RN-09) |

**Por qué almacenar los importes del comprobante:**

1. **Rendimiento:** las consultas de ventas por sala y trimestre (etapa 4) leen `total` directamente, sin recalcular sobre 600 mil renglones.
2. **Inmutabilidad histórica:** un comprobante emitido es un documento; sus importes no deben cambiar si cambian precios o descuentos futuros.
3. **Costo:** el sobrecosto de mantenerlos (triggers) es aceptable porque las ventas se insertan una vez y no se modifican.

**Cómo se evita la inconsistencia:** el cálculo no queda en manos de la aplicación; lo hacen triggers y funciones de la base (`trg_comprobante_inicial`, `trg_detalle_validar`, `trg_detalle_aplicar`), y los `CHECK` bloquean cualquier combinación incoherente (`total = subtotal − descuento`, `descuento <= subtotal`). Las pruebas de `tests/db_tests.sql` verifican RN-08.

### 2.5 Acciones referenciales (`ON DELETE` / `ON UPDATE`)

**Criterio general**

- **`ON DELETE RESTRICT`** (o `NO ACTION`) en las entidades de negocio y en los movimientos: no se puede borrar algo que otra tabla usa. Protege el historial (RN-14).
- **`ON DELETE CASCADE`** solo en tablas **dependientes que no tienen sentido sin su tabla principal**: renglones, teléfonos, composición, vino-maridaje, permisos, análisis, parcelas y subtipos de cliente.
- **`ON UPDATE CASCADE`** solo en FKs hacia **claves naturales** (`cuit_bodega`, `cod_postal`), que podrían corregirse. Las claves `IDENTITY` no se modifican, así que no necesitan `ON UPDATE`.

**Resumen de las 37 FK del esquema** (21 `RESTRICT`, 16 `CASCADE`)

| Acción | FKs | Razón |
|---|---|---|
| `ON DELETE CASCADE` | Parcela→Finca; Analisis_Calidad→Lote; Vino_Maridaje→Vino y →Maridaje; Detalle_Comprobante→Comprobante; Socio / Distribuidor / Exportador→Cliente; Permiso_exportacion→Exportador; Ingreso_Vino→Ingreso; Transferencia_Vino→Transferencia; Transportista_Telefono→Transportista; Transportista_Localidad→Transportista y →Localidad; Stock_Deposito→Deposito_Central; Composicion→Vino | La fila hija es parte del padre (detalle, subtipo, atributo multivaluado, asociación N:M) |
| `ON DELETE RESTRICT` | Vino→Bodega; Encargado / Sala_Venta / Cliente→Localidad; Empleado→Sala_Venta; Parcela→Cepa; Lote→Bodega y →Parcela; Comprobante→Sala_Venta y →Cliente; Detalle_Comprobante→Vino; Ingreso→Bodega y →Transportista; Ingreso_Vino→Vino; Stock_Deposito→Vino; Transferencia→Sala_Venta; Transferencia_Vino→Vino; Sala_Venta_Vino→Sala_Venta y →Vino; Auditoria→Vino; Composicion→Cepa | Son entidades de negocio o movimientos con valor histórico; no se pueden borrar si están referenciadas |
| `ON UPDATE CASCADE` | Vino→Bodega; Encargado→Localidad; Sala_Venta→Localidad; Cliente→Localidad | Se apunta a claves naturales (`cuit_bodega`, `cod_postal`) |

**Ejemplos que justifican la elección**

- No se puede borrar un `Vino` con ventas, ingresos, transferencias o stock (`RESTRICT`), pero sí se pueden borrar sus filas de composición y maridajes (`CASCADE`), que solo lo describen.
- Borrar un `Comprobante` borra sus renglones (`CASCADE`), pero no se puede borrar un `Cliente` o una `Sala_Venta` con comprobantes (`RESTRICT`).
- Un `Ingreso` o `Transferencia` ya procesado no se puede alterar: lo impiden los triggers de estado (RN-10 a RN-12), que se suman a las FK.
- Borrar una `Finca` borra sus parcelas (entidad débil), pero la parcela no puede borrarse si ya tiene lotes cosechados (`Lote→Parcela RESTRICT`).

### 2.6 Otras decisiones relevantes

- **Entidad débil `Parcela`:** PK compuesta `(id_finca, nro_parcela)`. `Lote` referencia la parcela con una FK compuesta; el `UNIQUE (id_finca, nro_parcela, campania)` garantiza a lo sumo una cosecha por parcela y campaña (RN-04), y `CHECK (campania = EXTRACT(YEAR FROM fecha_cosecha))` mantiene coherentes año y fecha.
- **Una única cepa por parcela (RN-04):** `id_cepa` en `Parcela` (relación 1:N), no una tabla intermedia.
- **Composición de cada vino:** tabla N:M con porcentaje; la suma por vino debe ser 100 y se controla con un **constraint trigger diferido** (`trg_composicion_100`), que valida al final de la transacción y permite insertar las cepas una por una.
- **Precio único para toda la red (RN-01):** `precio` vive en `Vino`, no en cada sala.
- **Stock separado por ubicación:** `Stock_Deposito` y `Sala_Venta_Vino` son tablas distintas con clave `(ubicación, vino)`; evitan columnas por sala y permiten agregar salas sin cambiar el esquema.
- **Un único depósito central:** se modela como tabla `Deposito_Central` (y no como constante) para poder referenciarlo con FK y mantener el stock normalizado.
- **Auditoría de precios (RN-13):** tabla `Auditoria` completada por un trigger `AFTER UPDATE` sobre `Vino`, de modo que no se puede omitir desde la aplicación.
- **Integridad por capas:** tipos y `DOMAIN` → `CHECK` → FK → triggers → procedimientos. Las reglas que involucran varias filas o tablas (stock, estados, suma 100 %) se resuelven con triggers; las de una sola fila con `CHECK`.

---

## 3. Verificación

- Las dependencias funcionales de la sección 1 se pueden contrastar con el DER y el esquema relacional de esta carpeta (`DER Integrado.png`, `Esquema_Relacional.drawio.png`).
- Las restricciones citadas (`CHECK`, `UNIQUE`, FK) están en `db/migrations/002_constraints.sql` y en el bloque de `ALTER TABLE` de `001_esquema.sql`.
- Las reglas RN-01 a RN-15 están probadas en `tests/db_tests.sql`.
- No hay columnas `FLOAT`/`REAL` en el esquema (todo dato decimal es `NUMERIC`).
