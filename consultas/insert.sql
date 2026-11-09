/*
   Etapa 5 - Insercion de datos (INSERT), seccion 8.2 del TPI.
   Cada consigna corre en su propia transaccion:
   BEGIN -> control previo -> sentencia -> control posterior -> ROLLBACK.
   Se corre con el rol propietario sobre la base con la carga masiva:
     docker compose cp consultas/insert.sql db:/tmp/insert.sql
     docker compose exec db sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f /tmp/insert.sql'
   Filas afectadas: medidas con la carga por defecto de db/seed/generar.py.
*/

\set ON_ERROR_STOP on

-- Parametros (se cambian aca)
\set localidad_i1 '\'General Alvear\''
\set cliente_i3 '\'Cliente 018999\''
\set sala_i3 1
\set bodega_i6 '\'Bodega 001\''
\set vino_i6 '\'Reserva Atuel 00015\''
\set volumen_i6 750
\set transportista_i6 '\'Transportes Atuel 0001\''


/* ---------------------------------------------------------------------------
   I1. Insertar en transportista-localidad una nueva cobertura que vincule la
       localidad de General Alvear con el transportista que menos envios
       (ingresos trasladados) haya realizado en el ultimo trimestre.
   Estrategia: CTE que cuenta los ingresos de cada transportista en los
   ultimos 3 meses (CURRENT_DATE - 3 meses). LEFT JOIN para incluir a los que
   no hicieron envios (0). Desempate por cod_transporte. ON CONFLICT evita
   duplicar la cobertura si ya existe (la PK es compuesta).
   Filas afectadas: 1. Con la carga actual no hay ingresos en el ultimo
   trimestre: todos tienen 0 envios y gana el desempate.
--------------------------------------------------------------------------- */
BEGIN;

SELECT t.cod_transporte, t.razon_social, count(i.cod_ingreso) AS envios_trimestre
  FROM Transportista t
  LEFT JOIN Ingreso i ON i.cod_transporte = t.cod_transporte
                     AND i.fecha_ingreso >= CURRENT_DATE - INTERVAL '3 months'
 GROUP BY t.cod_transporte, t.razon_social
 ORDER BY envios_trimestre, t.cod_transporte
 LIMIT 3;

SELECT count(*) AS transportistas_en_la_localidad
  FROM Transportista_Localidad tl
  JOIN Localidad l USING (cod_postal)
 WHERE l.nombre = :localidad_i1;

WITH menos_envios AS (
    SELECT t.cod_transporte
      FROM Transportista t
      LEFT JOIN Ingreso i ON i.cod_transporte = t.cod_transporte
                         AND i.fecha_ingreso >= CURRENT_DATE - INTERVAL '3 months'
     GROUP BY t.cod_transporte
     ORDER BY count(i.cod_ingreso), t.cod_transporte
     LIMIT 1
)
INSERT INTO Transportista_Localidad (cod_transporte, cod_postal)
SELECT m.cod_transporte, l.cod_postal
  FROM menos_envios m, Localidad l
 WHERE l.nombre = :localidad_i1
ON CONFLICT DO NOTHING;

SELECT tl.cod_transporte, t.razon_social, l.nombre
  FROM Transportista_Localidad tl
  JOIN Localidad l USING (cod_postal)
  JOIN Transportista t USING (cod_transporte)
 WHERE l.nombre = :localidad_i1
 ORDER BY tl.cod_transporte;

ROLLBACK;


/* ---------------------------------------------------------------------------
   I2. Si existe algun vino tinto con graduacion de 14 o mas, crear el maridaje
       "cordero al disco" y asociarlo a todos los vinos que cumplan esa
       condicion.
   Estrategia: INSERT ... SELECT ... WHERE EXISTS crea el maridaje solo si hay
   algun vino que cumpla; despues INSERT ... SELECT asocia todos esos vinos.
   ON CONFLICT porque nombre_maridaje es UNIQUE y la asociacion tiene PK.
   Filas afectadas: 1 maridaje y 82 asociaciones.
--------------------------------------------------------------------------- */
BEGIN;

SELECT count(*) AS tintos_de_14_o_mas
  FROM Vino
 WHERE tipo = 'tinto' AND graduacion >= 14;

INSERT INTO Maridaje (nombre_maridaje, temperatura_servicio)
SELECT 'Cordero al disco', 17
 WHERE EXISTS (SELECT 1 FROM Vino WHERE tipo = 'tinto' AND graduacion >= 14)
ON CONFLICT (nombre_maridaje) DO NOTHING;

INSERT INTO Vino_Maridaje (cod_vino, id_maridaje)
SELECT v.cod_vino, m.id_maridaje
  FROM Vino v, Maridaje m
 WHERE v.tipo = 'tinto' AND v.graduacion >= 14
   AND m.nombre_maridaje = 'Cordero al disco'
ON CONFLICT DO NOTHING;

SELECT m.nombre_maridaje, count(vm.cod_vino) AS vinos_asociados
  FROM Maridaje m
  LEFT JOIN Vino_Maridaje vm USING (id_maridaje)
 WHERE m.nombre_maridaje = 'Cordero al disco'
 GROUP BY m.nombre_maridaje;

ROLLBACK;


