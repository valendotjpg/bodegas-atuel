/*
   Etapa 5 - Consultas (SELECT), secciones 8.4 y 8.5 del TPI.
   Se corre sobre la base con la carga masiva (cualquier rol con lectura):
     docker compose cp consultas/select.sql db:/tmp/select.sql
     docker compose exec db sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f /tmp/select.sql'
   Los LIMIT marcados "para mostrar" solo acortan la salida en pantalla.
   Al final: EXPLAIN (ANALYZE) de S9 a S12.
*/

\set ON_ERROR_STOP on

-- Parametros (se cambian aca)
\set sala_s3 6
\set vino_s4 '\'Reserva Atuel 00000\''
\set sala_s6 2
\set vino_s9 '\'Reserva Atuel 00000\''
\set bodega_s12 '\'Bodega 019\''


/* ---------------------------------------------------------------------------
   S1. Ranking de los 10 vinos con mayor cantidad de botellas vendidas en toda
       la red de salas.
   Estrategia: suma de cantidades de los renglones por vino, orden descendente
   y LIMIT 10.
--------------------------------------------------------------------------- */
SELECT v.cod_vino, v.nombre_comercial, SUM(d.cantidad) AS botellas
  FROM Detalle_Comprobante d
  JOIN Vino v ON v.cod_vino = d.cod_vino
 GROUP BY v.cod_vino, v.nombre_comercial
 ORDER BY botellas DESC, v.cod_vino
 LIMIT 10;


/* ---------------------------------------------------------------------------
   S2. Codigos y nombres de los vinos que se vendieron en todas las salas
       (division relacional).
   Estrategia: division por conteo. Un vino se vendio en todas las salas si
   la cantidad de salas distintas donde se vendio es igual al total de salas.
   La version con doble NOT EXISTS es equivalente (ver S12); aca se usa el
   conteo porque recorre los renglones una sola vez.
--------------------------------------------------------------------------- */
SELECT v.cod_vino, v.nombre_comercial
  FROM Vino v
  JOIN Detalle_Comprobante d ON d.cod_vino = v.cod_vino
  JOIN Comprobante c ON c.nro_comprobante = d.nro_comprobante
 GROUP BY v.cod_vino, v.nombre_comercial
HAVING count(DISTINCT c.id_sala) = (SELECT count(*) FROM Sala_Venta)
 ORDER BY v.cod_vino
 LIMIT 10;  -- para mostrar

SELECT count(*) AS vinos_vendidos_en_todas_las_salas
  FROM (SELECT d.cod_vino
          FROM Detalle_Comprobante d
          JOIN Comprobante c ON c.nro_comprobante = d.nro_comprobante
         GROUP BY d.cod_vino
        HAVING count(DISTINCT c.id_sala) = (SELECT count(*) FROM Sala_Venta)) x;


/* ---------------------------------------------------------------------------
   S3. Cantidad de clientes de cada tipo que compraron en una sala determinada
       (parametro :sala_s3) en la ultima semana.
   Estrategia: el tipo sale de en que subtipo esta el cliente (LEFT JOIN a
   Socio y Distribuidor; si no esta en ninguno es exportador). count(DISTINCT)
   para no contar dos veces a un cliente con varias compras.
--------------------------------------------------------------------------- */
SELECT CASE
           WHEN s.id_cliente IS NOT NULL THEN 'socio'
           WHEN d.id_cliente IS NOT NULL THEN 'distribuidor'
           ELSE 'exportador'
       END AS tipo_cliente,
       count(DISTINCT c.id_cliente) AS clientes
  FROM Comprobante c
  LEFT JOIN Socio s ON s.id_cliente = c.id_cliente
  LEFT JOIN Distribuidor d ON d.id_cliente = c.id_cliente
 WHERE c.id_sala = :sala_s3
   AND c.fecha > CURRENT_DATE - 7
 GROUP BY 1
 ORDER BY 1;


