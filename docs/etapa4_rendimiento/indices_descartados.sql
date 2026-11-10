-- Indices evaluados y descartados en la etapa 4. NO forman parte de las
-- migraciones. Los planes que justifican el descarte estan en este directorio.

-- S9. Ficha de un vino por nombre comercial.
-- Descartado: duplica el indice que ya crea unique_nombre
-- (nombre_comercial, anada, volumen_ml). El tiempo no cambia
-- (s9_antes.txt 2,08 ms vs s9_despues.txt 2,11 ms) y solo agrega costo de
-- escritura.
-- CREATE INDEX idx_vino_nombre_comercial ON vino (nombre_comercial);

-- S10. Rendimiento por parcela y campania (subconsulta correlacionada).
-- Descartado: el planificador no lo usa. La CTE se materializa y las
-- subconsultas recorren la CTE, no la tabla lote (planes identicos en
-- s10_antes.txt y s10_despues.txt: 933,7 ms vs 929,2 ms). Es el caso de
-- "indice existente que el planificador no usa" pedido en la etapa 4.
-- CREATE INDEX idx_rendimiento_parcela ON lote (id_finca, campania) INCLUDE (kilos, nro_parcela);
