  
Diccionario de datos

**Convenciones usadas en las tablas**

**Tipos propios:** estado\_documento es un ENUM con los valores en\_confeccion, terminado y procesado. cuit\_dom es un DOMAIN basado en CHAR(11) que admite solo 11 dígitos. Los importes usan NUMERIC (nunca FLOAT).

**Claves**: se usan claves naturales para el CUIT (bodega, empleado) y el código postal (localidad), porque son identificadores estables y únicos del dominio. El resto de las tablas usa claves subrogadas autoincrementales (IDENTITY o SERIAL, según la tabla).

**Acciones referenciales**: ON DELETE RESTRICT en las entidades de negocio y en los movimientos (RN-14). ON DELETE CASCADE solo en tablas dependientes que no existen sin su tabla principal (renglones, teléfonos, composición, vino-maridaje, permisos, análisis, parcelas y subtipos de cliente). ON DELETE CASCADE también en Vino\_maridaje → Maridaje, Transportista\_Localidad → Localidad y Stock\_Deposito → Deposito\_Central, por ser tablas de asociación. ON UPDATE CASCADE en las claves foráneas de Vino → Bodega y hacia Localidad (encargado, sala y cliente). Las claves subrogadas no se modifican.

**Atributos derivados**: subtotal, descuento y total del comprobante y subtotal\_renglon del detalle se almacenan, pero los calcula la base (RN-08). La antigüedad del empleado no se almacena: se calcula con fn\_antiguedad\_anios.

**Columna Nulo**: No equivale a NOT NULL. Las claves primarias nunca admiten nulos.

Tabla: Localidad

*Localidades donde la empresa tiene salas de venta y donde viven los clientes. Identificadas por código postal.*

| Campo | Tipo | Clave | Nulo | Referencia | Descripción | Restricciones |
| :---- | :---- | :---- | :---- | :---- | :---- | :---- |
| cod\_postal | INT | PK | No |  | Código postal de la localidad  |  |
| nombre | VARCHAR(50) |  | No |  | Nombre de la localidad |  |
| provincia | VARCHAR(50) |  | No |  | Provincia a la que pertenece |  |

Tabla: Encargado

*Encargado regional (responsable comercial). Hay uno solo por localidad y está afectado a todas las salas de esa localidad (RN-02).*

| Campo | Tipo | Clave | Nulo | Referencia | Descripción | Restricciones |
| :---- | :---- | :---- | :---- | :---- | :---- | :---- |
| id\_encargado | INT | PK | No |  | ID único del encargado | Autoincremental (IDENTITY) |
| nombre | VARCHAR(50) |  | No |  | Nombre del encargado |  |
| apellido | VARCHAR(50) |  | No |  | Apellido del encargado |  |
| cod\_postal | INT | FK | No | Localidad.cod\_postalON DELETE RESTRICTON UPDATE CASCADE | Localidad de la que es responsable | UNIQUE (un solo encargado por localidad, RN-02) |

Tabla: Sala\_Venta

*Salas de venta de la red. Cada sala está en una sola localidad; una localidad puede tener varias salas.*

| Campo | Tipo | Clave | Nulo | Referencia | Descripción | Restricciones |
| :---- | :---- | :---- | :---- | :---- | :---- | :---- |
| id\_sala | INT | PK | No |  | ID único de la sala de venta | Autoincremental (IDENTITY) |
| calle | VARCHAR(50) |  | No |  | Domicilio de la sala: calle |  |
| numero | INT |  | No |  | Domicilio de la sala: numeración | CHECK (numero \> 0\) |
| dia\_cierre | VARCHAR(20) |  | No |  | Día de cierre semanal de la sala | CHECK (dia\_cierre IN ('lunes','martes','miercoles','jueves','viernes','sabado','domingo')) |
| cod\_postal | INT | FK | No | Localidad.cod\_postalON DELETE RESTRICTON UPDATE CASCADE | Localidad donde está la sala (RN-02) |  |

Tabla: Empleado

*Empleados de la empresa. Cada empleado trabaja en una sola sala (RN-03). La antigüedad no se almacena: se calcula con fn\_antiguedad\_anios.*

