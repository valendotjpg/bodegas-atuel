-- Monto total de ventas por sala en el último trimestre - Índice parcial
CREATE INDEX idx_ventas_trimestre ON comprobante (id_sala, fecha, total)
WHERE fecha >= CURRENT_DATE - INTERVAL '3 months';



