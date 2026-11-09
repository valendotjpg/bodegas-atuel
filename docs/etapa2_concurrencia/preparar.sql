-- Demo de concurrencia: deja un vino con una sola botella en una sala y un comprobante
-- abierto para cada sesion (A y B). Se puede correr varias veces: vuelve a dejar el stock en 1.
-- Se corre con el rol propietario:
--   docker compose exec -T db sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"' < docs/etapa2_concurrencia/preparar.sql

\set ON_ERROR_STOP on

BEGIN;

INSERT INTO Localidad (cod_postal, nombre, provincia)
VALUES (5600, 'San Rafael', 'Mendoza')
ON CONFLICT DO NOTHING;

INSERT INTO Bodega (cuit_bodega, razon_social, calle, numero)
VALUES ('30777777777', 'Bodega Demo', 'Calle Demo', 1)
ON CONFLICT DO NOTHING;

INSERT INTO Vino (anada, tipo, nombre_comercial, precio, graduacion, volumen_ml, cuit_bodega)
VALUES (2020, 'Tinto', 'Demo Ultima Botella', 50000, 14, 750, '30777777777')
ON CONFLICT ON CONSTRAINT unique_nombre DO NOTHING;

INSERT INTO Sala_Venta (calle, numero, dia_cierre, cod_postal)
SELECT 'Sala Demo', 1, 'Lunes', 5600
WHERE NOT EXISTS (SELECT 1 FROM Sala_Venta WHERE calle = 'Sala Demo');

INSERT INTO Cliente (razon_social, tipo_documento, nro_documento, calle, numero, cod_postal)
VALUES ('Cliente Demo A', 'DNI', '99999991', 'Calle Demo', 1, 5600),
       ('Cliente Demo B', 'DNI', '99999992', 'Calle Demo', 2, 5600)
ON CONFLICT ON CONSTRAINT unique_documento DO NOTHING;

INSERT INTO Socio (id_cliente)
SELECT id_cliente FROM Cliente WHERE razon_social IN ('Cliente Demo A', 'Cliente Demo B')
ON CONFLICT DO NOTHING;

-- Una sola botella del vino en la sala
INSERT INTO Sala_Venta_Vino (id_sala, cod_vino, cantidad)
SELECT s.id_sala, v.cod_vino, 1
  FROM Sala_Venta s, Vino v
 WHERE s.calle = 'Sala Demo'
   AND v.nombre_comercial = 'Demo Ultima Botella'
ON CONFLICT (id_sala, cod_vino) DO UPDATE SET cantidad = 1;

-- Un comprobante nuevo para cada cliente
INSERT INTO Comprobante (fecha, id_sala, id_cliente)
SELECT CURRENT_DATE, s.id_sala, c.id_cliente
  FROM Sala_Venta s, Cliente c
 WHERE s.calle = 'Sala Demo'
   AND c.razon_social IN ('Cliente Demo A', 'Cliente Demo B');

COMMIT;

SELECT s.id_sala, v.cod_vino, svv.cantidad AS stock
  FROM Sala_Venta s
  JOIN Sala_Venta_Vino svv ON svv.id_sala = s.id_sala
  JOIN Vino v ON v.cod_vino = svv.cod_vino
 WHERE s.calle = 'Sala Demo'
   AND v.nombre_comercial = 'Demo Ultima Botella';
