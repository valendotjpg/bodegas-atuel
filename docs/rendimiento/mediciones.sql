-- Monto total de ventas en el último trimestre por sala
SELECT indexname FROM pg_indexes WHERE tablename = 'comprobante';

ANALYZE comprobante;
EXPLAIN (ANALYZE,BUFFERS)
SELECT id_sala, SUM(total) AS monto_total_ventas
  FROM Comprobante
 WHERE fecha >= CURRENT_DATE - INTERVAL '3 months'
 GROUP BY id_sala
 ORDER BY monto_total_ventas DESC;

