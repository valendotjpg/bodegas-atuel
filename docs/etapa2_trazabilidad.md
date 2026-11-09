# Etapa 2: trazabilidad de reglas de negocio

Cada regla de negocio, el mecanismo de la base que la protege y el caso de
prueba que lo verifica. Las pruebas están en
[`tests/db_tests.sql`](../tests/db_tests.sql): corren dentro de una transacción
que se revierte al final y muestran `PASS` por regla. Los privilegios de cada
rol se prueban en [`tests/db_tests_roles.sql`](../tests/db_tests_roles.sql).

## Reglas

| Regla | Mecanismo | Dónde | Caso de prueba (lo que debe fallar) |
|---|---|---|---|
| **RN-01** Precio único por vino y siempre mayor que cero | Atributo `precio` en `Vino` (no en la sala) + `CHECK (precio > 0)`. El precio del renglón lo toma el trigger de venta del vino | 001, 002 `check_precio`, 005 `trg_detalle_validar` | Vino con precio 0 → `check_violation` |
| **RN-02** Una sala pertenece a una sola localidad; cada localidad tiene un único encargado | FK `Sala_Venta.cod_postal` NOT NULL + `UNIQUE (cod_postal)` en `Encargado` | 001, 002 `unique_localidad` | Segundo encargado en la misma localidad → `unique_violation` |
| **RN-03** Cada empleado trabaja en una sola sala | FK `Empleado.id_sala` NOT NULL | 001 `fk_empleado_sala_venta` | Empleado con una sala inexistente → `foreign_key_violation` |
| **RN-04** Una parcela tiene una sola cepa y se cosecha como máximo una vez por campaña | FK `Parcela.id_cepa` + `UNIQUE (id_finca, nro_parcela, campania)` en `Lote` | 001, 002 `unique_lote` | Segunda cosecha de la parcela en la misma campaña → `unique_violation` |
| **RN-05** Los porcentajes de corte de un vino suman 100 | Constraint trigger diferido | 005 `trg_composicion_100` | Composición de 60 % → `raise_exception` (P0001) al confirmar |
| **RN-06** Descuento según el tipo de cliente: socio 10 %, distribuidor 20 %, exportador 30 % | `porcentaje_descuento` en cada subtipo (DEFAULT 10/20/30) + CHECK de rango 0 a 100 + `fn_descuento_cliente` + trigger de venta | 001, 002 `check_descuento_*`, 003, 005 `trg_detalle_validar` | `fn_descuento_cliente` devuelve 10/20/30; con 35 guardado devuelve 35 (U6); 120 → `check_violation` |
| **RN-07** Un exportador puede tener varios permisos; el vencimiento es posterior a la emisión | Tabla `Permiso_exportacion` (FK a `Exportador`) + CHECK entre columnas | 001, 002 `check_fecha_emision` | Vencimiento anterior a la emisión → `check_violation` |
| **RN-08** El total del comprobante es la suma de sus renglones con el descuento; no se carga a mano | `fn_total_comprobante` + triggers: el comprobante nace en 0 y se recalcula con cada renglón | 003, 005 `trg_comprobante_inicial`, `trg_detalle_aplicar` | Comprobante creado con importes 999 y un renglón de 2 × $100 a un socio → total 180 |
| **RN-09** No se vende más de lo que hay en la sala; el stock nunca es negativo | Trigger BEFORE con `FOR UPDATE` + `CHECK (cantidad >= 0)` | 002 `check_cantidad_sala`, 005 `trg_detalle_validar` | Vender 100 con stock 10 → `raise_exception` (P0001) «Stock insuficiente» |
| **RN-10** Solo un ingreso terminado impacta en el depósito y pasa a procesado; los estados no retroceden | ENUM `estado_documento` + trigger de estados + `sp_procesar_ingreso` | 001, 004, 005 `trg_ingreso_estado` | Procesar suma 5 al depósito y queda `procesado`; volver a `en_confeccion` → `raise_exception` (P0001) |
| **RN-11** Igual para transferencias; la fecha de confección es la actual y no se modifica | Trigger de estados + trigger de fecha + `sp_procesar_transferencia` | 004, 005 `trg_transferencia_estado`, `trg_transferencia_fecha` | Fecha enviada 2000-01-01 → queda hoy; cambiar la fecha → error; procesar descuenta 2 del depósito |
| **RN-12** Un documento que no está en confección no admite cambios en sus renglones | Trigger BEFORE INSERT/UPDATE/DELETE en los renglones | 005 `trg_ingreso_vino_bloqueo`, `trg_transferencia_vino_bloqueo` | Agregar un renglón a una transferencia terminada → `raise_exception` (P0001) |
| **RN-13** Todo cambio de precio queda auditado (fecha, usuario, precio anterior y nuevo) | Trigger AFTER UPDATE + tabla `Auditoria` | 005 `trg_vino_auditar_precio` | Subir el precio agrega una fila en `Auditoria` |
| **RN-14** No se borra un transportista, una bodega ni un vino con movimientos | FK con `ON DELETE RESTRICT` | 001 | Borrar transportista, bodega o vino referenciados → `foreign_key_violation` |
| **RN-15** Cantidades, superficies, kilos y precios positivos; graduación entre 5 y 20 | CHECK | 002 | Graduación 21 y kilos −5 → `check_violation` |