/* ---------------------------------------------------------------------------
   S4. Top 5 de las salas que solicitaron mayor cantidad de un vino determinado
       (parametro :vino_s4) mediante transferencias en los ultimos 15 dias.
   Estrategia: suma de botellas de los renglones de transferencia del vino,
   por sala, con fecha >= CURRENT_DATE - 15.
--------------------------------------------------------------------------- */
SELECT t.id_sala, SUM(tv.cantidad) AS botellas_solicitadas, count(*) AS transferencias
  FROM Transferencia t
  JOIN Transferencia_Vino tv ON tv.nro_solicitud = t.nro_solicitud
  JOIN Vino v ON v.cod_vino = tv.cod_vino
 WHERE v.nombre_comercial = :vino_s4
   AND t.fecha >= CURRENT_DATE - 15
 GROUP BY t.id_sala
 ORDER BY botellas_solicitadas DESC, t.id_sala
 LIMIT 5;


/* ---------------------------------------------------------------------------
   S5. Listado de las salas con menor cantidad de transferencias pendientes
       (no procesadas).
   Estrategia: CTE con las pendientes por sala. LEFT JOIN con la condicion en
   el ON para que las salas sin pendientes cuenten 0. Se listan todas las que
   empatan en el minimo.
--------------------------------------------------------------------------- */
WITH pendientes AS (
    SELECT s.id_sala, count(t.nro_solicitud) AS pendientes
      FROM Sala_Venta s
      LEFT JOIN Transferencia t ON t.id_sala = s.id_sala
                               AND t.estado <> 'procesado'
     GROUP BY s.id_sala
)
SELECT id_sala, pendientes
  FROM pendientes
 WHERE pendientes = (SELECT min(pendientes) FROM pendientes)
 ORDER BY id_sala;


/* ---------------------------------------------------------------------------
   S6. Para una sala determinada (parametro :sala_s6), los vinos sin stock en
       la sala pero con stock en el deposito central.
   Estrategia: anti-join con NOT EXISTS. "Sin stock" incluye no tener fila en
   Sala_Venta_Vino o tenerla en 0.
--------------------------------------------------------------------------- */
SELECT v.cod_vino, v.nombre_comercial, sd.cantidad AS stock_deposito
  FROM Vino v
  JOIN Stock_Deposito sd ON sd.cod_vino = v.cod_vino AND sd.cantidad > 0
 WHERE NOT EXISTS (SELECT 1
                     FROM Sala_Venta_Vino svv
                    WHERE svv.id_sala = :sala_s6
                      AND svv.cod_vino = v.cod_vino
                      AND svv.cantidad > 0)
 ORDER BY v.cod_vino
 LIMIT 10;  -- para mostrar

SELECT count(*) AS vinos_sin_stock_en_sala_con_stock_en_deposito
  FROM Vino v
  JOIN Stock_Deposito sd ON sd.cod_vino = v.cod_vino AND sd.cantidad > 0
 WHERE NOT EXISTS (SELECT 1
                     FROM Sala_Venta_Vino svv
                    WHERE svv.id_sala = :sala_s6
                      AND svv.cod_vino = v.cod_vino
                      AND svv.cantidad > 0);


/* ---------------------------------------------------------------------------
   S7. Cual es la empresa de transporte con mayor actividad en el ultimo mes.
   Estrategia: actividad = cantidad de ingresos trasladados con fecha del
   ultimo mes (tambien se muestran las botellas). FETCH FIRST 1 ROWS WITH TIES
   devuelve todas si hay empate.
--------------------------------------------------------------------------- */
SELECT t.cod_transporte, t.razon_social,
       count(DISTINCT i.cod_ingreso) AS ingresos, SUM(iv.cantidad) AS botellas
  FROM Transportista t
  JOIN Ingreso i ON i.cod_transporte = t.cod_transporte
  JOIN Ingreso_Vino iv ON iv.cod_ingreso = i.cod_ingreso
 WHERE i.fecha_ingreso >= CURRENT_DATE - INTERVAL '1 month'
 GROUP BY t.cod_transporte, t.razon_social
 ORDER BY ingresos DESC
 FETCH FIRST 1 ROWS WITH TIES;


