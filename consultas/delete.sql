/*
   Etapa 5 - Borrado de datos (DELETE), seccion 8.3 del TPI.
   Cada consigna corre en su propia transaccion:
   BEGIN -> control previo -> sentencia -> control posterior -> ROLLBACK.
   Se corre con el rol propietario sobre la base con la carga masiva:
     docker compose cp consultas/delete.sql db:/tmp/delete.sql
     docker compose exec db sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f /tmp/delete.sql'
   Filas afectadas: medidas con la carga por defecto de db/seed/generar.py.
*/

\set ON_ERROR_STOP on

-- Parametros (se cambian aca)
\set localidad_d3 '\'San Rafael\''
\set localidad_d6 '\'General Alvear\''


/* ---------------------------------------------------------------------------
   D1. Borrar los comprobantes con mas de 5 anios de antiguedad asociados a
       clientes socios del club.
   Estrategia: DELETE ... USING Socio para filtrar por tipo de cliente; la
   antiguedad se calcula con CURRENT_DATE.
   Constraints: los renglones se borran solos por ON DELETE CASCADE de
   fk_detalle_comprobante_comprobante. El stock no se devuelve: es historial.
   Filas afectadas: 0 (la carga tiene comprobantes de los ultimos 3 anios).
--------------------------------------------------------------------------- */
BEGIN;

SELECT count(*) AS comprobantes,
       (SELECT count(*) FROM Detalle_Comprobante d JOIN Comprobante c2 USING (nro_comprobante)
          JOIN Socio s2 ON s2.id_cliente = c2.id_cliente
         WHERE c2.fecha < CURRENT_DATE - INTERVAL '5 years') AS renglones
  FROM Comprobante c
  JOIN Socio s ON s.id_cliente = c.id_cliente
 WHERE c.fecha < CURRENT_DATE - INTERVAL '5 years';

DELETE FROM Comprobante c
 USING Socio s
 WHERE s.id_cliente = c.id_cliente
   AND c.fecha < CURRENT_DATE - INTERVAL '5 years';

SELECT count(*) AS comprobantes_restantes
  FROM Comprobante c
  JOIN Socio s ON s.id_cliente = c.id_cliente
 WHERE c.fecha < CURRENT_DATE - INTERVAL '5 years';

ROLLBACK;


/* ---------------------------------------------------------------------------
   D2. Eliminar las cepas que no componen ningun vino ni estan plantadas en
       ninguna parcela.
   Estrategia: doble NOT EXISTS (anti-join) contra Composicion y Parcela.
   Constraints: si se intentara borrar una cepa en uso, las FK con ON DELETE
   RESTRICT lo impedirian; el NOT EXISTS evita llegar a ese error.
   Filas afectadas: 0 (las 12 cepas del catalogo estan en uso).
--------------------------------------------------------------------------- */
BEGIN;

SELECT count(*) AS cepas,
       count(*) FILTER (WHERE NOT EXISTS (SELECT 1 FROM Composicion co WHERE co.id_cepa = c.id_cepa)
                          AND NOT EXISTS (SELECT 1 FROM Parcela p WHERE p.id_cepa = c.id_cepa)) AS sin_uso
  FROM Cepa c;

DELETE FROM Cepa c
 WHERE NOT EXISTS (SELECT 1 FROM Composicion co WHERE co.id_cepa = c.id_cepa)
   AND NOT EXISTS (SELECT 1 FROM Parcela p WHERE p.id_cepa = c.id_cepa);

SELECT count(*) AS cepas FROM Cepa;

ROLLBACK;


/* ---------------------------------------------------------------------------
   D3. La sala de una localidad determinada fue dada de baja: eliminar los
       empleados de esa sala que trabajaron menos de dos anios.
   Estrategia: subconsulta con las salas de la localidad (por nombre) y
   fn_antiguedad_anios(fecha_ingreso) < 2. Se borran solo esos empleados,
   la sala no (la consigna no lo pide).
   Filas afectadas: 1.
--------------------------------------------------------------------------- */
BEGIN;

SELECT e.cuit_empleado, e.apellido, e.fecha_ingreso,
       fn_antiguedad_anios(e.fecha_ingreso) AS antiguedad
  FROM Empleado e
 WHERE e.id_sala IN (SELECT s.id_sala
                       FROM Sala_Venta s
                       JOIN Localidad l USING (cod_postal)
                      WHERE l.nombre = :localidad_d3)
 ORDER BY e.fecha_ingreso;