/* ---------------------------------------------------------------------------
   I3. Crear un nuevo comprobante con tres renglones para un cliente dado, en
       la sala con ID 1, dentro de una transaccion y usando las funciones de
       calculo.
   Estrategia: el comprobante se crea sin importes (trg_comprobante_inicial lo
   deja en 0). Cada renglon se inserta solo con vino y cantidad: los triggers
   validan y descuentan el stock, ponen el precio del vino, el descuento de
   fn_descuento_cliente y recalculan los importes con fn_total_comprobante
   (RN-06, RN-08, RN-09). Se eligen los 3 primeros vinos con stock en la sala.
   Filas afectadas: 1 comprobante y 3 renglones; el stock de la sala baja.
--------------------------------------------------------------------------- */
BEGIN;

SELECT id_cliente, fn_descuento_cliente(id_cliente) AS descuento_cliente
  FROM Cliente
 WHERE razon_social = :cliente_i3 \gset

SELECT svv.cod_vino, v.nombre_comercial, v.precio, svv.cantidad AS stock_sala
  FROM Sala_Venta_Vino svv
  JOIN Vino v USING (cod_vino)
 WHERE svv.id_sala = :sala_i3 AND svv.cantidad >= 2
 ORDER BY svv.cod_vino
 LIMIT 3;

INSERT INTO Comprobante (fecha, id_sala, id_cliente)
VALUES (CURRENT_DATE, :sala_i3, :id_cliente)
RETURNING nro_comprobante \gset

INSERT INTO Detalle_Comprobante (nro_comprobante, cod_vino, cantidad)
SELECT :nro_comprobante, svv.cod_vino, 2
  FROM Sala_Venta_Vino svv
 WHERE svv.id_sala = :sala_i3 AND svv.cantidad >= 2
 ORDER BY svv.cod_vino
 LIMIT 3;

SELECT d.cod_vino, d.cantidad, d.precio_unitario, d.descuento_aplicado, d.subtotal_renglon,
       fn_stock_sala(:sala_i3, d.cod_vino) AS stock_sala_despues
  FROM Detalle_Comprobante d
 WHERE d.nro_comprobante = :nro_comprobante
 ORDER BY d.cod_vino;

SELECT nro_comprobante, subtotal, descuento, total,
       fn_total_comprobante(nro_comprobante) AS total_calculado
  FROM Comprobante
 WHERE nro_comprobante = :nro_comprobante;

ROLLBACK;


/* ---------------------------------------------------------------------------
   I4. Insertar una nueva bodega.
   Estrategia: INSERT simple. El CUIT tiene que cumplir el DOMAIN cuit_dom
   (11 digitos) y el numero de calle el CHECK numero > 0.
   Filas afectadas: 1.
--------------------------------------------------------------------------- */
BEGIN;

SELECT count(*) AS bodegas FROM Bodega;

INSERT INTO Bodega (cuit_bodega, razon_social, calle, numero)
VALUES ('30712345674', 'Bodega Los Alamos', 'Ruta 143', 2450);

SELECT * FROM Bodega WHERE cuit_bodega = '30712345674';
SELECT count(*) AS bodegas FROM Bodega;

ROLLBACK;


/* ---------------------------------------------------------------------------
   I5. Insertar una nueva sala de venta.
   Estrategia: la localidad se busca por nombre; el dia de cierre respeta
   check_dia_cierre y el id lo genera la base (IDENTITY).
   Filas afectadas: 1.
--------------------------------------------------------------------------- */
BEGIN;

SELECT count(*) AS salas FROM Sala_Venta;

INSERT INTO Sala_Venta (calle, numero, dia_cierre, cod_postal)
SELECT 'Av. Alvear Oeste', 1200, 'Martes', cod_postal
  FROM Localidad
 WHERE nombre = 'General Alvear'
RETURNING *;

SELECT count(*) AS salas FROM Sala_Venta;

ROLLBACK;


/* ---------------------------------------------------------------------------
   I6. Crear un ingreso en confeccion de 120 botellas de un vino determinado
       (750 ml), elaborado por una bodega dada y trasladado por un
       transportista dado.
   Estrategia: el ingreso se crea sin estado ni fecha: los DEFAULT y
   trg_ingreso_estado lo dejan en_confeccion con la fecha de hoy (RN-10). El
   vino se busca por nombre, volumen y bodega, para que sea de esa bodega.
   Como esta en confeccion, el renglon se puede agregar (RN-12). No impacta el
   deposito hasta que se termine y se procese (sp_procesar_ingreso).
   Filas afectadas: 1 ingreso y 1 renglon.
--------------------------------------------------------------------------- */
BEGIN;

SELECT b.cuit_bodega, t.cod_transporte, v.cod_vino
  FROM Bodega b, Transportista t, Vino v
 WHERE b.razon_social = :bodega_i6
   AND t.razon_social = :transportista_i6
   AND v.nombre_comercial = :vino_i6
   AND v.volumen_ml = :volumen_i6
   AND v.cuit_bodega = b.cuit_bodega \gset

SELECT count(*) AS ingresos_en_confeccion FROM Ingreso WHERE estado = 'en_confeccion';

INSERT INTO Ingreso (cuit_bodega, cod_transporte)
VALUES (:'cuit_bodega', :cod_transporte)
RETURNING cod_ingreso, estado, fecha_ingreso \gset

INSERT INTO Ingreso_Vino (cod_ingreso, cod_vino, cantidad)
VALUES (:cod_ingreso, :cod_vino, 120);

SELECT i.cod_ingreso, i.estado, i.fecha_ingreso, iv.cod_vino, iv.cantidad
  FROM Ingreso i
  JOIN Ingreso_Vino iv USING (cod_ingreso)
 WHERE i.cod_ingreso = :cod_ingreso;

SELECT count(*) AS ingresos_en_confeccion FROM Ingreso WHERE estado = 'en_confeccion';

ROLLBACK;
