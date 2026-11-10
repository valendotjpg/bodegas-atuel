-- Clientes por tipo en una sala en la última semana

\set sala_s3 6
EXPLAIN (ANALYZE, BUFFERS)
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