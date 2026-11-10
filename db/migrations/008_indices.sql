-- Etapa 4: indices. Cada uno cita la consulta que lo motiva y la evidencia
-- (planes EXPLAIN (ANALYZE, BUFFERS) antes/despues en docs/etapa4_rendimiento/).
-- Los indices que se evaluaron y no aportaron estan en
-- docs/etapa4_rendimiento/indices_descartados.sql y NO se crean aca.

-- S8. Monto total de ventas por sala en el ultimo trimestre.
-- Un solo rango sobre fecha; id_sala y total van en INCLUDE para resolverla
-- con Index Only Scan (7,77 ms -> 1,22 ms; 1.246 -> 28 buffers).
CREATE INDEX IF NOT EXISTS idx_ventas_trimestre
    ON comprobante (fecha) INCLUDE (id_sala, total);

-- S3. Clientes por tipo en una sala en la ultima semana.
-- Compuesto: la sala es una igualdad y la fecha un rango, por eso id_sala va
-- primero. Con INCLUDE (id_cliente) no toca la tabla (6,99 ms -> 0,48 ms).
CREATE INDEX IF NOT EXISTS idx_comprobante_sala_fecha
    ON comprobante (id_sala, fecha) INCLUDE (id_cliente);

-- S12. Clientes que compraron todos los vinos de una bodega / nunca compraron
-- tinto. Sobre clave foranea: PostgreSQL no indexa cod_vino en
-- detalle_comprobante y la PK empieza por nro_comprobante, asi que no sirve
-- para buscar por vino (27,8 ms -> 6,3 ms en la parte (a)).
CREATE INDEX IF NOT EXISTS idx_detalle_vino
    ON detalle_comprobante (cod_vino) INCLUDE (nro_comprobante);

-- S4. Top 5 de salas que solicitaron un vino por transferencia.
-- Misma razon que el anterior sobre transferencia_vino (PK = nro_solicitud,
-- cod_vino): Seq Scan -> Index Only Scan.
CREATE INDEX IF NOT EXISTS idx_transferencia_vino
    ON transferencia_vino (cod_vino) INCLUDE (nro_solicitud, cantidad);

-- S5 y v_documentos_pendientes. Indice PARCIAL: solo las transferencias que
-- todavia no se procesaron (el predicado es constante, no usa CURRENT_DATE).
-- Es ~30 % mas chico que un indice completo sobre id_sala. Con la carga por
-- defecto el planificador sigue prefiriendo Seq Scan (la tabla tiene 5.000
-- filas, 32 paginas): el indice paga cuando la tabla crece y lo pendiente es
-- una fraccion menor.
CREATE INDEX IF NOT EXISTS idx_transferencia_pendientes
    ON transferencia (id_sala) WHERE estado <> 'procesado';
