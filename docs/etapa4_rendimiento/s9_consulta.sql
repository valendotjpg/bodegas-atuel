\set vino_s9 '\'Reserva Atuel 00000\''


EXPLAIN (ANALYZE,BUFFERS)
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