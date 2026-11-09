/*
   Etapa 5 - Modificacion de datos (UPDATE), seccion 8.1 del TPI.
   Cada consigna corre en su propia transaccion:
   BEGIN -> control previo -> sentencia -> control posterior -> ROLLBACK.
   Se corre con el rol propietario sobre la base con la carga masiva:
     docker compose cp consultas/update.sql db:/tmp/update.sql
     docker compose exec db sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f /tmp/update.sql'
   Filas afectadas: medidas con la carga por defecto de db/seed/generar.py.
*/

\set ON_ERROR_STOP on

-- Parametros (se cambian aca)
\set bodega '\'Bodega 001\''


/* ---------------------------------------------------------------------------
   U1. Recalcular el total de todos los comprobantes aplicando el descuento
       que corresponde al tipo de cliente.
   Estrategia: primero cada renglon toma el descuento del cliente
   (fn_descuento_cliente) y recalcula su subtotal; despues cada comprobante
   toma subtotal, descuento y total de sus renglones (fn_total_comprobante).
   Se actualizan los tres importes juntos para cumplir check_total.
   Filas afectadas: 600000 renglones y 150000 comprobantes. Con la carga
   consistente no cambia ningun importe (0 antes y 0 despues); sirve para
   corregir los totales despues de un cambio de descuento como el de U6.
--------------------------------------------------------------------------- */
BEGIN;

SELECT count(*) AS comprobantes_mal_calculados
  FROM Comprobante
 WHERE total <> fn_total_comprobante(nro_comprobante);

UPDATE Detalle_Comprobante d
   SET descuento_aplicado = fn_descuento_cliente(c.id_cliente),
       subtotal_renglon   = ROUND(d.cantidad * d.precio_unitario
                                  * (1 - fn_descuento_cliente(c.id_cliente) / 100), 2)
  FROM Comprobante c
 WHERE c.nro_comprobante = d.nro_comprobante;

UPDATE Comprobante c
   SET subtotal  = r.subtotal,
       total     = fn_total_comprobante(c.nro_comprobante),
       descuento = r.subtotal - fn_total_comprobante(c.nro_comprobante)
  FROM (SELECT nro_comprobante, SUM(ROUND(cantidad * precio_unitario, 2)) AS subtotal
          FROM Detalle_Comprobante
         GROUP BY nro_comprobante) r
 WHERE r.nro_comprobante = c.nro_comprobante;

SELECT count(*) AS comprobantes_mal_calculados
  FROM Comprobante
 WHERE total <> fn_total_comprobante(nro_comprobante);

ROLLBACK;


/* ---------------------------------------------------------------------------
   U2. Aumentar un 20 % el salario de los empleados con mas de 5 anios de
       antiguedad.
   Estrategia: filtro con fn_antiguedad_anios(fecha_ingreso), que cuenta anios
   completos hasta hoy.
   Filas afectadas: 42.
--------------------------------------------------------------------------- */
BEGIN;

SELECT count(*) AS empleados, SUM(salario) AS masa_salarial
  FROM Empleado
 WHERE fn_antiguedad_anios(fecha_ingreso) > 5;

UPDATE Empleado
   SET salario = ROUND(salario * 1.20, 2)
 WHERE fn_antiguedad_anios(fecha_ingreso) > 5;

SELECT count(*) AS empleados, SUM(salario) AS masa_salarial
  FROM Empleado
 WHERE fn_antiguedad_anios(fecha_ingreso) > 5;

ROLLBACK;


/* ---------------------------------------------------------------------------
   U3. Incrementar un 13 % el precio de los vinos elaborados por una bodega
       determinada (parametro :bodega).
   Estrategia: subconsulta por razon social para obtener el CUIT.
   Trigger: cada cambio de precio dispara trg_vino_auditar_precio (RN-13) y
   deja una fila en Auditoria por vino.
   Filas afectadas: 29 vinos y 29 filas nuevas en Auditoria.
--------------------------------------------------------------------------- */
BEGIN;

SELECT count(*) AS vinos, ROUND(AVG(precio), 2) AS precio_promedio,
       (SELECT count(*) FROM Auditoria) AS filas_auditoria
  FROM Vino
 WHERE cuit_bodega = (SELECT cuit_bodega FROM Bodega WHERE razon_social = :bodega);

UPDATE Vino
   SET precio = ROUND(precio * 1.13, 2)
 WHERE cuit_bodega = (SELECT cuit_bodega FROM Bodega WHERE razon_social = :bodega);

