/* 
   Tipos y dominios
*/
CREATE TYPE estado_documento AS ENUM ('en_confeccion', 'terminado', 'procesado');
CREATE DOMAIN cuit_dom AS CHAR(11)
    CHECK (VALUE ~ '^[0-9]{11}$');

/* 
   Tablas
*/

CREATE TABLE Bodega(
    cuit_bodega cuit_dom PRIMARY KEY,
    razon_social VARCHAR(100) NOT NULL,
    calle VARCHAR(50) NOT NULL,
    numero INT NOT NULL
);
CREATE TABLE Vino(
    cod_vino INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    anada SMALLINT NOT NULL,
    tipo VARCHAR(12) NOT NULL,
    nombre_comercial VARCHAR(80) NOT NULL,
    precio NUMERIC(10,2) NOT NULL,
    graduacion NUMERIC(4,2) NOT NULL,
    volumen_ml INT NOT NULL,
    cuit_bodega cuit_dom NOT NULL REFERENCES Bodega(cuit_bodega) ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE TABLE Localidad(
    cod_postal INT PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL,
    provincia VARCHAR(50) NOT NULL
);
CREATE TABLE Encargado(
    id_encargado INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL,
    apellido VARCHAR(50) NOT NULL,
    cod_postal INT NOT NULL
);
CREATE TABLE Sala_Venta(
    id_sala INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    calle VARCHAR(50) NOT NULL,
    numero INT NOT NULL,
    dia_cierre VARCHAR(20) NOT NULL,
    cod_postal INT NOT NULL
);
CREATE TABLE Sala_Venta_Vino(
    id_sala INT NOT NULL,
    cod_vino INT NOT NULL,
    cantidad INT NOT NULL,
    PRIMARY KEY(id_sala, cod_vino)
);
CREATE TABLE Empleado(
    cuit_empleado cuit_dom PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL,
    apellido VARCHAR(50) NOT NULL,
    salario NUMERIC(12,2) NOT NULL,
    fecha_ingreso DATE NOT NULL,
    id_sala INT NOT NULL
);
CREATE TABLE Finca(
    id_finca INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL,
    superficie_ha NUMERIC(10,2) NOT NULL,
    departamento VARCHAR(50) NOT NULL,
    provincia VARCHAR(50) NOT NULL
);
CREATE TABLE Cepa(
    id_cepa INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL,
    tipo VARCHAR(10) NOT NULL
);
CREATE TABLE Parcela(
    id_finca INT NOT NULL,
    nro_parcela INT NOT NULL,
    superficie NUMERIC(8,2) NOT NULL,
    anio_plantacion SMALLINT NOT NULL,
    id_cepa INT NOT NULL,
    PRIMARY KEY(id_finca, nro_parcela)
);
CREATE TABLE Lote(
    nro_lote INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    campania SMALLINT NOT NULL,
    fecha_cosecha DATE NOT NULL,
    kilos NUMERIC(10,2) NOT NULL,
    cuit_bodega cuit_dom NOT NULL,
    id_finca INT NOT NULL,
    nro_parcela INT NOT NULL
);
CREATE TABLE Analisis_Calidad(
    id_analisis INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    fecha DATE NOT NULL,
    grado_brix NUMERIC(4,2) NOT NULL,
    ph NUMERIC(4,2) NOT NULL,
    acidez_total NUMERIC(5,2) NOT NULL,
    nro_lote INT NOT NULL
);
CREATE TABLE Composicion(
    cod_vino INT NOT NULL,
    id_cepa INT NOT NULL,
    porcentaje NUMERIC(5,2) NOT NULL,
    PRIMARY KEY(cod_vino, id_cepa)
);
CREATE TABLE Maridaje(
    id_maridaje INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL,
    temperatura_servicio NUMERIC(4,2) NOT NULL
);
CREATE TABLE Vino_Maridaje(
    cod_vino INT NOT NULL,
    id_maridaje INT NOT NULL,
    PRIMARY KEY(cod_vino, id_maridaje)
);
CREATE TABLE Cliente(
    id_cliente SERIAL PRIMARY KEY,
    razon_social VARCHAR(100) NOT NULL,
    tipo_documento VARCHAR(10) NOT NULL,
    nro_documento VARCHAR(20) NOT NULL,
    fecha_alta DATE NOT NULL DEFAULT CURRENT_DATE,
    calle VARCHAR(50) NOT NULL,
    numero INT NOT NULL,
    cod_postal INT NOT NULL
);
CREATE TABLE Socio(
    id_cliente INT PRIMARY KEY
);
CREATE TABLE Distribuidor(
    id_cliente INT PRIMARY KEY,
    zona_cobertura VARCHAR(50) NOT NULL,
    nro_habilitacion VARCHAR(20) NOT NULL
);
CREATE TABLE Exportador(
    id_cliente INT PRIMARY KEY,
    pais_destino VARCHAR(50) NOT NULL
);
CREATE TABLE Permiso_exportacion(
    cod_permiso SERIAL PRIMARY KEY,
    fecha_emision DATE NOT NULL,
    fecha_vencimiento DATE NOT NULL,
    id_cliente INT NOT NULL
);
CREATE TABLE Comprobante(
    nro_comprobante SERIAL PRIMARY KEY,
    fecha DATE NOT NULL,
    subtotal NUMERIC(12,2) NOT NULL,
    descuento NUMERIC(12,2) NOT NULL,
    total NUMERIC(12,2) NOT NULL,
    id_sala INT NOT NULL,
    id_cliente INT NOT NULL
);
CREATE TABLE Detalle_Comprobante(
    nro_comprobante INT NOT NULL,
    cod_vino INT NOT NULL,
    cantidad INT NOT NULL,
    precio_unitario NUMERIC(10,2) NOT NULL,
    descuento_aplicado NUMERIC(5,2) NOT NULL,
    subtotal_renglon NUMERIC(12,2) NOT NULL,
    PRIMARY KEY(nro_comprobante, cod_vino)
);
CREATE TABLE Transportista(
    cod_transporte SERIAL PRIMARY KEY,
    razon_social VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL,
    cuit cuit_dom NOT NULL,
    calle VARCHAR(50) NOT NULL,
    numero INT NOT NULL
);
CREATE TABLE Transportista_Telefono(
    cod_transporte INT NOT NULL,
    telefono VARCHAR(20) NOT NULL,
    PRIMARY KEY(cod_transporte, telefono)
);
CREATE TABLE Transportista_Localidad(
    cod_transporte INT NOT NULL,
    cod_postal INT NOT NULL,
    PRIMARY KEY(cod_transporte, cod_postal)
);
CREATE TABLE Ingreso(
    cod_ingreso SERIAL PRIMARY KEY,
    estado estado_documento NOT NULL,
    fecha_ingreso DATE DEFAULT CURRENT_DATE,
    cuit_bodega cuit_dom NOT NULL,
    cod_transporte INT NOT NULL
);
CREATE TABLE Ingreso_Vino(
    cod_ingreso INT NOT NULL,
    cod_vino INT NOT NULL,
    cantidad INT NOT NULL,
    PRIMARY KEY(cod_ingreso, cod_vino)
);
CREATE TABLE Deposito_Central(
    id_deposito SERIAL PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL
);
CREATE TABLE Stock_Deposito(
    id_deposito INT NOT NULL,
    cod_vino INT NOT NULL,
    cantidad INT NOT NULL,
    PRIMARY KEY(id_deposito, cod_vino)
);
CREATE TABLE Transferencia(
    nro_solicitud SERIAL PRIMARY KEY,
    estado estado_documento NOT NULL,
    fecha DATE DEFAULT CURRENT_DATE,
    id_sala INT NOT NULL
);
CREATE TABLE Transferencia_Vino(
    nro_solicitud INT NOT NULL,
    cod_vino INT NOT NULL,
    cantidad INT NOT NULL,
    PRIMARY KEY(nro_solicitud, cod_vino)
);
CREATE TABLE Auditoria(
    id_auditoria SERIAL PRIMARY KEY,
    usuario VARCHAR(50) NOT NULL,
    precio_anterior NUMERIC(10,2) NOT NULL,
    precio_nuevo NUMERIC(10,2) NOT NULL,
    cod_vino INT NOT NULL,
    fecha_hora TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
/*
   Claves foráneas
*/
ALTER TABLE Vino ADD CONSTRAINT fk_vino_bodega 
FOREIGN KEY (cuit_bodega) REFERENCES Bodega(cuit_bodega) 
ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE Encargado ADD CONSTRAINT fk_encargado_localidad 
FOREIGN KEY (cod_postal) REFERENCES Localidad(cod_postal) 
ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE Sala_Venta ADD CONSTRAINT fk_sala_venta_localidad
FOREIGN KEY (cod_postal) REFERENCES Localidad(cod_postal)
ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE Empleado ADD CONSTRAINT fk_empleado_sala_venta
FOREIGN KEY (id_sala) REFERENCES Sala_Venta(id_sala)
ON DELETE RESTRICT;

ALTER TABLE Parcela ADD CONSTRAINT fk_parcela_finca
FOREIGN KEY (id_finca) REFERENCES Finca(id_finca)
ON DELETE CASCADE;

ALTER TABLE Parcela ADD CONSTRAINT fk_parcela_cepa
FOREIGN KEY (id_cepa) REFERENCES Cepa(id_cepa)
ON DELETE RESTRICT;

ALTER TABLE Lote ADD CONSTRAINT fk_lote_bodega
FOREIGN KEY (cuit_bodega) REFERENCES Bodega(cuit_bodega)
ON DELETE RESTRICT;

ALTER TABLE Lote ADD CONSTRAINT fk_lote_parcela
FOREIGN KEY (id_finca, nro_parcela) REFERENCES Parcela(id_finca,nro_parcela)
ON DELETE RESTRICT;

ALTER TABLE Analisis_Calidad ADD CONSTRAINT fk_analisis_calidad_lote
FOREIGN KEY (nro_lote) REFERENCES Lote(nro_lote)
ON DELETE CASCADE;

ALTER TABLE Vino_Maridaje ADD CONSTRAINT fk_vino_maridaje_vino
FOREIGN KEY (cod_vino) REFERENCES Vino(cod_vino)
ON DELETE CASCADE;

ALTER TABLE Vino_Maridaje ADD CONSTRAINT fk_vino_maridaje_maridaje
FOREIGN KEY (id_maridaje) REFERENCES Maridaje(id_maridaje)
ON DELETE CASCADE;

ALTER TABLE Comprobante ADD CONSTRAINT fk_comprobante_sala_venta
FOREIGN KEY (id_sala) REFERENCES Sala_Venta(id_sala)
ON DELETE RESTRICT;

ALTER TABLE Comprobante ADD CONSTRAINT fk_comprobante_cliente
FOREIGN KEY (id_cliente) REFERENCES Cliente(id_cliente)
ON DELETE RESTRICT;

ALTER TABLE Detalle_Comprobante ADD CONSTRAINT fk_detalle_comprobante_comprobante
FOREIGN KEY (nro_comprobante) REFERENCES Comprobante(nro_comprobante)
ON DELETE CASCADE;

ALTER TABLE Detalle_Comprobante ADD CONSTRAINT fk_detalle_comprobante_vino
FOREIGN KEY (cod_vino) REFERENCES Vino(cod_vino)
ON DELETE RESTRICT;

ALTER TABLE Cliente ADD CONSTRAINT fk_cliente_localidad
FOREIGN KEY (cod_postal) REFERENCES Localidad(cod_postal)
ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE Socio ADD CONSTRAINT fk_socio_cliente
FOREIGN KEY (id_cliente) REFERENCES Cliente(id_cliente)
ON DELETE CASCADE;

ALTER TABLE Distribuidor ADD CONSTRAINT fk_distribuidor_cliente
FOREIGN KEY (id_cliente) REFERENCES Cliente(id_cliente)
ON DELETE CASCADE;

ALTER TABLE Exportador ADD CONSTRAINT fk_exportador_cliente
FOREIGN KEY (id_cliente) REFERENCES Cliente(id_cliente)
ON DELETE CASCADE;

ALTER TABLE Permiso_exportacion ADD CONSTRAINT fk_permiso_exportacion_cliente
FOREIGN KEY (id_cliente) REFERENCES Cliente(id_cliente)
ON DELETE CASCADE;

ALTER TABLE Ingreso ADD CONSTRAINT fk_ingreso_bodega
FOREIGN KEY (cuit_bodega) REFERENCES Bodega(cuit_bodega)
ON DELETE RESTRICT;

ALTER TABLE Ingreso ADD CONSTRAINT fk_ingreso_transportista
FOREIGN KEY (cod_transporte) REFERENCES Transportista(cod_transporte)
ON DELETE RESTRICT;

ALTER TABLE Ingreso_Vino ADD CONSTRAINT fk_ingreso_vino_ingreso
FOREIGN KEY (cod_ingreso) REFERENCES Ingreso(cod_ingreso)
ON DELETE CASCADE;

ALTER TABLE Ingreso_Vino ADD CONSTRAINT fk_ingreso_vino_vino
FOREIGN KEY (cod_vino) REFERENCES Vino(cod_vino)
ON DELETE RESTRICT;

ALTER TABLE Transportista_Telefono ADD CONSTRAINT fk_telefono_transportista
FOREIGN KEY (cod_transporte) REFERENCES Transportista(cod_transporte)
ON DELETE CASCADE;

ALTER TABLE Transportista_Localidad ADD CONSTRAINT fk_localidad_transportista
FOREIGN KEY (cod_postal) REFERENCES Localidad(cod_postal)
ON DELETE CASCADE;

ALTER TABLE Transportista_Localidad ADD CONSTRAINT fk_transportista_localidad
FOREIGN KEY (cod_transporte) REFERENCES Transportista(cod_transporte)
ON DELETE CASCADE;

ALTER TABLE Stock_Deposito ADD CONSTRAINT fk_stock_deposito_deposito
FOREIGN KEY (id_deposito) REFERENCES Deposito_Central(id_deposito)
ON DELETE CASCADE;

ALTER TABLE Stock_Deposito ADD CONSTRAINT fk_stock_deposito_vino
FOREIGN KEY (cod_vino) REFERENCES Vino(cod_vino)
ON DELETE RESTRICT;

ALTER TABLE Transferencia ADD CONSTRAINT fk_transferencia_sala_venta
FOREIGN KEY (id_sala) REFERENCES Sala_Venta(id_sala)
ON DELETE RESTRICT;

ALTER TABLE Transferencia_Vino ADD CONSTRAINT fk_transferencia_vino_transferencia
FOREIGN KEY (nro_solicitud) REFERENCES Transferencia(nro_solicitud)
ON DELETE CASCADE;

ALTER TABLE Transferencia_Vino ADD CONSTRAINT fk_transferencia_vino_vino
FOREIGN KEY (cod_vino) REFERENCES Vino(cod_vino)
ON DELETE RESTRICT;

ALTER TABLE Sala_Venta_Vino ADD CONSTRAINT fk_sala_venta_vino_sala
FOREIGN KEY (id_sala) REFERENCES Sala_Venta(id_sala)
ON DELETE RESTRICT;

ALTER TABLE Sala_Venta_Vino ADD CONSTRAINT fk_sala_venta_vino_vino
FOREIGN KEY (cod_vino) REFERENCES Vino(cod_vino)
ON DELETE RESTRICT;

ALTER TABLE Auditoria ADD CONSTRAINT fk_auditoria_vino
FOREIGN KEY cod_vino REFERENCES Vino(cod_vino)
ON DELETE RESTRICT;


