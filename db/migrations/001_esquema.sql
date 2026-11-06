CREATE TABLE Vino(
    cod_vino SERIAL PRIMARY KEY,
    anada SMALLINT NOT NULL,
    tipo VARCHAR(12) NOT NULL,
    nombre_comercial VARCHAR(80) NOT NULL,
    precio NUMERIC(10,2) NOT NULL,
    graduacion NUMERIC(4,2) NOT NULL,
    volumen_ml INT NOT NULL,
    cuit_bodega cuit_dom NOT NULL  
)
CREATE TABLE Bodega(
    cuit_bodega cuit_dom PRIMARY KEY,
    razon_social VARCHAR(100) NOT NULL,
    calle VARCHAR(50) NOT NULL,
    numero INT NOT NULL,
)
CREATE TABLE Localidad(
    cod_postal INT PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL,
    provincia VARCHAR(50) NOT NULL
)
CREATE TABLE Encargado(
    id_encargado SERIAL PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL,
    apellido VARCHAR(50) NOT NULL,
    cod_postal INT NOT NULL
)
CREATE TABLE Sala_Venta(
    id_sala SERIAL PRIMARY KEY,
    calle VARCHAR(50) NOT NULL,
    numero INT NOT NULL,
    dia_cierre VARCHAR(20) NOT NULL,
    cod_postal INT NOT NULL
)
CREATE TABLE Sala_Venta_Vino(
    id_sala INT NOT NULL,
    cod_vino INT NOT NULL,
    cantidad INT NOT NULL,
    PRIMARY KEY(id_sala, cod_vino)
)
CREATE TABLE Empleado(
    cuit_empleado cuit_dom PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL,
    apellido VARCHAR(50) NOT NULL,
    salario NUMERIC(12,2) NOT NULL,
    fecha_ingreso DATE NOT NULL,
    id_sala INT NOT NULL
)
CREATE TABLE Finca(
    id_finca SERIAL PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL,
    superficie_ha NUMERIC(10,2) NOT NULL,
    departamento VARCHAR(50) NOT NULL,
    provincia VARCHAR(50) NOT NULL,
)
CREATE TABLE Cepa(
    id_cepa SERIAL PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL,
    tipo VARCHAR(10) NOT NULL,
)
CREATE TABLE Parcela(
    id_finca INT NOT NULL,
    nro_parcela INT NOT NULL,
    superficie NUMERIC(8,2) NOT NULL,
    anio_plantacion SMALLINT NOT NULL,
    id_cepa INT NOT NULL,
    PRIMARY KEY(id_finca, nro_parcela)
)
CREATE TABLE Lote(
    nro_lote SERIAL PRIMARY KEY,
    campania SMALLINT NOT NULL,
    fecha_cosecha DATE NOT NULL,
    kilos NUMERIC(10,2) NOT NULL,
    cuit_bodega cuit_dom NOT NULL,
    id_finca INT NOT NULL,
    nro_parcela INT NOT NULL,
)
CREATE TABLE Analisis_Calidad(
    id_analisis SERIAL PRIMARY KEY,
    fecha DATE NOT NULL,
    grado_brix NUMERIC(4,2) NOT NULL,
    ph NUMERIC(4,2) NOT NULL,
    acidez_total NUMERIC(5,2) NOT NULL,
    nro_lote INT NOT NULL
)
CREATE TABLE Composicion(
    cod_vino INT NOT NULL,
    id_cepa INT NOT NULL,
    porcentaje NUMERIC(5,2) NOT NULL,
)
CREATE TABLE Maridaje(
    id_maridaje SERIAL PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL,
    temperatura_servicio NUMERIC(4,2) NOT NULL,
)
CREATE TABLE Cliente(
    id_cliente SERIAL PRIMARY KEY,
    razon_social VARCHAR(100) NOT NULL,
    tipo_documento VARCHAR(10) NOT NULL,
    nro_documento VARCHAR(20) NOT NULL,
    fecha_alta DATE NOT NULL DEFAULT CURRENT_DATE,
    calle VARCHAR(50) NOT NULL,
    numero INT NOT NULL,
    cod_postal INT NOT NULL
)
CREATE TABLE Socio(
    id_cliente INT PRIMARY KEY,

)
CREATE TABLE Distribuidor(
    id_cliente INT PRIMARY KEY,
    zona_cobertura VARCHAR(50) NOT NULL,
    nro_habilitacion VARCHAR(20) NOT NULL
)
CREATE TABLE Permiso_exportacion(
    cod_permiso SERIAL PRIMARY KEY,
    fecha_emision DATE NOT NULL,
    fecha_vencimiento DATE NOT NULL
    id_cliente INT NOT NULL
)
CREATE TABLE Comprobante(
    nro_comprobante SERIAL PRIMARY KEY,
    fecha DATE NOT NULL,
    subtotal NUMERIC(12,2) NOT NULL,
    descuento NUMERIC(12,2) NOT NULL,
    total NUMERIC(12,2) NOT NULL,
    id_sala INT NOT NULL,
    id_cliente INT NOT NULL
)
CREATE TABLE Detalle_Comprobante(
    nro_comprobante INT NOT NULL,
    cod_vino INT NOT NULL,
    cantidad INT NOT NULL,
    cantidad INT NOT NULL,
    precio_unitario NUMERIC(10,2) NOT NULL,
    descuento_aplicado NUMERIC(5,2) NOT NULL,
    subtotal_renglon NUMERIC(12,2) NOT NULL,
    PRIMARY KEY(nro_comprobante, cod_vino)
)
CREATE TABLE Transportista(
    cod_transporte SERIAL PRIMARY KEY,
    razon_social VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL,
    cuit cuit_dom NOT NULL,
    calle VARCHAR(50) NOT NULL,
    numero INT NOT NULL,
)
CREATE TABLE Transportista_Telefono(
    cod_transporte INT NOT NULL,
    telefono VARCHAR(20) NOT NULL,
    PRIMARY KEY(cod_transporte, telefono)
)
CREATE TABLE Transportista_Localidad(
    cod_transporte INT NOT NULL,
    cod_postal INT NOT NULL,
    PRIMARY KEY(cod_transporte, cod_postal)
)
CREATE TABLE Ingreso(
    cod_ingreso SERIAL PRIMARY KEY,
    estado estado_documento NOT NULL,
    fecha_ingreso DATE DEFAULT CURRENT_DATE,
    cuit_bodega cuit_dom NOT NULL,
    cod_transporte INT NOT NULL
)
CREATE TABLE Ingreso_Vino(
    cod_ingreso INT NOT NULL,
    cod_vino INT NOT NULL,
    cantidad INT NOT NULL,
    PRIMARY KEY(cod_ingreso, cod_vino)
)
CREATE TABLE Deposito_Central(
    id_deposito SERIAL PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL
)
CREATE TABLE Stock_Deposito(
    id_deposito INT NOT NULL,
    cod_vino INT NOT NULL,
    cantidad INT NOT NULL,
    PRIMARY KEY(id_deposito, cod_vino)
)
CREATE TABLE Transferencia(
    nro_solicitud SERIAL PRIMARY KEY,
    estado estado_documento NOT NULL,
    fecha DATE DEFAULT CURRENT_DATE,
    id_sala INT NOT NULL,
)
CREATE TABLE Transferencia_Vino(
    nro_solicitud INT NOT NULL,
    cod_vino INT NOT NULL,
    cantidad INT NOT NULL,
    PRIMARY KEY(nro_solicitud, cod_vino)
)
CREATE TABLE Auditoria(
    id_auditoria SERIAL PRIMARY KEY,
    usuario VARCHAR(50) NOT NULL,
    precio_anterior NUMERIC(10,2) NOT NULL,
    precio_nuevo NUMERIC(10,2) NOT NULL,
    fecha_hora TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
);