/* ---------------------------------------------------------------------------
   S8. Monto total de ventas por sala en el ultimo trimestre, en orden
       descendente.
   Estrategia: suma de los totales de los comprobantes de los ultimos 3 meses.
   LEFT JOIN con la condicion en el ON para incluir salas sin ventas (0).
--------------------------------------------------------------------------- */
SELECT s.id_sala, l.nombre AS localidad, COALESCE(SUM(c.total), 0) AS total_vendido
  FROM Sala_Venta s
  JOIN Localidad l ON l.cod_postal = s.cod_postal
  LEFT JOIN Comprobante c ON c.id_sala = s.id_sala
                         AND c.fecha >= CURRENT_DATE - INTERVAL '3 months'
 GROUP BY s.id_sala, l.nombre
 ORDER BY total_vendido DESC, s.id_sala;


/* ---------------------------------------------------------------------------
   S9. Ficha de un vino (parametro :vino_s9): cepas con sus porcentajes,
       bodega elaboradora, maridajes y stock total (deposito mas salas).
   Herramienta: joins, agregacion y vista.
   Estrategia: joins con Bodega y Composicion/Cepa agregando las cepas con
   string_agg; los maridajes en una subconsulta agregada aparte, para no
   multiplicar filas; el stock sale de la vista v_stock_total (006).
--------------------------------------------------------------------------- */
SELECT v.cod_vino, v.nombre_comercial, v.tipo, v.anada, v.volumen_ml, v.precio,
       b.razon_social AS bodega,
       string_agg(ce.nombre || ' ' || co.porcentaje || ' %', ', ' ORDER BY co.porcentaje DESC) AS cepas,
       (SELECT string_agg(m.nombre_maridaje, ', ' ORDER BY m.nombre_maridaje)
          FROM Vino_Maridaje vm
          JOIN Maridaje m ON m.id_maridaje = vm.id_maridaje
         WHERE vm.cod_vino = v.cod_vino) AS maridajes,
       st.stock_deposito, st.stock_sala, st.stock_total
  FROM Vino v
  JOIN Bodega b ON b.cuit_bodega = v.cuit_bodega
  JOIN Composicion co ON co.cod_vino = v.cod_vino
  JOIN Cepa ce ON ce.id_cepa = co.id_cepa
  JOIN v_stock_total st ON st.cod_vino = v.cod_vino
 WHERE v.nombre_comercial = :vino_s9
 GROUP BY v.cod_vino, b.razon_social, st.stock_deposito, st.stock_sala, st.stock_total;


/* ---------------------------------------------------------------------------
   S10. Rendimiento en kg por hectarea de cada parcela y campania, e
        identificar las parcelas que rinden menos que el promedio de su finca.
   Herramienta: CTE y subconsulta correlacionada.
   Estrategia: la CTE calcula kilos del lote / superficie de la parcela
   (en hectareas). La subconsulta correlacionada compara cada parcela con el
   promedio de las parcelas de su misma finca en la misma campania, asi no se
   mezclan cosechas de anios distintos.
   Rendimiento: la subconsulta se evalua por cada fila (5000 x 5000), ~1,5 s.
   AVG(kg_por_ha) OVER (PARTITION BY id_finca, campania) daria lo mismo en una
   sola pasada; se deja la correlacionada porque es la herramienta pedida.
--------------------------------------------------------------------------- */
WITH rendimiento AS (
    SELECT l.id_finca, l.nro_parcela, l.campania,
           ROUND(l.kilos / p.superficie, 2) AS kg_por_ha
      FROM Lote l
      JOIN Parcela p ON p.id_finca = l.id_finca AND p.nro_parcela = l.nro_parcela
)
SELECT r.id_finca, r.nro_parcela, r.campania, r.kg_por_ha,
       ROUND((SELECT AVG(r2.kg_por_ha)
                FROM rendimiento r2
               WHERE r2.id_finca = r.id_finca
                 AND r2.campania = r.campania), 2) AS promedio_finca,
       r.kg_por_ha < (SELECT AVG(r2.kg_por_ha)
                        FROM rendimiento r2
                       WHERE r2.id_finca = r.id_finca
                         AND r2.campania = r.campania) AS rinde_menos
  FROM rendimiento r
 ORDER BY r.id_finca, r.campania, r.nro_parcela
 LIMIT 10;  -- para mostrar

