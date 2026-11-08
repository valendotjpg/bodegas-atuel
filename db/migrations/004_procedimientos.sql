/*
Procesos transaccionales de la base de datos.
*/

CREATE OR REPLACE PROCEDURE sp_procesar_ingreso(
    cod_vino INT,
    cod_ingreso INT,
    cantidad INT
)
LANGUAGE plpgsql
AS $$
BEGIN 
    -- Verificar que el vino exista
    IF NOT EXISTS (SELECT 1 FROM Vino WHERE cod_vino = cod_vino) THEN
        RAISE EXCEPTION 'El vino con código % no existe', cod_vino;
    END IF;

    -- Verificar que el ingreso exista
    IF NOT EXISTS (SELECT 1 FROM Ingreso_Vino WHERE cod_ingreso = cod_ingreso) THEN
        RAISE EXCEPTION 'El ingreso con código % no existe', cod_ingreso;
    END IF;

    -- Actualizar el stock en Stock_Deposito
    UPDATE Stock_Deposito
    SET cantidad = cantidad + cantidad
    WHERE cod_vino = cod_vino;

    -- Insertar en Auditoria
    INSERT INTO Auditoria (cod_vino, cod_ingreso, cantidad, fecha)
    VALUES (cod_vino, cod_ingreso, cantidad, NOW());
END;
$$;

CREATE OR REPLACE PROCEDURE sp_procesar_transferencia(
    cod_vino INT,
    cod_transferencia INT,
    cantidad INT
)
LANGUAGE plpgsql
AS $$
BEGIN 
    -- Verificar que el vino exista
    IF NOT EXISTS (SELECT 1 FROM Vino WHERE cod_vino = cod_vino) THEN
        RAISE EXCEPTION 'El vino con código % no existe', cod_vino;
    END IF;

    -- Verificar que la transferencia exista
    IF NOT EXISTS (SELECT 1 FROM Transferencia_Vino WHERE cod_transferencia = cod_transferencia) THEN
        RAISE EXCEPTION 'La transferencia con código % no existe', cod_transferencia;
    END IF;

    -- Actualizar el stock en Stock_Deposito y Sala_Venta_Vino
    UPDATE Stock_Deposito
    SET cantidad = cantidad - cantidad
    WHERE cod_vino = cod_vino;

    UPDATE Sala_Venta_Vino
    SET cantidad = cantidad + cantidad
    WHERE cod_vino = cod_vino;

    -- Insertar en Auditoria
    INSERT INTO Auditoria (cod_vino, cod_transferencia, cantidad, fecha)
    VALUES (cod_vino, cod_transferencia, cantidad, NOW());
END;
$$;
