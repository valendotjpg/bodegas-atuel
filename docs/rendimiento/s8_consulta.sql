-- Monto total de ventas en el último trimestre por sala
/* 
   Herramienta: Función de agregación y filtrado.
   Estrategia: Se filtra por fecha en el último trimestre y se agrupa por sala.
   Rendimiento: la consulta se ejecuta en menos de 1 segundo.
*/
ANALYZE comprobante;
EXPLAIN (ANALYZE,BUFFERS)
SELECT id_sala, SUM(total) AS monto_total_ventas
  FROM Comprobante
 WHERE fecha >= CURRENT_DATE - INTERVAL '3 months'
 GROUP BY id_sala
 ORDER BY monto_total_ventas DESC;