| Campo | Tipo | Clave | Nulo | Referencia | Descripción | Restricciones |
| :---- | :---- | :---- | :---- | :---- | :---- | :---- |
| cuit\_empleado | cuit\_dom | PK | No |  | CUIT del empleado  | Dominio cuit\_dom (11 dígitos) |
| nombre | VARCHAR(50) |  | No |  | Nombre del empleado |  |
| apellido | VARCHAR(50) |  | No |  | Apellido del empleado |  |
| salario | NUMERIC(12,2) |  | No |  | Salario del empleado | CHECK (salario \> 0\) (RN-15) |
| fecha\_ingreso | DATE |  | No |  | Fecha de ingreso laboral |  |
| id\_sala | INT | FK | No | Sala\_Venta.id\_salaON DELETE RESTRICT | Sala donde trabaja (RN-03) |  |

Tabla: Finca

*Fincas donde la empresa cultiva uva. Se divide en parcelas.*

| Campo | Tipo | Clave | Nulo | Referencia | Descripción | Restricciones |
| :---- | :---- | :---- | :---- | :---- | :---- | :---- |
| id\_finca | INT | PK | No |  | ID único de la finca | Autoincremental (IDENTITY) |
| nombre | VARCHAR(50) |  | No |  | Nombre de la finca |  |
| superficie\_ha | NUMERIC(10,2) |  | No |  | Superficie total en hectáreas | CHECK (superficie\_ha \> 0\) (RN-15) |
| departamento | VARCHAR(50) |  | No |  | Departamento donde se ubica |  |
| provincia | VARCHAR(50) |  | No |  | Provincia donde se ubica |  |

Tabla: Cepa

*Catálogo de cepas (variedades de uva).*

| Campo | Tipo | Clave | Nulo | Referencia | Descripción | Restricciones |
| :---- | :---- | :---- | :---- | :---- | :---- | :---- |
| id\_cepa | INT | PK | No |  | ID único de la cepa | Autoincremental (IDENTITY) |
| nombre | VARCHAR(50) |  | No |  | Nombre de la cepa (ej. Malbec) | UNIQUE |
| tipo | VARCHAR(10) |  | No |  | Tipo de cepa: tinta o blanca | CHECK (tipo IN ('tinta','blanca')) |

Tabla: Parcela

*Subdivisión de una finca. Entidad débil: se identifica por (id\_finca, nro\_parcela) y no existe sin su finca. Tiene una sola cepa plantada (RN-04).*

| Campo | Tipo | Clave | Nulo | Referencia | Descripción | Restricciones |
| :---- | :---- | :---- | :---- | :---- | :---- | :---- |
| id\_finca | INT | PK, FK | No | Finca.id\_fincaON DELETE CASCADE | Finca a la que pertenece la parcela |  |
| nro\_parcela | INT | PK | No |  | Número de parcela dentro de la finca |  |
| superficie | NUMERIC(8,2) |  | No |  | Superficie de la parcela en hectáreas | CHECK (superficie \> 0\) (RN-15) |
| anio\_plantacion | SMALLINT |  | No |  | Año de plantación | CHECK (anio\_plantacion BETWEEN 1900 AND 2100\) |
| id\_cepa | INT | FK | No | Cepa.id\_cepaON DELETE RESTRICT | Cepa plantada (una sola, RN-04) |  |

Tabla: Bodega

*Bodegas del grupo donde se elabora el vino.*

| Campo | Tipo | Clave | Nulo | Referencia | Descripción | Restricciones |
| :---- | :---- | :---- | :---- | :---- | :---- | :---- |
| cuit\_bodega | cuit\_dom | PK | No |  | CUIT de la bodega (clave natural) | Dominio cuit\_dom (11 dígitos) |
| razon\_social | VARCHAR(100) |  | No |  | Nombre legal de la bodega |  |
| calle | VARCHAR(50) |  | No |  | Domicilio de la bodega: calle |  |
| numero | INT |  | No |  | Domicilio de la bodega: numeración | CHECK (numero \> 0\) |

Tabla: Lote

*Lote de uva generado al cosechar una parcela en una campaña. Una parcela se cosecha a lo sumo una vez por campaña (RN-04).*

