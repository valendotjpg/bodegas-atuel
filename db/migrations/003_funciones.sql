/*
   003_funciones.sql
   Funciones de cálculo que usan los triggers, los procedimientos y la API.
   La API no recalcula descuentos, totales ni stock: llama a estas funciones.

   Volatilidad:
   - IMMUTABLE: el resultado depende solo de los parámetros (no lee tablas
     ni la fecha actual). PostgreSQL puede evaluarla una vez y reutilizarla.
   - STABLE: lee tablas, pero dentro de una misma sentencia devuelve siempre
     lo mismo para los mismos parámetros. No modifica la base.
*/


/*
   fn_descuento_cliente(p_id_cliente)                                 RN-06
   Propósito : porcentaje de descuento que corresponde al cliente según su
               tipo: socio 10 %, distribuidor 20 %, exportador 30 %.
   Parámetros: p_id_cliente  id del cliente (Cliente.id_cliente).
   Devuelve  : NUMERIC(5,2) en puntos porcentuales (10.00, no 0.10), el mismo
               formato que Detalle_Comprobante.descuento_aplicado.
   Errores   : el cliente no existe, no tiene tipo o tiene más de un tipo
               (la jerarquía es total y disjunta).
   STABLE    : lee Cliente, Socio, Distribuidor y Exportador.
*/
CREATE FUNCTION fn_descuento_cliente(p_id_cliente INT)
RETURNS NUMERIC(5,2)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_es_socio        BOOLEAN;
    v_es_distribuidor BOOLEAN;
    v_es_exportador   BOOLEAN;
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
        RETURN 10.00;
    ELSIF v_es_distribuidor THEN
        RETURN 20.00;
    ELSIF v_es_exportador THEN
        RETURN 30.00;
    END IF;

    RAISE EXCEPTION 'El cliente % no es socio, distribuidor ni exportador', p_id_cliente
        USING ERRCODE = 'data_exception';
END;
$$;

COMMENT ON FUNCTION fn_descuento_cliente(INT) IS
    'RN-06. Porcentaje de descuento según el tipo de cliente (socio 10, distribuidor 20, exportador 30). STABLE.';


/*
   fn_total_comprobante(p_nro_comprobante)                            RN-08
   Propósito : total del comprobante = suma de sus renglones con el descuento
               aplicado. Cada renglón vale
               cantidad * precio_unitario * (1 - descuento_aplicado / 100),
               redondeado a 2 decimales (igual que subtotal_renglon).
               Se calcula desde cantidad, precio y descuento, no desde
               subtotal_renglon, para no depender de un dato derivado.
   Parámetros: p_nro_comprobante  número del comprobante.
   Devuelve  : NUMERIC(12,2). 0.00 si el comprobante todavía no tiene renglones.
   Errores   : el comprobante no existe.
   STABLE    : lee Comprobante y Detalle_Comprobante.
*/
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

COMMENT ON FUNCTION fn_total_comprobante(INT) IS
    'RN-08. Total del comprobante: suma de cantidad * precio * (1 - descuento / 100) de sus renglones. STABLE.';


/*
   fn_stock_sala(p_id_sala, p_cod_vino)                               RN-09
   Propósito : botellas disponibles de un vino en una sala.
   Parámetros: p_id_sala   id de la sala de venta.
               p_cod_vino  código del vino.
   Devuelve  : INT. 0 si la sala no tiene fila de stock para ese vino.
   STABLE    : lee Sala_Venta_Vino.
   Ojo       : solo consulta, no bloquea. Una función STABLE no puede hacer
               SELECT ... FOR UPDATE, así que el trigger de venta tiene que
               bloquear la fila de stock antes de descontar (ver demostración
               de concurrencia).
*/
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

COMMENT ON FUNCTION fn_stock_sala(INT, INT) IS
    'RN-09. Stock de un vino en una sala (0 si no hay fila). No bloquea filas. STABLE.';


/*
   fn_antiguedad_anios(p_desde, p_hasta)
   Propósito : años completos entre dos fechas. Se usa para la antigüedad de
               los empleados (U2: más de 5 años) y de los comprobantes
               (D1: más de 5 años).
   Parámetros: p_desde  fecha inicial (ej. Empleado.fecha_ingreso).
               p_hasta  fecha final; si se omite, CURRENT_DATE.
   Devuelve  : INT. NULL si alguna fecha es NULL (STRICT).
   Errores   : p_desde posterior a p_hasta.
   IMMUTABLE : el cuerpo solo usa los parámetros. El DEFAULT CURRENT_DATE se
               evalúa en la llamada, no dentro de la función, así que la
               función sigue siendo determinística. Por la misma razón no se
               debe usar en un CHECK con el valor por defecto.
*/
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

COMMENT ON FUNCTION fn_antiguedad_anios(DATE, DATE) IS
    'Años completos entre p_desde y p_hasta (por defecto, hoy). IMMUTABLE.';
