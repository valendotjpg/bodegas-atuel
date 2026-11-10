-- Monto total de ventas por sala en el último trimestre
CREATE INDEX IF NOT EXISTS idx_ventas_trimestre ON comprobante (fecha) INCLUDE (id_sala, total);

-- Rendimiento en kg por hectarea de cada parcela y campania
-- Índice descartado
CREATE INDEX IF NOT EXISTS idx_rendimiento_parcela ON lote (id_finca, campania) INCLUDE (kilos, nro_parcela);

-- Clientes que compraron todos los vinos de una bodega específica y clientes que nunca compraron vinos tinto
CREATE INDEX IF NOT EXISTS idx_detalle_vino ON detalle_comprobante (cod_vino) INCLUDE (nro_comprobante);

-- Clientes por tipo en una sala en la última semana
CREATE INDEX IF NOT EXISTS idx_comprobante_sala_fecha ON comprobante (id_sala, fecha) INCLUDE (id_cliente);

-- Busqueda de un vino por nombre comercial
-- Índice descartado
CREATE INDEX IF NOT EXISTS idx_vino_nombre_comercial ON vino (nombre_comercial);
