-- Triggers. Cada uno indica la regla de negocio que protege.


-- RN-08: el comprobante nace con importes en 0
CREATE FUNCTION fn_trg_comprobante_inicial()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.subtotal  := 0;
    NEW.descuento := 0;
    NEW.total     := 0;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_comprobante_inicial
BEFORE INSERT ON Comprobante
FOR EACH ROW
EXECUTE FUNCTION fn_trg_comprobante_inicial();


-- RN-06, RN-08, RN-09: valida stock (bloquea la fila con FOR UPDATE) y completa precio, descuento y subtotal
CREATE OR REPLACE FUNCTION fn_trg_detalle_validar()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_sala    INT;
    v_id_cliente INT;
    v_precio     NUMERIC(10,2);
    v_stock      INT;
    v_nombre     TEXT;
BEGIN
    SELECT id_sala, id_cliente
      INTO v_id_sala, v_id_cliente
      FROM Comprobante
     WHERE nro_comprobante = NEW.nro_comprobante;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El comprobante % no existe', NEW.nro_comprobante
            USING ERRCODE = 'foreign_key_violation';
    END IF;

    SELECT precio, nombre_comercial
      INTO v_precio, v_nombre
      FROM Vino
     WHERE cod_vino = NEW.cod_vino;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El vino % no existe', NEW.cod_vino
            USING ERRCODE = 'foreign_key_violation';
    END IF;

    SELECT cantidad
      INTO v_stock
      FROM Sala_Venta_Vino
     WHERE id_sala = v_id_sala
       AND cod_vino = NEW.cod_vino
       FOR UPDATE;

    v_stock := COALESCE(v_stock, 0);

    IF v_stock < NEW.cantidad THEN
        RAISE EXCEPTION 'Stock insuficiente del vino % (codigo %) en la sala %: hay %, se piden % (RN-09)',
            v_nombre, NEW.cod_vino, v_id_sala, v_stock, NEW.cantidad
            USING ERRCODE = 'raise_exception';
    END IF;

    NEW.precio_unitario    := v_precio;
    NEW.descuento_aplicado := fn_descuento_cliente(v_id_cliente);
    NEW.subtotal_renglon   := ROUND(NEW.cantidad * NEW.precio_unitario
                                    * (1 - NEW.descuento_aplicado / 100), 2);
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_detalle_validar
BEFORE INSERT ON Detalle_Comprobante
FOR EACH ROW
EXECUTE FUNCTION fn_trg_detalle_validar();


-- RN-08, RN-09: descuenta stock y recalcula los importes del comprobante
CREATE FUNCTION fn_trg_detalle_aplicar()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_sala  INT;
    v_subtotal NUMERIC(12,2);
    v_total    NUMERIC(12,2);
BEGIN
    SELECT id_sala
      INTO v_id_sala
      FROM Comprobante
     WHERE nro_comprobante = NEW.nro_comprobante;

    UPDATE Sala_Venta_Vino
       SET cantidad = cantidad - NEW.cantidad
     WHERE id_sala = v_id_sala
       AND cod_vino = NEW.cod_vino;

    SELECT COALESCE(SUM(ROUND(cantidad * precio_unitario, 2)), 0)
      INTO v_subtotal
      FROM Detalle_Comprobante
     WHERE nro_comprobante = NEW.nro_comprobante;

    v_total := fn_total_comprobante(NEW.nro_comprobante);

    UPDATE Comprobante
       SET subtotal  = v_subtotal,
           descuento = v_subtotal - v_total,
           total     = v_total
     WHERE nro_comprobante = NEW.nro_comprobante;

    RETURN NULL;
END;
$$;

CREATE TRIGGER trg_detalle_aplicar
AFTER INSERT ON Detalle_Comprobante
FOR EACH ROW
EXECUTE FUNCTION fn_trg_detalle_aplicar();


-- RN-10, RN-11: nace en confeccion y solo avanza en_confeccion -> terminado -> procesado
CREATE FUNCTION fn_trg_control_estado()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        NEW.estado := COALESCE(NEW.estado, 'en_confeccion');

        IF NEW.estado <> 'en_confeccion' THEN
            RAISE EXCEPTION 'Un documento de % se crea en confección, no en % (RN-10, RN-11)',
                TG_TABLE_NAME, NEW.estado
                USING ERRCODE = 'raise_exception';
        END IF;

    ELSIF NEW.estado IS DISTINCT FROM OLD.estado
          AND NOT (OLD.estado = 'en_confeccion' AND NEW.estado = 'terminado')
          AND NOT (OLD.estado = 'terminado'     AND NEW.estado = 'procesado') THEN
        RAISE EXCEPTION 'Transición de estado no permitida en %: % → % (RN-10, RN-11)',
            TG_TABLE_NAME, OLD.estado, NEW.estado
            USING ERRCODE = 'raise_exception';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_ingreso_estado
BEFORE INSERT OR UPDATE OF estado ON Ingreso
FOR EACH ROW
EXECUTE FUNCTION fn_trg_control_estado();

