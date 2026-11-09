-- Monto total de ventas por sala en el último trimestre
CREATE INDEX idx_ventas_trimestre ON comprobante (fecha) INCLUDE (id_sala, total);




