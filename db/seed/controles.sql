-- Consultas de control requeridas por la etapa 3. Todas deben devolver cero
-- inconsistencias (los conteos de la primera consulta son informativos).
SELECT relname AS tabla, n_live_tup::bigint AS filas
FROM pg_stat_user_tables
ORDER BY relname;

SELECT 'vino_sin_bodega' AS control, COUNT(*) AS inconsistencias
FROM Vino v LEFT JOIN Bodega b ON b.cuit_bodega = v.cuit_bodega
WHERE b.cuit_bodega IS NULL
UNION ALL
SELECT 'stock_negativo', COUNT(*) FROM Stock_Deposito WHERE cantidad < 0
UNION ALL
SELECT 'stock_sala_negativo', COUNT(*) FROM Sala_Venta_Vino WHERE cantidad < 0
UNION ALL
SELECT 'detalle_sin_comprobante', COUNT(*)
FROM Detalle_Comprobante d LEFT JOIN Comprobante c ON c.nro_comprobante = d.nro_comprobante
WHERE c.nro_comprobante IS NULL
UNION ALL
SELECT 'totales_incorrectos', COUNT(*)
FROM Comprobante c
WHERE c.total <> c.subtotal - c.descuento
   OR c.total <> fn_total_comprobante(c.nro_comprobante)
   OR c.subtotal <> COALESCE((SELECT SUM(ROUND(d.cantidad * d.precio_unitario, 2))
                              FROM Detalle_Comprobante d
                              WHERE d.nro_comprobante = c.nro_comprobante), 0)
UNION ALL
SELECT 'descuento_distinto_al_tipo_de_cliente', COUNT(*)
FROM Detalle_Comprobante d JOIN Comprobante c USING (nro_comprobante)
WHERE d.descuento_aplicado <> fn_descuento_cliente(c.id_cliente)
UNION ALL
SELECT 'subtotal_renglon_incorrecto', COUNT(*)
FROM Detalle_Comprobante
WHERE subtotal_renglon <> ROUND(cantidad * precio_unitario * (1 - descuento_aplicado / 100), 2);

SELECT cod_vino, SUM(porcentaje) AS porcentaje_total
FROM Composicion
GROUP BY cod_vino
HAVING SUM(porcentaje) <> 100;