| Campo | Tipo | Clave | Nulo | Referencia | Descripción | Restricciones |
| :---- | :---- | :---- | :---- | :---- | :---- | :---- |
| nro\_lote | INT | PK | No |  | Número único del lote | Autoincremental (IDENTITY) |
| campania | SMALLINT |  | No |  | Campaña (año de cosecha) | UNIQUE (id\_finca, nro\_parcela, campania) (RN-04)CHECK (campania \= EXTRACT(YEAR FROM fecha\_cosecha)) |
| fecha\_cosecha | DATE |  | No |  | Fecha de cosecha |  |
| kilos | NUMERIC(10,2) |  | No |  | Kilos cosechados | CHECK (kilos \> 0\) (RN-15) |
| cuit\_bodega | cuit\_dom | FK | No | Bodega.cuit\_bodegaON DELETE RESTRICT | Bodega a la que fue entregado el lote |  |
| id\_finca | INT | FK | No | Parcela(id\_finca, nro\_parcela)ON DELETE RESTRICT | Finca de la parcela cosechada (FK compuesta, una sola con nro\_parcela) | Parte del UNIQUE |
| nro\_parcela | INT | FK | No | (parte de la FK compuesta a Parcela) | Parcela cosechada | Parte del UNIQUE |

Tabla: Analisis\_Calidad

*Análisis de calidad practicados a un lote de uva (uno o más por lote).*

| Campo | Tipo | Clave | Nulo | Referencia | Descripción | Restricciones |
| :---- | :---- | :---- | :---- | :---- | :---- | :---- |
| id\_analisis | INT | PK | No |  | ID único del análisis | Autoincremental (IDENTITY) |
| fecha | DATE |  | No |  | Fecha del análisis |  |
| grado\_brix | NUMERIC(4,2) |  | No |  | Grado Brix (azúcares) de la uva | CHECK (grado\_brix \> 0\) |
| ph | NUMERIC(4,2) |  | No |  | pH del mosto | CHECK (ph BETWEEN 0 AND 14\) |
| acidez\_total | NUMERIC(5,2) |  | No |  | Acidez total (g/L) | CHECK (acidez\_total \> 0\) |
| nro\_lote | INT | FK | No | Lote.nro\_loteON DELETE CASCADE | Lote analizado |  |

Tabla: Vino

*Vinos elaborados por las bodegas del grupo. El precio es único para toda la red de salas (RN-01).*

| Campo | Tipo | Clave | Nulo | Referencia | Descripción | Restricciones |
| :---- | :---- | :---- | :---- | :---- | :---- | :---- |
| cod\_vino | INT | PK | No |  | Código único del vino | Autoincremental (IDENTITY) |
| anada | SMALLINT |  | No |  | Año de cosecha (añada) | CHECK (anada BETWEEN 1990 AND 2100\)UNIQUE (nombre\_comercial, anada, volumen\_ml) |
| tipo | VARCHAR(12) |  | No |  | Tinto, blanco, rosado o espumante | CHECK (tipo IN ('tinto','blanco','rosado','espumante')) |
| nombre\_comercial | VARCHAR(80) |  | No |  | Nombre comercial de venta | Parte del UNIQUE (nombre\_comercial, anada, volumen\_ml) |
| precio | NUMERIC(10,2) |  | No |  | Precio de venta, igual para todas las salas | CHECK (precio \> 0\) (RN-01, RN-15)Cada cambio se audita (RN-13) |
| graduacion | NUMERIC(4,2) |  | No |  | Graduación alcohólica (°) | CHECK (graduacion BETWEEN 5 AND 20\) (RN-15) |
| volumen\_ml | INT |  | No |  | Presentación en mililitros | CHECK (volumen\_ml IN (187,375,750,1500,3000))Parte del UNIQUE |
| cuit\_bodega | cuit\_dom | FK | No | Bodega.cuit\_bodegaON DELETE RESTRICTON UPDATE CASCADE | Bodega que elabora el vino (RN-14) |  |

Tabla: Composición

*Cepas que componen cada vino y su porcentaje de corte (relación N:M con atributo).*

| Campo | Tipo | Clave | Nulo | Referencia | Descripción | Restricciones |
| :---- | :---- | :---- | :---- | :---- | :---- | :---- |
| cod\_vino | INT | PK, FK | No | Vino.cod\_vinoON DELETE CASCADE | Vino |  |
| id\_cepa | INT | PK, FK | No | Cepa.id\_cepaON DELETE RESTRICT | Cepa utilizada |  |
| porcentaje | NUMERIC(5,2) |  | No |  | Porcentaje de la cepa en el corte | CHECK (porcentaje \> 0 AND porcentaje \<= 100\)La suma por vino debe ser 100 (constraint trigger diferido, RN-05) |

Tabla: Maridaje

*Catálogo de maridajes recomendados.*