WITH rendimiento AS (
    SELECT l.id_finca, l.nro_parcela, l.campania,
           ROUND(l.kilos / p.superficie, 2) AS kg_por_ha
      FROM Lote l
      JOIN Parcela p ON p.id_finca = l.id_finca AND p.nro_parcela = l.nro_parcela
)
SELECT count(*) AS parcelas_que_rinden_menos_que_su_finca
  FROM rendimiento r
 WHERE r.kg_por_ha < (SELECT AVG(r2.kg_por_ha)
                        FROM rendimiento r2
                       WHERE r2.id_finca = r.id_finca
                         AND r2.campania = r.campania);


/* ---------------------------------------------------------------------------
   S11. Ranking de vinos dentro de cada sala por botellas vendidas, y ventas
        acumuladas mensuales por sala.
   Herramienta: RANK() OVER (PARTITION BY ...) y suma acumulada con ventana.
   Estrategia: (a) RANK() particionado por sala sobre las botellas de cada
   vino; RANK deja huecos si hay empates. Se muestran los 3 primeros de cada
   sala. (b) ventas por sala y mes, y SUM(...) OVER (PARTITION BY sala, anio
   ORDER BY mes) acumula dentro de cada anio calendario.
--------------------------------------------------------------------------- */
SELECT id_sala, ranking, cod_vino, botellas
  FROM (SELECT c.id_sala, d.cod_vino, SUM(d.cantidad) AS botellas,
               RANK() OVER (PARTITION BY c.id_sala ORDER BY SUM(d.cantidad) DESC) AS ranking
          FROM Detalle_Comprobante d
          JOIN Comprobante c ON c.nro_comprobante = d.nro_comprobante
         GROUP BY c.id_sala, d.cod_vino) r
 WHERE ranking <= 3
 ORDER BY id_sala, ranking, cod_vino
 LIMIT 9;  -- para mostrar (3 salas)

SELECT id_sala, mes, ventas_mes,
       SUM(ventas_mes) OVER (PARTITION BY id_sala, date_trunc('year', mes) ORDER BY mes) AS acumulado_anio
  FROM (SELECT c.id_sala, date_trunc('month', c.fecha)::date AS mes, SUM(c.total) AS ventas_mes
          FROM Comprobante c
         GROUP BY c.id_sala, date_trunc('month', c.fecha)) m
 WHERE date_trunc('year', mes) = date_trunc('year', CURRENT_DATE)
 ORDER BY id_sala, mes
 LIMIT 12;  -- para mostrar (anio actual de la primera sala)


/* ---------------------------------------------------------------------------
   S12. Clientes que compraron todos los vinos de una bodega determinada
        (parametro :bodega_s12), y clientes que nunca compraron ningun vino
        tinto.
   Herramienta: NOT EXISTS (division) y anti-join.
   Estrategia: (a) division con doble NOT EXISTS: no existe un vino de la
   bodega que el cliente no haya comprado. La CTE materializa antes los pares
   (cliente, vino) de esa bodega, asi cada NOT EXISTS se resuelve contra una
   tabla chica. (b) anti-join: clientes para los que no existe ningun renglon
   de un vino tinto.
--------------------------------------------------------------------------- */
WITH compras_bodega AS MATERIALIZED (
    SELECT DISTINCT co.id_cliente, d.cod_vino
      FROM Comprobante co
      JOIN Detalle_Comprobante d ON d.nro_comprobante = co.nro_comprobante
      JOIN Vino v ON v.cod_vino = d.cod_vino
      JOIN Bodega b ON b.cuit_bodega = v.cuit_bodega
     WHERE b.razon_social = :bodega_s12
)
SELECT count(*) AS clientes_que_compraron_todos_los_vinos_de_la_bodega
  FROM Cliente c
 WHERE NOT EXISTS (SELECT 1
                     FROM Vino v
                     JOIN Bodega b ON b.cuit_bodega = v.cuit_bodega
                    WHERE b.razon_social = :bodega_s12
                      AND NOT EXISTS (SELECT 1
                                        FROM compras_bodega cb
                                       WHERE cb.id_cliente = c.id_cliente
                                         AND cb.cod_vino = v.cod_vino));

