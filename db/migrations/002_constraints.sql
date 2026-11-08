/*
Restricciones de integridad
*/

ALTER TABLE Vino
ADD CONSTRAINT check_anada CHECK (anada BETWEEN 1990 AND 2100);

ALTER TABLE Vino
ADD CONSTRAINT check_precio CHECK (precio >= 0);

ALTER TABLE Vino
ADD CONSTRAINT check_graduacion CHECK (graduacion BETWEEN 5 AND 20);

ALTER TABLE Vino
ADD CONSTRAINT check_volumen_ml CHECK (volumen_ml IN (187, 375, 750, 1000, 1500));

ALTER TABLE Vino
ADD CONSTRAINT unique_nombre UNIQUE (nombre_comercial, anada, volumen_ml);

ALTER TABLE Vino
ADD CONSTRAINT check_tipo CHECK (tipo IN ('Tinto', 'Blanco', 'Rosado', 'Espumante'));

ALTER TABLE Encargado
ADD CONSTRAINT unique_localidad UNIQUE (cod_postal);

ALTER TABLE Sala_Venta
ADD CONSTRAINT check_numeracion CHECK (numero > 0);

ALTER TABLE Sala_Venta
ADD CONSTRAINT check_dia_cierre CHECK (dia_cierre IN ('Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'));

ALTER TABLE Empleado
ADD CONSTRAINT check_salario CHECK (salario > 0);

ALTER TABLE Finca
ADD CONSTRAINT check_superficie_ha CHECK (superficie_ha > 0);

ALTER TABLE Cepa
ADD CONSTRAINT unique_nombre_cepa UNIQUE (nombre);

ALTER TABLE Cepa
ADD CONSTRAINT check_tipo_cepa CHECK (tipo IN ('Blanca', 'Tinta'));

ALTER TABLE Parcela
ADD CONSTRAINT check_superficie_parcela CHECK (superficie > 0);

ALTER TABLE Parcela
ADD CONSTRAINT check_anio_plantacion CHECK (anio_plantacion BETWEEN 1900 AND 2100);

ALTER TABLE Bodega
ADD CONSTRAINT check_numero_bodega CHECK (numero > 0);

ALTER TABLE Lote
ADD CONSTRAINT check_campania CHECK (campania = EXTRACT(YEAR FROM fecha_cosecha));

ALTER TABLE Lote
ADD CONSTRAINT unique_lote UNIQUE (id_finca, nro_parcela, campania);

ALTER TABLE Analisis_Calidad
ADD CONSTRAINT check_grado_brix CHECK (grado_brix > 0);

ALTER TABLE Analisis_Calidad
ADD CONSTRAINT check_ph CHECK (ph BETWEEN 0 AND 14);

ALTER TABLE Analisis_Calidad
ADD CONSTRAINT check_acidez_total CHECK (acidez_total > 0);

ALTER TABLE Composicion
ADD CONSTRAINT check_porcentaje CHECK (porcentaje > 0 AND porcentaje <= 100);

ALTER TABLE Maridaje
ADD CONSTRAINT unique_nombre_maridaje UNIQUE (nombre_maridaje);

ALTER TABLE Maridaje
ADD CONSTRAINT check_temperatura_servicio CHECK (temperatura_servicio BETWEEN 0 AND 30);

ALTER TABLE Cliente
ADD CONSTRAINT check_tipo_documento CHECK (tipo_documento IN ('DNI', 'Pasaporte', 'CUIT', 'CUIL'));

ALTER TABLE Cliente
ADD CONSTRAINT unique_documento UNIQUE (tipo_documento, nro_documento);

ALTER TABLE Cliente
ADD CONSTRAINT check_numeracion CHECK (numero > 0);

ALTER TABLE Distribuidor
ADD CONSTRAINT unique_nro_habilitacion UNIQUE (nro_habilitacion);

ALTER TABLE Permiso_Exportacion
ADD CONSTRAINT check_fecha_emision CHECK (fecha_emision < fecha_vencimiento);

ALTER TABLE Comprobante
ADD CONSTRAINT check_subtotal CHECK (subtotal >= 0);

ALTER TABLE Comprobante
ADD CONSTRAINT check_descuento CHECK (descuento >= 0 AND descuento <= subtotal);

ALTER TABLE Comprobante
ADD CONSTRAINT check_total CHECK (total = subtotal - descuento);

ALTER TABLE Detalle_Comprobante
ADD CONSTRAINT check_cantidad CHECK (cantidad > 0);

ALTER TABLE Detalle_Comprobante
ADD CONSTRAINT check_precio_unitario CHECK (precio_unitario >= 0);

ALTER TABLE Detalle_Comprobante
ADD CONSTRAINT descuento_aplicado CHECK (descuento_aplicado BETWEEN 0 AND 100);

ALTER TABLE Detalle_Comprobante
ADD CONSTRAINT check_subtotal_renglon CHECK (subtotal_renglon >= 0);

ALTER TABLE Transportista
ADD CONSTRAINT check_email CHECK (email LIKE '%_@__%.__%');

ALTER TABLE Transportista
ADD CONSTRAINT unique_cuit UNIQUE (cuit);

ALTER TABLE Transportista 
ADD CONSTRAINT check_numeracion CHECK (numero > 0);

ALTER TABLE Ingreso_Vino
ADD CONSTRAINT check_cantidad_ingreso CHECK (cantidad > 0);

ALTER TABLE Stock_Deposito
ADD CONSTRAINT check_cantidad_stock CHECK (cantidad >= 0);

ALTER TABLE Sala_Venta_Vino
ADD CONSTRAINT check_cantidad_sala CHECK (cantidad >= 0);

ALTER TABLE Transferencia_Vino
ADD CONSTRAINT check_cantidad_transferencia CHECK (cantidad > 0);

ALTER TABLE Auditoria
ADD CONSTRAINT check_precio_anterior CHECK (precio_anterior > 0);

ALTER TABLE Auditoria
ADD CONSTRAINT check_precio_nuevo CHECK (precio_nuevo > 0);




