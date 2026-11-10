\timing on
DROP TABLE IF EXISTS cmp_sin, cmp_con, det_sin, det_con;

-- comprobante (150.000 filas)
CREATE TABLE cmp_sin (LIKE comprobante INCLUDING DEFAULTS);
ALTER TABLE cmp_sin ADD PRIMARY KEY (nro_comprobante);
CREATE TABLE cmp_con (LIKE comprobante INCLUDING DEFAULTS);
ALTER TABLE cmp_con ADD PRIMARY KEY (nro_comprobante);
CREATE INDEX ON cmp_con (fecha) INCLUDE (id_sala, total);
CREATE INDEX ON cmp_con (id_sala, fecha) INCLUDE (id_cliente);
INSERT INTO cmp_sin SELECT * FROM comprobante;
INSERT INTO cmp_con SELECT * FROM comprobante;

-- detalle_comprobante (600.000 filas)
CREATE TABLE det_sin (LIKE detalle_comprobante INCLUDING DEFAULTS);
ALTER TABLE det_sin ADD PRIMARY KEY (nro_comprobante, cod_vino);
CREATE TABLE det_con (LIKE detalle_comprobante INCLUDING DEFAULTS);
ALTER TABLE det_con ADD PRIMARY KEY (nro_comprobante, cod_vino);
CREATE INDEX ON det_con (cod_vino) INCLUDE (nro_comprobante);
INSERT INTO det_sin SELECT * FROM detalle_comprobante;
INSERT INTO det_con SELECT * FROM detalle_comprobante;

-- tamaño de los índices reales
SELECT indexname, pg_size_pretty(pg_relation_size(indexname::regclass)) AS tamanio
  FROM pg_indexes
 WHERE indexname IN ('idx_ventas_trimestre','idx_comprobante_sala_fecha','idx_detalle_vino');

DROP TABLE cmp_sin, cmp_con, det_sin, det_con;