/*
   Pruebas de roles y privilegios (007_roles.sql).
   Se corre con el rol propietario; cambia de rol con SET ROLE y todo
   queda dentro de una transaccion que se revierte al final.

   docker compose exec -T db sh -c 'psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB"' < tests/db_tests_roles.sql

   Cada caso imprime NOTICE 'OK: ...'. Si un caso falla, corta con ERROR 'FALLO: ...'.
*/

\getenv api_user API_DB_USER
\getenv report_user REPORT_DB_USER

BEGIN;

-- Los nombres de rol se pasan a los bloques DO como parametros de sesion.
SET LOCAL pruebas.api_user = :'api_user';
SET LOCAL pruebas.report_user = :'report_user';


-- ===== Atributos de los roles =====

-- Ni la API ni reportes son superusuario, ni crean roles o bases.
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN
        SELECT rolname, rolsuper, rolcreaterole, rolcreatedb, rolbypassrls
        FROM pg_roles
        WHERE rolname IN (current_setting('pruebas.api_user'), current_setting('pruebas.report_user'))
    LOOP
        IF r.rolsuper OR r.rolcreaterole OR r.rolcreatedb OR r.rolbypassrls THEN
            RAISE EXCEPTION 'FALLO: % tiene atributos de administrador', r.rolname;
        END IF;
        RAISE NOTICE 'OK: % no tiene atributos de administrador', r.rolname;
    END LOOP;
END $$;

-- Ninguno de los dos es dueno de objetos del esquema.
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public'
          AND pg_get_userbyid(c.relowner) IN (current_setting('pruebas.api_user'), current_setting('pruebas.report_user'))
    ) THEN
        RAISE EXCEPTION 'FALLO: la API o reportes es duena de objetos del esquema';
    END IF;
    RAISE NOTICE 'OK: la API y reportes no son duenos de ningun objeto';
END $$;


-- ===== PUBLIC =====

DO $$
BEGIN
    IF has_database_privilege('public', current_database(), 'CONNECT') THEN
        RAISE EXCEPTION 'FALLO: PUBLIC puede conectarse a la base';
    END IF;
    IF has_database_privilege('public', current_database(), 'TEMP') THEN
        RAISE EXCEPTION 'FALLO: PUBLIC puede crear tablas temporales';
    END IF;
    IF has_schema_privilege('public', 'public', 'USAGE') THEN
        RAISE EXCEPTION 'FALLO: PUBLIC puede usar el esquema public';
    END IF;
    RAISE NOTICE 'OK: PUBLIC no se conecta ni usa el esquema';
END $$;


-- ===== Rol de la API: lo que debe poder hacer =====

-- Escritura y procedimientos: se verifica el privilegio (la base puede estar vacia).
DO $$
DECLARE
    v_api TEXT := current_setting('pruebas.api_user');
BEGIN
    IF NOT (has_table_privilege(v_api, 'vino', 'SELECT, INSERT, UPDATE, DELETE')
            AND has_table_privilege(v_api, 'comprobante', 'INSERT')
            AND has_table_privilege(v_api, 'detalle_comprobante', 'INSERT')) THEN
        RAISE EXCEPTION 'FALLO: la API no puede leer y escribir las tablas';
    END IF;
    IF NOT (has_function_privilege(v_api, 'sp_procesar_ingreso(int, int)', 'EXECUTE')
            AND has_function_privilege(v_api, 'sp_procesar_transferencia(int, int)', 'EXECUTE')) THEN
        RAISE EXCEPTION 'FALLO: la API no puede ejecutar los procedimientos';
    END IF;
    RAISE NOTICE 'OK: la API puede escribir tablas y ejecutar procedimientos';
END $$;

SELECT set_config('role', current_setting('pruebas.api_user'), true);

DO $$
BEGIN
    PERFORM count(*) FROM Vino;
    PERFORM fn_stock_sala(1, 1);
    RAISE NOTICE 'OK: la API lee tablas y ejecuta funciones';
END $$;


-- ===== Rol de la API: lo que NO debe poder hacer =====

DO $$
BEGIN
    PERFORM 1 FROM Auditoria LIMIT 1;
    RAISE EXCEPTION 'FALLO: la API pudo leer Auditoria';
EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'OK: la API no puede leer Auditoria';
END $$;

-- RN-13: la auditoria solo la escribe el trigger.
DO $$
BEGIN
    INSERT INTO Auditoria DEFAULT VALUES;
    RAISE EXCEPTION 'FALLO: la API pudo escribir en Auditoria';
EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'OK: la API no puede escribir en Auditoria';
END $$;

DO $$
BEGIN
    TRUNCATE Vino CASCADE;
    RAISE EXCEPTION 'FALLO: la API pudo vaciar Vino con TRUNCATE';
EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'OK: la API no puede hacer TRUNCATE';
END $$;

DO $$
BEGIN
    CREATE TABLE prueba_api (id INT);
    RAISE EXCEPTION 'FALLO: la API pudo crear una tabla';
EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'OK: la API no puede crear tablas';
END $$;

DO $$
BEGIN
    ALTER TABLE Vino DISABLE TRIGGER ALL;
    RAISE EXCEPTION 'FALLO: la API pudo deshabilitar los triggers de Vino';
EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'OK: la API no puede deshabilitar triggers';
END $$;

DO $$
BEGIN
    DROP TABLE Vino CASCADE;
    RAISE EXCEPTION 'FALLO: la API pudo borrar la tabla Vino';
EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'OK: la API no puede borrar tablas';
END $$;

RESET ROLE;


-- ===== Rol de reportes: lo que debe poder hacer =====

SELECT set_config('role', current_setting('pruebas.report_user'), true);

DO $$
BEGIN
    PERFORM count(*) FROM Vino;
    PERFORM count(*) FROM Comprobante;
    PERFORM count(*) FROM Auditoria;
    PERFORM fn_stock_sala(1, 1);
    RAISE NOTICE 'OK: reportes lee tablas y ejecuta funciones de lectura';
END $$;


-- ===== Rol de reportes: lo que NO debe poder hacer =====

DO $$
BEGIN
    DELETE FROM Vino;
    RAISE EXCEPTION 'FALLO: reportes pudo borrar filas';
EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'OK: reportes no puede borrar filas';
END $$;

DO $$
BEGIN
    UPDATE Vino SET precio = precio;
    RAISE EXCEPTION 'FALLO: reportes pudo modificar filas';
EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'OK: reportes no puede modificar filas';
END $$;

DO $$
BEGIN
    CALL sp_procesar_transferencia(1, 1);
    RAISE EXCEPTION 'FALLO: reportes pudo ejecutar un procedimiento';
EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'OK: reportes no puede ejecutar procedimientos';
END $$;

RESET ROLE;

ROLLBACK;