| Campo | Tipo | Clave | Nulo | Referencia | Descripción | Restricciones |
| :---- | :---- | :---- | :---- | :---- | :---- | :---- |
| id\_maridaje | INT | PK | No |  | ID único del maridaje | Autoincremental (IDENTITY) |
| nombre\_maridaje | VARCHAR(50) |  | No |  | Nombre del maridaje (ej. carnes rojas) | UNIQUE |
| temperatura\_servicio | NUMERIC(4,2) |  | No |  | Temperatura de servicio sugerida en °C | CHECK (temperatura\_servicio BETWEEN 0 AND 30\) |

Tabla: Vino\_maridaje

*Maridajes recomendados para cada vino.*

| Campo | Tipo | Clave | Nulo | Referencia | Descripción | Restricciones |
| :---- | :---- | :---- | :---- | :---- | :---- | :---- |
| cod\_vino | INT | PK, FK | No | Vino.cod\_vinoON DELETE CASCADE | Vino |  |
| id\_maridaje | INT | PK, FK | No | Maridaje.id\_maridajeON DELETE CASCADE | Maridaje recomendado |  |

Tabla: Cliente

*Supertipo de la jerarquía de clientes (socio, distribuidor, exportador).* 

| Campo | Tipo | Clave | Nulo | Referencia | Descripción | Restricciones |
| :---- | :---- | :---- | :---- | :---- | :---- | :---- |
| id\_cliente | INT | PK | No |  | ID único del cliente | Autoincremental (IDENTITY) |
| apellido | VARCHAR(50) |  | Sí |  | Apellido del cliente (persona) | CHECK (razon\_social IS NOT NULL OR (apellido IS NOT NULL AND nombre IS NOT NULL)) |
| nombre | VARCHAR(50) |  | Sí |  | Nombre del cliente (persona) | Mismo CHECK que apellido |
| razon\_social | VARCHAR(100) |  | Sí |  | Razón social del cliente (empresa) | Mismo CHECK: razón social, o apellido y nombre |
| tipo\_documento | VARCHAR(10) |  | No |  | Tipo de documento | CHECK (tipo\_documento IN ('DNI','CUIT','CUIL','PASAPORTE'))Parte del UNIQUE (tipo\_documento, nro\_documento) |
| nro\_documento | VARCHAR(20) |  | No |  | Número de documento | Parte del UNIQUE (tipo\_documento, nro\_documento) |
| fecha\_alta | DATE |  | No |  | Fecha de alta del cliente | DEFAULT CURRENT\_DATE |
| calle | VARCHAR(50) |  | No |  | Domicilio: calle |  |
| numero | INT |  | No |  | Domicilio: numeración | CHECK (numero \> 0\) |
| cod\_postal | INT | FK | No | Localidad.cod\_postalON DELETE RESTRICTON UPDATE CASCADE | Localidad del cliente |  |

Tabla: Socio

*Subtipo de Cliente: socio del club (consumidor final), 10 % de descuento (RN-06).*

| Campo | Tipo | Clave | Nulo | Referencia | Descripción | Restricciones |
| :---- | :---- | :---- | :---- | :---- | :---- | :---- |
| id\_cliente | INT | PK, FK | No | Cliente.id\_clienteON DELETE CASCADE | Cliente que es socio | Un cliente pertenece a un solo subtipo |
| porcentaje\_descuento | NUMERIC(5,2) |  | No |  | Porcentaje de descuento del socio (RN-06); lo lee fn\_descuento\_cliente | DEFAULT 10CHECK (porcentaje\_descuento BETWEEN 0 AND 100) |

Tabla: Distribuidor

*Subtipo de Cliente: distribuidor, 20 % de descuento (RN-06).*

| Campo | Tipo | Clave | Nulo | Referencia | Descripción | Restricciones |
| :---- | :---- | :---- | :---- | :---- | :---- | :---- |
| id\_cliente | INT | PK, FK | No | Cliente.id\_clienteON DELETE CASCADE | Cliente que es distribuidor | Un cliente pertenece a un solo subtipo |
| porcentaje\_descuento | NUMERIC(5,2) |  | No |  | Porcentaje de descuento del distribuidor (RN-06); lo lee fn\_descuento\_cliente | DEFAULT 20CHECK (porcentaje\_descuento BETWEEN 0 AND 100) |
| zona\_cobertura | VARCHAR(50) |  | No |  | Zona de cobertura del distribuidor |  |
| nro\_habilitacion | VARCHAR(20) |  | No |  | Número de habilitación | UNIQUE |