SELECT count(*) AS clientes_que_nunca_compraron_tinto
  FROM Cliente c
 WHERE NOT EXISTS (SELECT 1
                     FROM Comprobante co
                     JOIN Detalle_Comprobante d ON d.nro_comprobante = co.nro_comprobante
                     JOIN Vino v ON v.cod_vino = d.cod_vino
                    WHERE co.id_cliente = c.id_cliente
                      AND v.tipo = 'tinto');


/* ===========================================================================
   EXPLAIN (ANALYZE) de las consultas avanzadas S9 a S12 (paso 6 de la etapa).
   Ejecutan la consulta y muestran el plan real con tiempos. Medido con la
   carga por defecto y sin los indices de la etapa 4:
     S9  ~4 ms     (busqueda de un vino; la vista agrega todo el stock)
     S10 ~1,5 s    (subconsulta correlacionada por fila, ver S10)
     S11 ~200 ms   (Parallel Seq Scan de renglones y comprobantes)
     S12 ~190 ms   (Hash Anti Join: el NOT EXISTS se resuelve en una pasada)
=========================================================================== */

\echo '===== EXPLAIN S9 ====='
EXPLAIN (ANALYZE)
SELECT v.cod_vino, v.nombre_comercial, b.razon_social,
       string_agg(ce.nombre || ' ' || co.porcentaje || ' %', ', ') AS cepas,
       (SELECT string_agg(m.nombre_maridaje, ', ')
          FROM Vino_Maridaje vm JOIN Maridaje m ON m.id_maridaje = vm.id_maridaje
         WHERE vm.cod_vino = v.cod_vino) AS maridajes,
       st.stock_total
  FROM Vino v
  JOIN Bodega b ON b.cuit_bodega = v.cuit_bodega
  JOIN Composicion co ON co.cod_vino = v.cod_vino
  JOIN Cepa ce ON ce.id_cepa = co.id_cepa
  JOIN v_stock_total st ON st.cod_vino = v.cod_vino
 WHERE v.nombre_comercial = :vino_s9
 GROUP BY v.cod_vino, b.razon_social, st.stock_total;

\echo '===== EXPLAIN S10 ====='
EXPLAIN (ANALYZE)
WITH rendimiento AS (
    SELECT l.id_finca, l.nro_parcela, l.campania, ROUND(l.kilos / p.superficie, 2) AS kg_por_ha
      FROM Lote l
      JOIN Parcela p ON p.id_finca = l.id_finca AND p.nro_parcela = l.nro_parcela
)
SELECT count(*)
  FROM rendimiento r
 WHERE r.kg_por_ha < (SELECT AVG(r2.kg_por_ha) FROM rendimiento r2
                       WHERE r2.id_finca = r.id_finca AND r2.campania = r.campania);

\echo '===== EXPLAIN S11 ====='
EXPLAIN (ANALYZE)
SELECT id_sala, ranking, cod_vino, botellas
  FROM (SELECT c.id_sala, d.cod_vino, SUM(d.cantidad) AS botellas,
               RANK() OVER (PARTITION BY c.id_sala ORDER BY SUM(d.cantidad) DESC) AS ranking
          FROM Detalle_Comprobante d
          JOIN Comprobante c ON c.nro_comprobante = d.nro_comprobante
         GROUP BY c.id_sala, d.cod_vino) r
 WHERE ranking <= 3;

\echo '===== EXPLAIN S12 (b) ====='
EXPLAIN (ANALYZE)
SELECT count(*)
  FROM Cliente c
 WHERE NOT EXISTS (SELECT 1
                     FROM Comprobante co
                     JOIN Detalle_Comprobante d ON d.nro_comprobante = co.nro_comprobante
                     JOIN Vino v ON v.cod_vino = d.cod_vino
                    WHERE co.id_cliente = c.id_cliente AND v.tipo = 'tinto');