SELECT count(*) AS vinos, ROUND(AVG(precio), 2) AS precio_promedio,
       (SELECT count(*) FROM Auditoria) AS filas_auditoria
  FROM Vino
 WHERE cuit_bodega = (SELECT cuit_bodega FROM Bodega WHERE razon_social = :bodega);

ROLLBACK;


/* ---------------------------------------------------------------------------
   U4. En las salas cuyo dia de cierre es lunes cambiarlo a miercoles y
       viceversa, en una sola sentencia.
   Estrategia: un solo UPDATE con CASE. Como cada fila se evalua con su valor
   original, no hace falta un valor intermedio.
   Filas afectadas: 12 (8 lunes y 4 miercoles).
--------------------------------------------------------------------------- */
BEGIN;

SELECT dia_cierre, count(*) AS salas
  FROM Sala_Venta
 WHERE dia_cierre IN ('Lunes', 'Miércoles')
 GROUP BY dia_cierre;

UPDATE Sala_Venta
   SET dia_cierre = CASE dia_cierre WHEN 'Lunes' THEN 'Miércoles' ELSE 'Lunes' END
 WHERE dia_cierre IN ('Lunes', 'Miércoles');

SELECT dia_cierre, count(*) AS salas
  FROM Sala_Venta
 WHERE dia_cierre IN ('Lunes', 'Miércoles')
 GROUP BY dia_cierre;

ROLLBACK;


/* ---------------------------------------------------------------------------
   U5. Aplicar un 15 % de descuento de precio a los 10 vinos menos vendidos de
       toda la red.
   Estrategia: CTE con las botellas vendidas por vino. LEFT JOIN para contar
   tambien los vinos que nunca se vendieron (0 botellas). Desempate por
   cod_vino para que siempre sean exactamente 10.
   Trigger: deja 10 filas en Auditoria (RN-13).
   Filas afectadas: 10 (los menos vendidos tienen entre 284 y 324 botellas).
--------------------------------------------------------------------------- */
BEGIN;

WITH ventas AS (
    SELECT v.cod_vino, COALESCE(SUM(d.cantidad), 0) AS botellas
      FROM Vino v
      LEFT JOIN Detalle_Comprobante d ON d.cod_vino = v.cod_vino
     GROUP BY v.cod_vino
     ORDER BY botellas, v.cod_vino
     LIMIT 10
)
SELECT v.cod_vino, v.nombre_comercial, ventas.botellas, v.precio
  FROM ventas JOIN Vino v USING (cod_vino)
 ORDER BY ventas.botellas, v.cod_vino;

WITH menos_vendidos AS (
    SELECT v.cod_vino
      FROM Vino v
      LEFT JOIN Detalle_Comprobante d ON d.cod_vino = v.cod_vino
     GROUP BY v.cod_vino
     ORDER BY COALESCE(SUM(d.cantidad), 0), v.cod_vino
     LIMIT 10
)
UPDATE Vino
   SET precio = ROUND(precio * 0.85, 2)
 WHERE cod_vino IN (SELECT cod_vino FROM menos_vendidos);

SELECT a.cod_vino, a.precio_anterior, a.precio_nuevo
  FROM Auditoria a
 WHERE a.fecha_hora = CURRENT_TIMESTAMP
 ORDER BY a.cod_vino;

ROLLBACK;


/* ---------------------------------------------------------------------------
   U6. A los exportadores con mas de 3 permisos de exportacion, subirles el
       descuento al 35 %.
   Estrategia: el descuento se guarda en Exportador.porcentaje_descuento
   (CHECK de 0 a 100); subconsulta con GROUP BY ... HAVING sobre los permisos.
   Efecto: rige para las ventas nuevas (trg_detalle_validar usa
   fn_descuento_cliente). Los comprobantes ya emitidos no cambian salvo que
   se corra U1.
   Filas afectadas: 2666.
--------------------------------------------------------------------------- */
BEGIN;

SELECT porcentaje_descuento, count(*) AS exportadores
  FROM Exportador
 GROUP BY porcentaje_descuento;

UPDATE Exportador
   SET porcentaje_descuento = 35
 WHERE id_cliente IN (SELECT id_cliente
                        FROM Permiso_exportacion
                       GROUP BY id_cliente
                      HAVING count(*) > 3);

SELECT porcentaje_descuento, count(*) AS exportadores
  FROM Exportador
 GROUP BY porcentaje_descuento;

ROLLBACK;
