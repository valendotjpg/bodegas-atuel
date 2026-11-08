/*
   Roles y privilegios.
   El usuario y la clave del rol de la API se leen del entorno (.env) con
   \getenv, así la clave no queda en el repo. Corre con psql, igual que el
   resto de las migraciones.
*/

\getenv api_user API_DB_USER
\getenv api_pass API_DB_PASSWORD

\if :{?api_user}
\else
    DO $$ BEGIN RAISE EXCEPTION 'Falta API_DB_USER en el .env'; END $$;
\endif

\if :{?api_pass}
\else
    DO $$ BEGIN RAISE EXCEPTION 'Falta API_DB_PASSWORD en el .env'; END $$;
\endif

CREATE ROLE :"api_user" LOGIN PASSWORD :'api_pass';

GRANT CONNECT ON DATABASE :"DBNAME" TO :"api_user";
GRANT USAGE ON SCHEMA public TO :"api_user";

-- TODO #8: REVOKE de PUBLIC, rol de solo lectura y GRANT por tabla y función.