Los triggers rechazan las reglas de negocio con `RAISE EXCEPTION` y SQLSTATE
`P0001`, que la API traduce a **409 Conflict** con el mensaje de la regla (tabla de
traducción de la etapa 6). Las violaciones de constraints mantienen su propio
código: CHECK `23514` → 422, UNIQUE `23505` y FK `23503` → 409.

Además: un cliente tiene apellido y nombre o razón social
(`check_nombre_o_razon_social`); sin ninguno de los dos → `check_violation`.

## Mínimos de la etapa

| Requisito | Mínimo | Hay | Dónde |
|---|---|---|---|
| UNIQUE además de las PK | 4 | 8 | 002 |
| CHECK, uno entre columnas | 8 | 42 (entre columnas: `check_fecha_emision`, `check_descuento`, `check_total`, `check_campania`) | 002 |
| DEFAULT | 3 | 12 (estados en confección, fechas actuales, descuentos por tipo, importes en 0, usuario de auditoría) | 001 |
| ENUM y DOMAIN | 1 y 1 | `estado_documento`, `cuit_dom` | 001 |
| Funciones | 4 | `fn_descuento_cliente`, `fn_total_comprobante`, `fn_stock_sala`, `fn_antiguedad_anios` | 003 |
| Procedimientos | 2 | `sp_procesar_ingreso`, `sp_procesar_transferencia` | 004 |
| Triggers (BEFORE, AFTER y diferido) | 6 | 10 con 8 propósitos | 005 |
| Vistas | 3 | `v_stock_total`, `v_ventas_mensuales`, `v_documentos_pendientes` | 006 |
| Roles | 3 | propietario, API (`bodegas_api`), reportes (`bodegas_report`); PUBLIC revocado | 007 |

## Cómo correr las pruebas

Con el rol propietario (la API no puede leer `Auditoria`, que la prueba de
RN-13 consulta):

```bash
docker compose cp tests/db_tests.sql db:/tmp/db_tests.sql
docker compose exec db sh -c 'psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f /tmp/db_tests.sql'
```

```bash
docker compose cp tests/db_tests_roles.sql db:/tmp/db_tests_roles.sql
docker compose exec db sh -c 'psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f /tmp/db_tests_roles.sql'
```

Resultado verificado: 15/15 `PASS` en una base vacía y después de la carga
completa; 16/16 `OK` en roles.

## Concurrencia

La venta concurrente de la última botella está en
[`etapa2_concurrencia/informe.md`](etapa2_concurrencia/informe.md).
