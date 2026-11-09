-- fn_descuento_cliente (RN-06): porcentaje de descuento del cliente, guardado en su subtipo
-- (por defecto socio 10, distribuidor 20, exportador 30; U6 puede subirlo).
-- Parámetros: p_id_cliente. STABLE: lee Cliente y sus subtipos.
CREATE FUNCTION fn_descuento_cliente(p_id_cliente INT)
RETURNS NUMERIC(5,2)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_es_socio        BOOLEAN;
    v_es_distribuidor BOOLEAN;
    v_es_exportador   BOOLEAN;
    v_porcentaje      NUMERIC(5,2);
BEGIN
    IF NOT EXISTS (SELECT 1 FROM Cliente WHERE id_cliente = p_id_cliente) THEN
        RAISE EXCEPTION 'El cliente % no existe', p_id_cliente
            USING ERRCODE = 'no_data_found';
    END IF;

    v_es_socio        := EXISTS (SELECT 1 FROM Socio        WHERE id_cliente = p_id_cliente);
    v_es_distribuidor := EXISTS (SELECT 1 FROM Distribuidor WHERE id_cliente = p_id_cliente);
    v_es_exportador   := EXISTS (SELECT 1 FROM Exportador   WHERE id_cliente = p_id_cliente);

    IF v_es_socio::INT + v_es_distribuidor::INT + v_es_exportador::INT > 1 THEN
        RAISE EXCEPTION 'El cliente % tiene más de un tipo (socio, distribuidor, exportador)', p_id_cliente
            USING ERRCODE = 'data_exception';
    END IF;

    IF v_es_socio THEN
        SELECT porcentaje_descuento INTO v_porcentaje FROM Socio WHERE id_cliente = p_id_cliente;
        RETURN v_porcentaje;
    ELSIF v_es_distribuidor THEN
        SELECT porcentaje_descuento INTO v_porcentaje FROM Distribuidor WHERE id_cliente = p_id_cliente;
        RETURN v_porcentaje;
    ELSIF v_es_exportador THEN
        SELECT porcentaje_descuento INTO v_porcentaje FROM Exportador WHERE id_cliente = p_id_cliente;
        RETURN v_porcentaje;
    END IF;

    RAISE EXCEPTION 'El cliente % no es socio, distribuidor ni exportador', p_id_cliente
        USING ERRCODE = 'data_exception';
END;
$$;

-- fn_total_comprobante (RN-08): suma de los renglones con el descuento aplicado (0 si no hay renglones).
-- Parámetros: p_nro_comprobante. STABLE: lee Comprobante y Detalle_Comprobante.
CREATE FUNCTION fn_total_comprobante(p_nro_comprobante INT)
RETURNS NUMERIC(12,2)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_total NUMERIC(12,2);
BEGIN
    IF NOT EXISTS (SELECT 1 FROM Comprobante WHERE nro_comprobante = p_nro_comprobante) THEN
        RAISE EXCEPTION 'El comprobante % no existe', p_nro_comprobante
            USING ERRCODE = 'no_data_found';
    END IF;

    SELECT COALESCE(SUM(ROUND(d.cantidad * d.precio_unitario
                              * (1 - d.descuento_aplicado / 100), 2)), 0)
      INTO v_total
      FROM Detalle_Comprobante d
     WHERE d.nro_comprobante = p_nro_comprobante;

    RETURN v_total;
END;
$$;

-- fn_stock_sala (RN-09): botellas de un vino en una sala (0 si no hay fila). No bloquea filas.
-- Parámetros: p_id_sala, p_cod_vino. STABLE: lee Sala_Venta_Vino.
CREATE FUNCTION fn_stock_sala(p_id_sala INT, p_cod_vino INT)
RETURNS INT
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_cantidad INT;
BEGIN
    SELECT cantidad
      INTO v_cantidad
      FROM Sala_Venta_Vino
     WHERE id_sala = p_id_sala
       AND cod_vino = p_cod_vino;

    RETURN COALESCE(v_cantidad, 0);
END;
$$;

-- fn_antiguedad_anios: años completos entre dos fechas.
-- Parámetros: p_desde, p_hasta (por defecto, hoy). IMMUTABLE: solo usa los parámetros.
CREATE FUNCTION fn_antiguedad_anios(p_desde DATE, p_hasta DATE DEFAULT CURRENT_DATE)
RETURNS INT
LANGUAGE plpgsql
IMMUTABLE
STRICT
AS $$
BEGIN
    IF p_desde > p_hasta THEN
        RAISE EXCEPTION 'La fecha desde (%) es posterior a la fecha hasta (%)', p_desde, p_hasta
            USING ERRCODE = 'invalid_parameter_value';
    END IF;

    RETURN EXTRACT(YEAR FROM age(p_hasta, p_desde))::INT;
END;
$$;
