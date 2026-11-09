\set ON_ERROR_STOP on

BEGIN;

CREATE TEMP TABLE test_summary (
    rule text PRIMARY KEY,
    result text NOT NULL
);

DO $$
DECLARE
    v_bodega cuit_dom := '30999999999';
    v_bodega_2 cuit_dom := '30999999998';
    v_transportista int;
    v_localidad int;
    v_cepa int;
    v_maridaje int;
    v_sala int;
    v_sala_2 int;
    v_vino int;
    v_vino_bad int;
    v_deposito int;
    v_socio int;
    v_distribuidor int;
    v_exportador int;
    v_ingreso int;
    v_transferencia int;
    v_comprobante int;
    v_comprobante_bad int;
    v_stock_before int;
    v_stock_after int;
    v_auditoria_before int;
    v_auditoria_after int;
    v_total numeric;
    v_fecha date;
    v_failed boolean;
BEGIN
    -- Datos propios de la prueba: no depende de la carga masiva.
    INSERT INTO localidad (cod_postal, nombre, provincia)
    VALUES (9999, 'Localidad Test', 'Mendoza')
    RETURNING cod_postal INTO v_localidad;
    INSERT INTO encargado (nombre, apellido, cod_postal)
    VALUES ('Encargado', 'Test', v_localidad);
    INSERT INTO cepa (nombre, tipo)
    VALUES ('Cepa Test', 'tinta')
    RETURNING id_cepa INTO v_cepa;
    INSERT INTO maridaje (nombre_maridaje, temperatura_servicio)
    VALUES ('Maridaje Test', 16)
    RETURNING id_maridaje INTO v_maridaje;

    INSERT INTO bodega (cuit_bodega, razon_social, calle, numero)
    VALUES (v_bodega, 'Bodega de pruebas', 'Calle Test', 1),
           (v_bodega_2, 'Bodega de pruebas 2', 'Calle Test', 2);

    INSERT INTO transportista (razon_social, email, cuit, calle, numero)
    VALUES ('Transportista de pruebas', 'test@example.com', '27999999999', 'Calle Test', 3)
    RETURNING cod_transporte INTO v_transportista;

    INSERT INTO sala_venta (calle, numero, dia_cierre, cod_postal)
    VALUES ('Sala Test', 9001, 'Lunes', v_localidad)
    RETURNING id_sala INTO v_sala;

    INSERT INTO sala_venta (calle, numero, dia_cierre, cod_postal)
    VALUES ('Sala Test 2', 9002, 'Martes', v_localidad)
    RETURNING id_sala INTO v_sala_2;

    INSERT INTO cliente
        (razon_social, tipo_documento, nro_documento, calle, numero, cod_postal)
    VALUES ('Cliente socio test', 'DNI', '99000001', 'Calle Test', 1, v_localidad)
    RETURNING id_cliente INTO v_socio;
    INSERT INTO socio (id_cliente) VALUES (v_socio);

    INSERT INTO cliente
        (razon_social, tipo_documento, nro_documento, calle, numero, cod_postal)
    VALUES ('Cliente distribuidor test', 'DNI', '99000002', 'Calle Test', 2, v_localidad)
    RETURNING id_cliente INTO v_distribuidor;
    INSERT INTO distribuidor (id_cliente, zona_cobertura, nro_habilitacion)
    VALUES (v_distribuidor, 'Cuyo', 'TEST-99000002');

    INSERT INTO cliente
        (razon_social, tipo_documento, nro_documento, calle, numero, cod_postal)
    VALUES ('Cliente exportador test', 'DNI', '99000003', 'Calle Test', 3, v_localidad)
    RETURNING id_cliente INTO v_exportador;
    INSERT INTO exportador (id_cliente, pais_destino)
    VALUES (v_exportador, 'Chile');

    -- RN-01 y RN-15: precio positivo y graduación entre 5 y 20.
    v_failed := false;
    BEGIN
        INSERT INTO vino
            (anada, tipo, nombre_comercial, precio, graduacion, volumen_ml, cuit_bodega)
        VALUES (2025, 'tinto', 'Vino RN01 inválido', 0, 12, 750, v_bodega);
    EXCEPTION WHEN check_violation THEN
        v_failed := true;
    END;
    IF NOT v_failed THEN
        RAISE EXCEPTION 'RN-01 no rechazó un precio cero';
    END IF;
    v_failed := false;
    BEGIN
        INSERT INTO vino
            (anada, tipo, nombre_comercial, precio, graduacion, volumen_ml, cuit_bodega)
        VALUES (2025, 'tinto', 'Vino RN15 inválido', 100, 21, 750, v_bodega);
    EXCEPTION WHEN check_violation THEN
        v_failed := true;
    END;
    IF NOT v_failed THEN
        RAISE EXCEPTION 'RN-15 no rechazó graduación fuera de rango';
    END IF;
    INSERT INTO vino
        (anada, tipo, nombre_comercial, precio, graduacion, volumen_ml, cuit_bodega)
    VALUES (2025, 'tinto', 'Vino RN test', 100, 12, 750, v_bodega)
    RETURNING cod_vino INTO v_vino;
    INSERT INTO composicion (cod_vino, id_cepa, porcentaje)
    VALUES (v_vino, v_cepa, 100);
    INSERT INTO vino_maridaje (cod_vino, id_maridaje)
    VALUES (v_vino, v_maridaje);

    -- RN-02 y RN-03: localidad única por encargado y empleado con sala válida.
    v_failed := false;
    BEGIN
        INSERT INTO encargado (nombre, apellido, cod_postal)
        VALUES ('Otro', 'Encargado', v_localidad);
    EXCEPTION WHEN unique_violation THEN
        v_failed := true;
    END;
    IF NOT v_failed THEN
        RAISE EXCEPTION 'RN-02 no rechazó dos encargados para la localidad';
    END IF;
    v_failed := false;
    BEGIN
        INSERT INTO empleado
            (cuit_empleado, nombre, apellido, salario, fecha_ingreso, id_sala)
        VALUES ('20999999999', 'Empleado', 'Inválido', 100, CURRENT_DATE, 999999999);
    EXCEPTION WHEN foreign_key_violation THEN
        v_failed := true;
    END;
    IF NOT v_failed THEN
        RAISE EXCEPTION 'RN-03 no rechazó una sala inexistente';
    END IF;

    -- RN-04: una parcela no puede repetirse en la misma campaña.
    INSERT INTO finca (nombre, superficie_ha, departamento, provincia)
    VALUES ('Finca RN04', 20, 'Maipú', 'Mendoza')
    RETURNING id_finca INTO v_deposito;
    INSERT INTO parcela (id_finca, nro_parcela, superficie, anio_plantacion, id_cepa)
    VALUES (v_deposito, 1, 5, 2020, v_cepa);
    INSERT INTO lote
        (campania, fecha_cosecha, kilos, cuit_bodega, id_finca, nro_parcela)
    VALUES (2025, '2025-03-01', 100, v_bodega, v_deposito, 1);
    v_failed := false;
    BEGIN
        INSERT INTO lote
            (campania, fecha_cosecha, kilos, cuit_bodega, id_finca, nro_parcela)
        VALUES (2025, '2025-03-02', 100, v_bodega, v_deposito, 1);
    EXCEPTION WHEN unique_violation THEN
        v_failed := true;
    END;
    IF NOT v_failed THEN
        RAISE EXCEPTION 'RN-04 no rechazó dos cosechas en la misma campaña';
    END IF;

    -- RN-15: los kilos de un lote son positivos.
    v_failed := false;
    BEGIN
        INSERT INTO lote
            (campania, fecha_cosecha, kilos, cuit_bodega, id_finca, nro_parcela)
        VALUES (2024, '2024-03-01', -5, v_bodega, v_deposito, 1);
    EXCEPTION WHEN check_violation THEN
        v_failed := true;
    END;
    IF NOT v_failed THEN
        RAISE EXCEPTION 'RN-15 aceptó kilos negativos';
    END IF;

    -- RN-05: el trigger diferido exige que la composición sume 100.
    INSERT INTO vino
        (anada, tipo, nombre_comercial, precio, graduacion, volumen_ml, cuit_bodega)
    VALUES (2025, 'blanco', 'Vino composición inválida', 120, 12, 750, v_bodega)
    RETURNING cod_vino INTO v_vino_bad;
    v_failed := false;
    BEGIN
        INSERT INTO composicion (cod_vino, id_cepa, porcentaje)
        VALUES (v_vino_bad, v_cepa, 60);
        SET CONSTRAINTS ALL IMMEDIATE;
    EXCEPTION WHEN check_violation THEN
        v_failed := true;
    END;
    SET CONSTRAINTS ALL DEFERRED;
    IF NOT v_failed THEN
        RAISE EXCEPTION 'RN-05 no rechazó composición distinta de 100';
    END IF;

    -- RN-06: descuento por subtipo y rechazo de cliente sin subtipo.
    IF fn_descuento_cliente(v_socio) <> 10
       OR fn_descuento_cliente(v_distribuidor) <> 20
       OR fn_descuento_cliente(v_exportador) <> 30 THEN
        RAISE EXCEPTION 'RN-06 devolvió descuentos incorrectos';
    END IF;
    v_failed := false;
    BEGIN
        PERFORM fn_descuento_cliente(
            (SELECT id_cliente FROM cliente WHERE nro_documento = '99000001')
        );
    EXCEPTION WHEN OTHERS THEN
        -- El cliente de prueba es socio y debe funcionar; esta rama no debe ejecutarse.
        v_failed := true;
    END;
    IF v_failed THEN
        RAISE EXCEPTION 'RN-06 falló para un socio válido';
    END IF;

    -- RN-06: el descuento se guarda en el subtipo y se puede cambiar (U6), siempre entre 0 y 100.
    UPDATE exportador SET porcentaje_descuento = 35 WHERE id_cliente = v_exportador;
    IF fn_descuento_cliente(v_exportador) <> 35 THEN
        RAISE EXCEPTION 'RN-06 no usó el descuento guardado del exportador';
    END IF;
    UPDATE exportador SET porcentaje_descuento = 30 WHERE id_cliente = v_exportador;
    v_failed := false;
    BEGIN
        UPDATE socio SET porcentaje_descuento = 120 WHERE id_cliente = v_socio;
    EXCEPTION WHEN check_violation THEN
        v_failed := true;
    END;
    IF NOT v_failed THEN
        RAISE EXCEPTION 'RN-06 aceptó un descuento fuera de rango';
    END IF;

    -- Cliente: apellido y nombre o razón social.
    v_failed := false;
    BEGIN
        INSERT INTO cliente (tipo_documento, nro_documento, calle, numero, cod_postal)
        VALUES ('DNI', '99000009', 'Calle Test', 9, v_localidad);
    EXCEPTION WHEN check_violation THEN
        v_failed := true;
    END;
    IF NOT v_failed THEN
        RAISE EXCEPTION 'Cliente sin nombre ni razón social fue aceptado';
    END IF;

    -- RN-07: permiso con vencimiento posterior a emisión.
    v_failed := false;
    BEGIN
        INSERT INTO permiso_exportacion (fecha_emision, fecha_vencimiento, id_cliente)
        VALUES ('2025-01-02', '2025-01-01', v_exportador);
    EXCEPTION WHEN check_violation THEN
        v_failed := true;
    END;
    IF NOT v_failed THEN
        RAISE EXCEPTION 'RN-07 no rechazó permiso vencido antes de emisión';
    END IF;

    INSERT INTO deposito_central (nombre)
    VALUES ('Depósito RN test')
    RETURNING id_deposito INTO v_deposito;
    INSERT INTO stock_deposito (id_deposito, cod_vino, cantidad)
    VALUES (v_deposito, v_vino, 20);
    INSERT INTO sala_venta_vino (id_sala, cod_vino, cantidad)
    VALUES (v_sala, v_vino, 10);

    -- RN-08 y RN-09: cálculo automático y límite de stock.
    INSERT INTO comprobante
        (fecha, subtotal, descuento, total, id_sala, id_cliente)
    VALUES (CURRENT_DATE, 999, 999, 999, v_sala, v_socio)
    RETURNING nro_comprobante INTO v_comprobante;
    INSERT INTO detalle_comprobante
        (nro_comprobante, cod_vino, cantidad, precio_unitario,
         descuento_aplicado, subtotal_renglon)
    VALUES (v_comprobante, v_vino, 2, 0, 0, 0);
    SELECT total INTO v_total FROM comprobante WHERE nro_comprobante = v_comprobante;
    IF v_total <> 180 THEN
        RAISE EXCEPTION 'RN-08 calculó total %, se esperaba 180', v_total;
    END IF;
    v_failed := false;
    BEGIN
        INSERT INTO comprobante
            (fecha, subtotal, descuento, total, id_sala, id_cliente)
        VALUES (CURRENT_DATE, 0, 0, 0, v_sala, v_socio)
        RETURNING nro_comprobante INTO v_comprobante_bad;
        INSERT INTO detalle_comprobante
            (nro_comprobante, cod_vino, cantidad, precio_unitario,
             descuento_aplicado, subtotal_renglon)
        VALUES (v_comprobante_bad, v_vino, 100, 0, 0, 0);
    EXCEPTION WHEN check_violation THEN
        v_failed := true;
    END;
    IF NOT v_failed THEN
        RAISE EXCEPTION 'RN-09 permitió vender más stock del disponible';
    END IF;

    -- RN-10: ingreso terminado impacta una sola vez y queda procesado.
    INSERT INTO ingreso (estado, fecha_ingreso, cuit_bodega, cod_transporte)
    VALUES ('en_confeccion', CURRENT_DATE - 2, v_bodega, v_transportista)
    RETURNING cod_ingreso INTO v_ingreso;
    INSERT INTO ingreso_vino (cod_ingreso, cod_vino, cantidad)
    VALUES (v_ingreso, v_vino, 5);
    UPDATE ingreso SET estado = 'terminado' WHERE cod_ingreso = v_ingreso;
    SELECT cantidad INTO v_stock_before
      FROM stock_deposito WHERE id_deposito = v_deposito AND cod_vino = v_vino;
    CALL sp_procesar_ingreso(v_ingreso, v_deposito);
    SELECT cantidad INTO v_stock_after
      FROM stock_deposito WHERE id_deposito = v_deposito AND cod_vino = v_vino;
    IF v_stock_after <> v_stock_before + 5
       OR (SELECT estado FROM ingreso WHERE cod_ingreso = v_ingreso) <> 'procesado' THEN
        RAISE EXCEPTION 'RN-10 no procesó correctamente el ingreso';
    END IF;
    v_failed := false;
    BEGIN
        UPDATE ingreso SET estado = 'en_confeccion' WHERE cod_ingreso = v_ingreso;
    EXCEPTION WHEN object_not_in_prerequisite_state THEN
        v_failed := true;
    END;
    IF NOT v_failed THEN
        RAISE EXCEPTION 'RN-10 permitió retroceder el estado';
    END IF;

    -- RN-11 y RN-12: fecha actual, transferencia y renglones bloqueados.
    INSERT INTO transferencia (estado, fecha, id_sala)
    VALUES ('en_confeccion', '2000-01-01', v_sala_2)
    RETURNING nro_solicitud INTO v_transferencia;
    SELECT fecha INTO v_fecha FROM transferencia WHERE nro_solicitud = v_transferencia;
    IF v_fecha <> CURRENT_DATE THEN
        RAISE EXCEPTION 'RN-11 no fijó la fecha actual';
    END IF;
    INSERT INTO transferencia_vino (nro_solicitud, cod_vino, cantidad)
    VALUES (v_transferencia, v_vino, 2);
    UPDATE transferencia SET estado = 'terminado' WHERE nro_solicitud = v_transferencia;
    v_failed := false;
    BEGIN
        INSERT INTO transferencia_vino (nro_solicitud, cod_vino, cantidad)
        VALUES (v_transferencia, v_vino_bad, 1);
    EXCEPTION WHEN object_not_in_prerequisite_state THEN
        v_failed := true;
    END;
    IF NOT v_failed THEN
        RAISE EXCEPTION 'RN-12 permitió modificar renglones cerrados';
    END IF;
    v_failed := false;
    BEGIN
        UPDATE transferencia
           SET fecha = CURRENT_DATE - 1
         WHERE nro_solicitud = v_transferencia;
    EXCEPTION WHEN object_not_in_prerequisite_state THEN
        v_failed := true;
    END;
    IF NOT v_failed THEN
        RAISE EXCEPTION 'RN-11 permitió modificar la fecha';
    END IF;
    CALL sp_procesar_transferencia(v_transferencia, v_deposito);
    IF (SELECT estado FROM transferencia WHERE nro_solicitud = v_transferencia) <> 'procesado'
       OR (SELECT cantidad FROM stock_deposito WHERE id_deposito = v_deposito AND cod_vino = v_vino) <> v_stock_after - 2 THEN
        RAISE EXCEPTION 'RN-11 no procesó correctamente la transferencia';
    END IF;

    -- RN-13: actualización de precio deja auditoría.
    SELECT COUNT(*) INTO v_auditoria_before FROM auditoria WHERE cod_vino = v_vino;
    UPDATE vino SET precio = precio + 1 WHERE cod_vino = v_vino;
    SELECT COUNT(*) INTO v_auditoria_after FROM auditoria WHERE cod_vino = v_vino;
    IF v_auditoria_after <> v_auditoria_before + 1 THEN
        RAISE EXCEPTION 'RN-13 no registró el cambio de precio';
    END IF;

    -- RN-14: entidades referenciadas no se pueden borrar.
    v_failed := false;
    BEGIN
        DELETE FROM transportista WHERE cod_transporte = v_transportista;
    EXCEPTION WHEN foreign_key_violation THEN
        v_failed := true;
    END;
    IF NOT v_failed THEN
        RAISE EXCEPTION 'RN-14 permitió borrar transportista referenciado';
    END IF;
    v_failed := false;
    BEGIN
        DELETE FROM bodega WHERE cuit_bodega = v_bodega;
    EXCEPTION WHEN foreign_key_violation THEN
        v_failed := true;
    END;
    IF NOT v_failed THEN
        RAISE EXCEPTION 'RN-14 permitió borrar bodega referenciada';
    END IF;
    v_failed := false;
    BEGIN
        DELETE FROM vino WHERE cod_vino = v_vino;
    EXCEPTION WHEN foreign_key_violation THEN
        v_failed := true;
    END;
    IF NOT v_failed THEN
        RAISE EXCEPTION 'RN-14 permitió borrar vino referenciado';
    END IF;

    INSERT INTO test_summary
    SELECT rule, 'PASS'
    FROM unnest(ARRAY[
        'RN-01','RN-02','RN-03','RN-04','RN-05','RN-06','RN-07','RN-08',
        'RN-09','RN-10','RN-11','RN-12','RN-13','RN-14','RN-15'
    ]) AS rules(rule);
END;
$$;

SELECT rule, result FROM test_summary ORDER BY rule;

ROLLBACK;