Tabla: Exportador

*Subtipo de Cliente: exportador, 30 % de descuento (RN-06). Puede tener varios permisos de exportación.*

| Campo | Tipo | Clave | Nulo | Referencia | Descripción | Restricciones |
| :---- | :---- | :---- | :---- | :---- | :---- | :---- |
| id\_cliente | INT | PK, FK | No | Cliente.id\_clienteON DELETE CASCADE | Cliente que es exportador | Un cliente pertenece a un solo subtipo |
| porcentaje\_descuento | NUMERIC(5,2) |  | No |  | Porcentaje de descuento del exportador (RN-06); lo lee fn\_descuento\_cliente | DEFAULT 30CHECK (porcentaje\_descuento BETWEEN 0 AND 100) |
| pais\_destino | VARCHAR(50) |  | No |  | País de destino principal |  |

Tabla: Permiso\_exportacion

*Permisos de exportación de un exportador (RN-07).*

| Campo | Tipo | Clave | Nulo | Referencia | Descripción | Restricciones |
| :---- | :---- | :---- | :---- | :---- | :---- | :---- |
| cod\_permiso | INT | PK | No |  | Código del permiso | Autoincremental (IDENTITY) |
| fecha\_emision | DATE |  | No |  | Fecha de emisión |  |
| fecha\_vencimiento | DATE |  | No |  | Fecha de vencimiento | CHECK (fecha\_vencimiento \> fecha\_emision) (RN-07) |
| id\_cliente | INT | FK | No | Exportador.id\_clienteON DELETE CASCADE | Exportador titular del permiso |  |

Tabla: Comprobante

*Cabecera de cada venta. Subtotal, descuento y total son derivados: se almacenan, pero los calcula la base (trigger y fn\_total\_comprobante).*

| Campo | Tipo | Clave | Nulo | Referencia | Descripción | Restricciones |
| :---- | :---- | :---- | :---- | :---- | :---- | :---- |
| nro\_comprobante | INT | PK | No |  | Número del comprobante | Autoincremental (IDENTITY) |
| fecha | DATE |  | No |  | Fecha de la venta | DEFAULT CURRENT\_DATE |
| subtotal | NUMERIC(12,2) |  | No |  | Suma de cantidad x precio unitario de los renglones, sin descuento (derivado) | DEFAULT 0CHECK (subtotal \>= 0\)Lo calcula el trigger (RN-08) |
| descuento | NUMERIC(12,2) |  | No |  | Importe descontado según el tipo de cliente (derivado) | DEFAULT 0CHECK (descuento \>= 0 AND descuento \<= subtotal)Lo calcula el trigger (RN-08) |
| total | NUMERIC(12,2) |  | No |  | Total a pagar: subtotal menos descuento (derivado) | DEFAULT 0CHECK (total \= subtotal \- descuento)Lo calcula el trigger (RN-08) |
| id\_sala | INT | FK | No | Sala\_Venta.id\_salaON DELETE RESTRICT | Sala donde se realizó la venta |  |
| id\_cliente | INT | FK | No | Cliente.id\_clienteON DELETE RESTRICT | Cliente que compró |  |

Tabla: Detalle\_Comprobante

*Renglones de un comprobante (relación N:M con atributos entre Comprobante y Vino).*

| Campo | Tipo | Clave | Nulo | Referencia | Descripción | Restricciones |
| :---- | :---- | :---- | :---- | :---- | :---- | :---- |
| cod\_vino | INT | PK, FK | No | Vino.cod\_vinoON DELETE RESTRICT | Vino vendido | Trigger BEFORE INSERT valida stock de la sala (RN-09) |
| nro\_comprobante | INT | PK, FK | No | Comprobante.nro\_comprobanteON DELETE CASCADE | Comprobante al que pertenece el renglón |  |
| cantidad | INT |  | No |  | Cantidad de botellas vendidas | CHECK (cantidad \> 0\) (RN-15) |
| precio\_unitario | NUMERIC(10,2) |  | No |  | Precio del vino al momento de la venta | CHECK (precio\_unitario \> 0\) (RN-15) |
| descuento\_aplicado | NUMERIC(5,2) |  | No |  | Porcentaje de descuento según el tipo de cliente (10, 20 o 30 %), obtenido con fn\_descuento\_cliente | CHECK (descuento\_aplicado BETWEEN 0 AND 100\) (RN-06) |
| subtotal\_renglon | NUMERIC(12,2) |  | No |  | Importe del renglón con descuento: cantidad x precio\_unitario x (1 \- descuento\_aplicado/100) (derivado) | CHECK (subtotal\_renglon \>= 0\)Lo calcula el trigger (RN-08) |

