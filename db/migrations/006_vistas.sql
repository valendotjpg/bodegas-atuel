-- Stock total de vinos (depósito + sala de venta)

CREATE OR REPLACE VIEW v_stock_total AS
SELECT v.cod_vino,
         v.nombre_comercial,
         v.anada,
         v.volumen_ml,
         v.precio,
         COALESCE(sd.stock_deposito, 0) AS stock_deposito, -- Con COALESCE (devuelve el primer valor no nulo) para que devuelva 0 si no hay stock en depósito
         COALESCE(sv.stock_sala, 0) AS stock_sala,
         COALESCE(sd.stock_deposito, 0) + COALESCE(sv.stock_sala, 0) AS stock_total
      FROM Vino v
      LEFT JOIN (SELECT cod_vino, SUM(cantidad) AS stock_deposito
                   FROM Stock_Deposito
                  GROUP BY cod_vino) sd ON v.cod_vino = sd.cod_vino
        LEFT JOIN (SELECT cod_vino, SUM(cantidad) AS stock_sala
                   FROM Sala_Venta_Vino
                  GROUP BY cod_vino) sv ON v.cod_vino = sv.cod_vino;

-- Ventas mensuales por sala
CREATE OR REPLACE VIEW v_ventas_mensuales AS
SELECT c.id_sala,
        DATE_TRUNC('month', c.fecha)::date AS mes, -- con ::date para que devuelva solo la fecha (sin hora)
        COUNT(*) AS cantidad_comprobantes,
        SUM(c.total) AS total_vendido
        FROM Comprobante c
         GROUP BY c.id_sala, DATE_TRUNC('month', c.fecha);

-- Documentos pendientes (ingresos y transferencias sin procesar)
CREATE OR REPLACE VIEW v_documentos_pendientes AS
SELECT 'Ingreso' AS tipo_documento,
        i.cod_ingreso AS nro_documento,
        i.fecha_ingreso,
        iv.cod_vino,
        iv.cantidad
   FROM Ingreso i
    JOIN Ingreso_Vino iv ON i.cod_ingreso = iv.cod_ingreso
    WHERE i.estado <> 'procesado'
UNION ALL
SELECT 'Transferencia' AS tipo_documento,
        t.nro_solicitud AS nro_documento,
        t.fecha,
        tv.cod_vino,
        t.cantidad
   FROM Transferencia t
    JOIN Transferencia_Vino tv ON t.nro_solicitud = tv.nro_solicitud
    WHERE t.estado <> 'procesado';



