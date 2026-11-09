-- Monto total de ventas por sala en el último trimestre
CREATE INDEX IF NOT EXISTS idx_ventas_trimestre ON comprobante (fecha) INCLUDE (id_sala, total);

-- Rendimiento en kg por hectarea de cada parcela y campania
CREATE INDEX IF NOT EXISTS idx_rendimiento_parcela ON lote (id_finca, campania) INCLUDE (kilos, nro_parcela);

-- Clientes que compraron todos los vinos de una bodega específica
CREATE INDEX IF NOT EXISTS idx_compras_bodega ON comprobante (id_cliente) INCLUDE (nro_comprobante);

-- Clientes que nunca compraron vinos tinto
CREATE INDEX IF NOT EXISTS idx_compras_tinto ON comprobante (id_cliente) INCLUDE (nro_comprobante);