Tabla: Transportista

*Empresas de transporte que trasladan los ingresos al depósito central.*

| Campo | Tipo | Clave | Nulo | Referencia | Descripción | Restricciones |
| :---- | :---- | :---- | :---- | :---- | :---- | :---- |
| cod\_transporte | INT | PK | No |  | Código de la empresa de transporte | Autoincremental (IDENTITY) |
| razon\_social | VARCHAR(100) |  | No |  | Razón social de la empresa |  |
| email | VARCHAR(100) |  | No |  | Correo electrónico de contacto | CHECK (email LIKE '%\_@\_%.\_%') |
| cuit | cuit\_dom |  | No |  | CUIT de la empresa (clave candidata) | UNIQUEDominio cuit\_dom (11 dígitos) |
| calle | VARCHAR(50) |  | No |  | Domicilio: calle |  |
| numero | INT |  | No |  | Domicilio: numeración | CHECK (numero \> 0\) |

Tabla: Transportista\_telefono

*Teléfonos de cada transportista (atributo multivaluado, 1FN).*

| Campo | Tipo | Clave | Nulo | Referencia | Descripción | Restricciones |
| :---- | :---- | :---- | :---- | :---- | :---- | :---- |
| cod\_transporte | INT | PK, FK | No | Transportista.cod\_transporteON DELETE CASCADE | Transportista |  |
| telefono | VARCHAR(20) | PK | No |  | Número de teléfono |  |

Tabla: Transportista\_Localidad

*Localidades a las que llega el servicio de cada transportista (relación N:M).*

| Campo | Tipo | Clave | Nulo | Referencia | Descripción | Restricciones |
| :---- | :---- | :---- | :---- | :---- | :---- | :---- |
| cod\_transporte | INT | PK, FK | No | Transportista.cod\_transporteON DELETE CASCADE | Transportista |  |
| cod\_postal | INT | PK, FK | No | Localidad.cod\_postalON DELETE CASCADE | Localidad cubierta por el servicio |  |

Tabla: Ingreso

*Ingreso de vino al depósito central. Estados: en\_confeccion → terminado → procesado, sin retrocesos (RN-10). Solo uno terminado impacta en el stock.*

| Campo | Tipo | Clave | Nulo | Referencia | Descripción | Restricciones |
| :---- | :---- | :---- | :---- | :---- | :---- | :---- |
| cod\_ingreso | INT | PK | No |  | Código único de ingreso | Autoincremental (IDENTITY) |
| estado | estado\_documento |  | No |  | Estado del ingreso: en\_confeccion, terminado o procesado | DEFAULT 'en\_confeccion'Transiciones controladas por trigger (RN-10) |
| fecha\_ingreso | DATE |  | No |  | Fecha del ingreso | DEFAULT CURRENT\_DATE |
| cuit\_bodega | cuit\_dom | FK | No | Bodega.cuit\_bodegaON DELETE RESTRICT | Bodega de origen (RN-14) |  |
| cod\_transporte | INT | FK | No | Transportista.cod\_transporteON DELETE RESTRICT | Transportista que efectuó el traslado (RN-14) |  |

Tabla: Ingreso\_vino

*Renglones de un ingreso: vinos y cantidad de botellas. Solo se modifican si el ingreso está en confección (RN-12).*

| Campo | Tipo | Clave | Nulo | Referencia | Descripción | Restricciones |
| :---- | :---- | :---- | :---- | :---- | :---- | :---- |
| cod\_vino | INT | PK, FK | No | Vino.cod\_vinoON DELETE RESTRICT | Vino ingresado |  |
| cod\_ingreso | INT | PK, FK | No | Ingreso.cod\_ingresoON DELETE CASCADE | Ingreso al que pertenece el renglón |  |
| cantidad | INT |  | No |  | Cantidad de botellas | CHECK (cantidad \> 0\) (RN-15) |

Tabla: Deposito\_Central

*Depósito central que recibe la producción embotellada y la redistribuye a las salas. Existe un único depósito.*