CREATE TRIGGER trg_transferencia_estado
BEFORE INSERT OR UPDATE OF estado ON Transferencia
FOR EACH ROW
EXECUTE FUNCTION fn_trg_control_estado();


-- RN-12: los renglones solo se modifican si el documento esta en confeccion (FOR SHARE evita que cambie de estado)
CREATE FUNCTION fn_trg_bloqueo_renglones()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_docs   INT[] := '{}';
    v_doc    INT;
    v_estado estado_documento;
BEGIN
    IF TG_TABLE_NAME = 'ingreso_vino' THEN
        IF TG_OP <> 'INSERT' THEN v_docs := v_docs || OLD.cod_ingreso; END IF;
        IF TG_OP <> 'DELETE' THEN v_docs := v_docs || NEW.cod_ingreso; END IF;
    ELSE
        IF TG_OP <> 'INSERT' THEN v_docs := v_docs || OLD.nro_solicitud; END IF;
        IF TG_OP <> 'DELETE' THEN v_docs := v_docs || NEW.nro_solicitud; END IF;
    END IF;

    FOREACH v_doc IN ARRAY v_docs LOOP
        IF TG_TABLE_NAME = 'ingreso_vino' THEN
            SELECT estado INTO v_estado
              FROM Ingreso
             WHERE cod_ingreso = v_doc
               FOR SHARE;
        ELSE
            SELECT estado INTO v_estado
              FROM Transferencia
             WHERE nro_solicitud = v_doc
               FOR SHARE;
        END IF;

        IF FOUND AND v_estado <> 'en_confeccion' THEN
            RAISE EXCEPTION '% % está en estado %: no admite cambios en sus renglones (RN-12)',
                CASE TG_TABLE_NAME WHEN 'ingreso_vino' THEN 'El ingreso' ELSE 'La transferencia' END,
                v_doc, v_estado
                USING ERRCODE = 'raise_exception';
        END IF;
    END LOOP;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_ingreso_vino_bloqueo
BEFORE INSERT OR UPDATE OR DELETE ON Ingreso_Vino
FOR EACH ROW
EXECUTE FUNCTION fn_trg_bloqueo_renglones();

CREATE TRIGGER trg_transferencia_vino_bloqueo
BEFORE INSERT OR UPDATE OR DELETE ON Transferencia_Vino
FOR EACH ROW
EXECUTE FUNCTION fn_trg_bloqueo_renglones();


-- RN-11: la fecha de la transferencia es la actual y no se modifica
CREATE FUNCTION fn_trg_transferencia_fecha()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        NEW.fecha := CURRENT_DATE;
    ELSIF NEW.fecha IS DISTINCT FROM OLD.fecha THEN
        RAISE EXCEPTION 'La fecha de la transferencia % no se puede modificar (RN-11)', OLD.nro_solicitud
            USING ERRCODE = 'raise_exception';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_transferencia_fecha
BEFORE INSERT OR UPDATE OF fecha ON Transferencia
FOR EACH ROW
EXECUTE FUNCTION fn_trg_transferencia_fecha();


-- RN-13: audita cada cambio de precio. SECURITY DEFINER: la API no necesita permiso sobre Auditoria
-- session_user registra al usuario conectado
CREATE FUNCTION fn_trg_auditar_precio()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    INSERT INTO Auditoria (cod_vino, usuario, precio_anterior, precio_nuevo, fecha_hora)
    VALUES (NEW.cod_vino, session_user, OLD.precio, NEW.precio, CURRENT_TIMESTAMP);

    RETURN NULL;
END;
$$;

CREATE TRIGGER trg_vino_auditar_precio
AFTER UPDATE OF precio ON Vino
FOR EACH ROW
WHEN (OLD.precio IS DISTINCT FROM NEW.precio)
EXECUTE FUNCTION fn_trg_auditar_precio();


-- RN-05: al cerrar la transaccion, los porcentajes de corte de cada vino suman 100 (diferido)
CREATE FUNCTION fn_trg_composicion_100()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_vinos INT[] := '{}';
    v_vino  INT;
    v_suma  NUMERIC;
BEGIN
    IF TG_OP <> 'INSERT' THEN v_vinos := v_vinos || OLD.cod_vino; END IF;
    IF TG_OP <> 'DELETE' THEN v_vinos := v_vinos || NEW.cod_vino; END IF;

    FOREACH v_vino IN ARRAY v_vinos LOOP
        SELECT SUM(porcentaje)
          INTO v_suma
          FROM Composicion
         WHERE cod_vino = v_vino;

        -- Sin filas no hay nada que controlar
        IF v_suma IS NOT NULL AND v_suma <> 100 THEN
            RAISE EXCEPTION 'Los porcentajes de corte del vino % suman % y tienen que sumar 100 (RN-05)',
                v_vino, v_suma
                USING ERRCODE = 'raise_exception';
        END IF;
    END LOOP;

    RETURN NULL;
END;
$$;

CREATE CONSTRAINT TRIGGER trg_composicion_100
AFTER INSERT OR UPDATE OR DELETE ON Composicion
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION fn_trg_composicion_100();
