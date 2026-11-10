/*
   Procedimientos transaccionales.
   Las excepciones abortan el CALL y revierten sus modificaciones.

   RN-10: procesamiento de ingresos al deposito central.
   RN-11: procesamiento de transferencias a salas de venta.
*/

-- RN-10
-- Proposito: incorporar al deposito el contenido de un ingreso terminado.
-- Parametros: p_cod_ingreso identifica el ingreso y p_id_deposito el deposito.
-- Uso: CALL sp_procesar_ingreso(1, 1);
CREATE OR REPLACE PROCEDURE sp_procesar_ingreso(
    p_cod_ingreso INT,
    p_id_deposito INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_estado estado_documento;
    v_item RECORD;
BEGIN
    IF NOT EXISTS (
        SELECT 1
          FROM Deposito_Central
         WHERE id_deposito = p_id_deposito
    ) THEN
        RAISE EXCEPTION
            'El deposito % no existe',
            p_id_deposito;
    END IF;

    SELECT estado
      INTO v_estado
      FROM Ingreso
     WHERE cod_ingreso = p_cod_ingreso
     FOR UPDATE;

    IF NOT FOUND OR v_estado IS DISTINCT FROM 'terminado' THEN
        RAISE EXCEPTION
            'El ingreso % no existe o no esta terminado (RN-10)',
            p_cod_ingreso;
    END IF;

    IF NOT EXISTS (
        SELECT 1
          FROM Ingreso_Vino
         WHERE cod_ingreso = p_cod_ingreso
    ) THEN
        RAISE EXCEPTION
            'El ingreso % no tiene vinos',
            p_cod_ingreso;
    END IF;

    FOR v_item IN
        SELECT cod_vino, cantidad
          FROM Ingreso_Vino
         WHERE cod_ingreso = p_cod_ingreso
         ORDER BY cod_vino
         FOR UPDATE
    LOOP
        IF v_item.cantidad <= 0 THEN
            RAISE EXCEPTION
                'La cantidad del vino % debe ser positiva',
                v_item.cod_vino;
        END IF;

        INSERT INTO Stock_Deposito (id_deposito, cod_vino, cantidad)
        VALUES (p_id_deposito, v_item.cod_vino, v_item.cantidad)
        ON CONFLICT (id_deposito, cod_vino)
        DO UPDATE
           SET cantidad = Stock_Deposito.cantidad + EXCLUDED.cantidad;
    END LOOP;

    UPDATE Ingreso
       SET estado = 'procesado'
     WHERE cod_ingreso = p_cod_ingreso;
END;
$$;

-- RN-11
-- Proposito: transferir al stock de una sala el contenido terminado.
-- Parametros: p_nro_solicitud identifica la transferencia y p_id_deposito el deposito.
-- Uso: CALL sp_procesar_transferencia(1, 1);
CREATE OR REPLACE PROCEDURE sp_procesar_transferencia(
    p_nro_solicitud INT,
    p_id_deposito INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_estado estado_documento;
    v_id_sala INT;
    v_item RECORD;
    v_stock INT;
BEGIN
    IF NOT EXISTS (
        SELECT 1
          FROM Deposito_Central
         WHERE id_deposito = p_id_deposito
    ) THEN
        RAISE EXCEPTION
            'El deposito % no existe',
            p_id_deposito;
    END IF;

    SELECT estado, id_sala
      INTO v_estado, v_id_sala
      FROM Transferencia
     WHERE nro_solicitud = p_nro_solicitud
     FOR UPDATE;

    IF NOT FOUND OR v_estado IS DISTINCT FROM 'terminado' THEN
        RAISE EXCEPTION
            'La transferencia % no existe o no esta terminada (RN-11)',
            p_nro_solicitud;
    END IF;

    IF NOT EXISTS (
        SELECT 1
          FROM Transferencia_Vino
         WHERE nro_solicitud = p_nro_solicitud
    ) THEN
        RAISE EXCEPTION
            'La transferencia % no tiene vinos',
            p_nro_solicitud;
    END IF;

    FOR v_item IN
        SELECT t.cod_vino, t.cantidad, v.nombre_comercial
          FROM Transferencia_Vino t
               LEFT JOIN Vino v ON v.cod_vino = t.cod_vino
         WHERE nro_solicitud = p_nro_solicitud
          ORDER BY t.cod_vino
          FOR UPDATE OF t
    LOOP
        IF v_item.cantidad <= 0 THEN
            RAISE EXCEPTION
                'La cantidad del vino % debe ser positiva',
                v_item.cod_vino;
        END IF;

        SELECT cantidad
          INTO v_stock
          FROM Stock_Deposito
         WHERE id_deposito = p_id_deposito
           AND cod_vino = v_item.cod_vino
         FOR UPDATE;

        IF NOT FOUND OR v_stock < v_item.cantidad THEN
            RAISE EXCEPTION
                'Stock insuficiente del vino % (codigo %) en el deposito % (RN-11)',
                v_item.nombre_comercial,
                v_item.cod_vino,
                p_id_deposito;
        END IF;
    END LOOP;

    FOR v_item IN
        SELECT cod_vino, cantidad
          FROM Transferencia_Vino
         WHERE nro_solicitud = p_nro_solicitud
         ORDER BY cod_vino
    LOOP
        UPDATE Stock_Deposito
           SET cantidad = cantidad - v_item.cantidad
         WHERE id_deposito = p_id_deposito
           AND cod_vino = v_item.cod_vino;

        INSERT INTO Sala_Venta_Vino (id_sala, cod_vino, cantidad)
        VALUES (v_id_sala, v_item.cod_vino, v_item.cantidad)
        ON CONFLICT (id_sala, cod_vino)
        DO UPDATE
           SET cantidad = Sala_Venta_Vino.cantidad + EXCLUDED.cantidad;
    END LOOP;

    UPDATE Transferencia
       SET estado = 'procesado'
     WHERE nro_solicitud = p_nro_solicitud;
END;
$$;