| Campo | Tipo | Clave | Nulo | Referencia | Descripción | Restricciones |
| :---- | :---- | :---- | :---- | :---- | :---- | :---- |
| id\_deposito | INT | PK | No |  | ID único del depósito | Autoincremental (IDENTITY) |
| nombre | VARCHAR(50) |  | No |  | Nombre del depósito |  |

Tabla: Stock\_Deposito

*Stock de cada vino en el depósito central.*

| Campo | Tipo | Clave | Nulo | Referencia | Descripción | Restricciones |
| :---- | :---- | :---- | :---- | :---- | :---- | :---- |
| cod\_vino | INT | PK, FK | No | Vino.cod\_vinoON DELETE RESTRICT | Vino |  |
| id\_deposito | INT | PK, FK | No | Deposito\_central.id\_depositoON DELETE CASCADE | Depósito |  |
| cantidad | INT |  | No |  | Botellas disponibles en el depósito | DEFAULT 0CHECK (cantidad \>= 0\) (RN-15) |

Tabla: Sala\_Venta\_Vino

*Stock de cada vino en cada sala de venta.*

| Campo | Tipo | Clave | Nulo | Referencia | Descripción | Restricciones |
| :---- | :---- | :---- | :---- | :---- | :---- | :---- |
| cod\_vino | INT | PK, FK | No | Vino.cod\_vinoON DELETE RESTRICT | Vino |  |
| id\_sala | INT | PK, FK | No | Sala\_Venta.id\_salaON DELETE RESTRICT | Sala de venta |  |
| cantidad | INT |  | No |  | Botellas disponibles en la sala | DEFAULT 0CHECK (cantidad \>= 0\) (RN-09) |

Tabla: Transferencia

*Pedido de vinos de una sala al depósito central. Estados: en\_confeccion → terminado → procesado (RN-11).*

| Campo | Tipo | Clave | Nulo | Referencia | Descripción | Restricciones |
| :---- | :---- | :---- | :---- | :---- | :---- | :---- |
| nro\_solicitud | INT | PK | No |  | Número de solicitud | Autoincremental (IDENTITY) |
| estado | estado\_documento |  | No |  | Estado de la transferencia: en\_confeccion, terminado o procesado | DEFAULT 'en\_confeccion'Transiciones controladas por trigger (RN-11) |
| fecha | DATE |  | No |  | Fecha de confección | DEFAULT CURRENT\_DATETrigger fuerza la fecha actual y prohíbe modificarla (RN-11) |
| id\_sala | INT | FK | No | Sala\_Venta.id\_salaON DELETE RESTRICT | Sala solicitante |  |

Tabla: Transferencia\_Vino

*Renglones de una transferencia: vinos y cantidad. Solo se modifican si está en confección (RN-12).*

| Campo | Tipo | Clave | Nulo | Referencia | Descripción | Restricciones |
| :---- | :---- | :---- | :---- | :---- | :---- | :---- |
| nro\_solicitud | INT | PK, FK | No | Transferencia.nro\_solicitudON DELETE CASCADE | Transferencia a la que pertenece el renglón |  |
| cod\_vino | INT | PK, FK | No | Vino.cod\_vinoON DELETE RESTRICT | Vino solicitado |  |
| cantidad | INT |  | No |  | Cantidad de botellas solicitadas | CHECK (cantidad \> 0\) (RN-15) |

Tabla: Auditoria

*Registro de cada cambio de precio de un vino. La completa un trigger AFTER UPDATE (RN-13).*

| Campo | Tipo | Clave | Nulo | Referencia | Descripción | Restricciones |
| :---- | :---- | :---- | :---- | :---- | :---- | :---- |
| id\_auditoria | INT | PK | No |  | ID único del registro | Autoincremental (IDENTITY) |
| usuario | VARCHAR(50) |  | No |  | Usuario de la base que hizo el cambio | DEFAULT current\_user |
| precio\_anterior | NUMERIC(10,2) |  | No |  | Precio antes del cambio | CHECK (precio\_anterior \> 0\) |
| precio\_nuevo | NUMERIC(10,2) |  | No |  | Precio después del cambio | CHECK (precio\_nuevo \> 0\) |
| fecha\_hora | TIMESTAMP |  | No |  | Fecha y hora del cambio | DEFAULT now() |
| cod\_vino | INT | FK | No | Vino.cod\_vinoON DELETE RESTRICT | Vino cuyo precio cambió |  |

