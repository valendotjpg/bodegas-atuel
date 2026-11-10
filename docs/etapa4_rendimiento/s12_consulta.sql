-- Clientes que compraron todos los vinos de una bodega específica y clientes que nunca compraron vinos tinto
SET jit=off;
\set bodega_s12 '\'Bodega 019\''

ANALYZE comprobante;
ANALYZE detalle_comprobante;
ANALYZE vino;

EXPLAIN (ANALYZE,BUFFERS)
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

EXPLAIN (ANALYZE,BUFFERS)
SELECT count(*) AS clientes_que_nunca_compraron_tinto
  FROM Cliente c
 WHERE NOT EXISTS (SELECT 1
                     FROM Comprobante co
                     JOIN Detalle_Comprobante d ON d.nro_comprobante = co.nro_comprobante
                     JOIN Vino v ON v.cod_vino = d.cod_vino
                    WHERE co.id_cliente = c.id_cliente
                      AND v.tipo = 'tinto');