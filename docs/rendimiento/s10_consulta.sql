/*Rendimiento en kg por hectarea de cada parcela y campania, e
        identificar las parcelas que rinden menos que el promedio de su finca.
   Herramienta: CTE y subconsulta correlacionada.
   Estrategia: la CTE calcula kilos del lote / superficie de la parcela
   (en hectareas). La subconsulta correlacionada compara cada parcela con el
   promedio de las parcelas de su misma finca en la misma campania, asi no se
   mezclan cosechas de anios distintos.
   Rendimiento: la subconsulta se evalua por cada fila (5000 x 5000), ~1,5 s.
   AVG(kg_por_ha) OVER (PARTITION BY id_finca, campania) daria lo mismo en una
   sola pasada; se deja la correlacionada porque es la herramienta pedida.
*/
ANALYZE lote;
EXPLAIN (ANALYZE,BUFFERS)
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