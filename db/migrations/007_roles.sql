/*
   Roles y privilegios.
   Las claves se leen del entorno con \getenv.
*/

\getenv api_user API_DB_USER
\getenv api_pass API_DB_PASSWORD
\getenv report_user REPORT_DB_USER
\getenv report_pass REPORT_DB_PASSWORD

\if :{?api_user}
\else
    DO $$ BEGIN RAISE EXCEPTION 'Falta API_DB_USER en el .env'; END $$;
\endif

\if :{?api_pass}
\else
    DO $$ BEGIN RAISE EXCEPTION 'Falta API_DB_PASSWORD en el .env'; END $$;
\endif

\if :{?report_user}
\else
    DO $$ BEGIN RAISE EXCEPTION 'Falta REPORT_DB_USER en el .env'; END $$;
\endif

\if :{?report_pass}
\else
    DO $$ BEGIN RAISE EXCEPTION 'Falta REPORT_DB_PASSWORD en el .env'; END $$;
\endif

CREATE ROLE :"api_user" LOGIN PASSWORD :'api_pass';
CREATE ROLE :"report_user" LOGIN PASSWORD :'report_pass';

-- Rol de la API: lectura y escritura sin privilegios de propietario.
GRANT CONNECT ON DATABASE :"DBNAME" TO :"api_user";
GRANT USAGE ON SCHEMA public TO :"api_user";
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO :"api_user";
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO :"api_user";
GRANT EXECUTE ON FUNCTION
    fn_descuento_cliente(INT),
    fn_total_comprobante(INT),
    fn_stock_sala(INT, INT),
    fn_antiguedad_anios(DATE, DATE)
    TO :"api_user";
GRANT EXECUTE ON PROCEDURE
    sp_procesar_ingreso(INT, INT),
    sp_procesar_transferencia(INT, INT)
    TO :"api_user";
REVOKE ALL ON Auditoria FROM :"api_user";

-- Rol de reportes: solo lectura.
GRANT CONNECT ON DATABASE :"DBNAME" TO :"report_user";
GRANT USAGE ON SCHEMA public TO :"report_user";
GRANT SELECT ON ALL TABLES IN SCHEMA public TO :"report_user";

-- Privilegios por defecto para objetos creados despues.
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO :"api_user";
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT USAGE, SELECT ON SEQUENCES TO :"api_user";
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT ON TABLES TO :"report_user";

-- PUBLIC no accede al esquema ni a los objetos.
REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL ROUTINES IN SCHEMA public FROM PUBLIC;