DELETE FROM Empleado e
 WHERE e.id_sala IN (SELECT s.id_sala
                       FROM Sala_Venta s
                       JOIN Localidad l USING (cod_postal)
                      WHERE l.nombre = :localidad_d3)
   AND fn_antiguedad_anios(e.fecha_ingreso) < 2;

SELECT count(*) AS empleados_restantes
  FROM Empleado e
 WHERE e.id_sala IN (SELECT s.id_sala
                       FROM Sala_Venta s
                       JOIN Localidad l USING (cod_postal)
                      WHERE l.nombre = :localidad_d3);

ROLLBACK;


/* ---------------------------------------------------------------------------
   D4. Borrar los clientes socios que nunca compraron y se dieron de alta hace
       mas de 5 anios.
   Estrategia: DELETE ... USING Socio con NOT EXISTS sobre Comprobante. Se
   borra de Cliente: la fila de Socio se va por ON DELETE CASCADE.
   Constraints: un socio con compras no se podria borrar (fk_comprobante_cliente
   es RESTRICT); el NOT EXISTS lo excluye.
   Filas afectadas: 0 (en la carga todos los clientes tienen compras).
--------------------------------------------------------------------------- */
BEGIN;

SELECT count(*) AS socios_a_borrar
  FROM Cliente c
  JOIN Socio s ON s.id_cliente = c.id_cliente
 WHERE c.fecha_alta < CURRENT_DATE - INTERVAL '5 years'
   AND NOT EXISTS (SELECT 1 FROM Comprobante co WHERE co.id_cliente = c.id_cliente);

DELETE FROM Cliente c
 USING Socio s
 WHERE s.id_cliente = c.id_cliente
   AND c.fecha_alta < CURRENT_DATE - INTERVAL '5 years'
   AND NOT EXISTS (SELECT 1 FROM Comprobante co WHERE co.id_cliente = c.id_cliente);

SELECT count(*) AS socios FROM Socio;

ROLLBACK;


/* ---------------------------------------------------------------------------
   D5. Eliminar los ingresos en estado procesado de hace mas de 365 dias.
   Estrategia: filtro por estado y por fecha_ingreso < CURRENT_DATE - 365.
   Constraints y triggers: los renglones se borran por ON DELETE CASCADE. El
   trigger de bloqueo de renglones (RN-12) no lo impide, porque cuando corre
   la cascada el ingreso ya no existe. El stock del deposito no cambia.
   Filas afectadas: 0 (la carga no tiene ingresos procesados).
--------------------------------------------------------------------------- */
BEGIN;

SELECT count(*) AS ingresos,
       (SELECT count(*) FROM Ingreso_Vino iv JOIN Ingreso i2 USING (cod_ingreso)
         WHERE i2.estado = 'procesado' AND i2.fecha_ingreso < CURRENT_DATE - 365) AS renglones
  FROM Ingreso
 WHERE estado = 'procesado' AND fecha_ingreso < CURRENT_DATE - 365;

DELETE FROM Ingreso
 WHERE estado = 'procesado'
   AND fecha_ingreso < CURRENT_DATE - 365;

SELECT count(*) AS ingresos_restantes
  FROM Ingreso
 WHERE estado = 'procesado' AND fecha_ingreso < CURRENT_DATE - 365;

ROLLBACK;


/* ---------------------------------------------------------------------------
   D6. Borrar los clientes socios sin compras que viven en una localidad
       especifica.
   Estrategia: igual que D4, filtrando por la localidad del cliente (por
   nombre) en lugar de la fecha de alta.
   Filas afectadas: 0 (en la carga todos los clientes tienen compras).
--------------------------------------------------------------------------- */
BEGIN;

SELECT count(*) AS socios_a_borrar
  FROM Cliente c
  JOIN Socio s ON s.id_cliente = c.id_cliente
  JOIN Localidad l ON l.cod_postal = c.cod_postal
 WHERE l.nombre = :localidad_d6
   AND NOT EXISTS (SELECT 1 FROM Comprobante co WHERE co.id_cliente = c.id_cliente);

DELETE FROM Cliente c
 USING Socio s, Localidad l
 WHERE s.id_cliente = c.id_cliente
   AND l.cod_postal = c.cod_postal
   AND l.nombre = :localidad_d6
   AND NOT EXISTS (SELECT 1 FROM Comprobante co WHERE co.id_cliente = c.id_cliente);

SELECT count(*) AS socios_en_la_localidad
  FROM Cliente c
  JOIN Socio s ON s.id_cliente = c.id_cliente
  JOIN Localidad l ON l.cod_postal = c.cod_postal
 WHERE l.nombre = :localidad_d6;

ROLLBACK;
