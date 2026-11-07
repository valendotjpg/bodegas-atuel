#!/usr/bin/env bash
# Crea el rol de minimos privilegios que usa la API.
# Es .sh (y no .sql) para leer la clave desde el .env en lugar de dejarla en el repo.
# Corre como POSTGRES_USER, despues de 001-006, asi que las tablas ya existen.
set -euo pipefail

: "${API_DB_USER:?Falta API_DB_USER en el .env}"
: "${API_DB_PASSWORD:?Falta API_DB_PASSWORD en el .env}"

psql -v ON_ERROR_STOP=1 \
     --username "$POSTGRES_USER" \
     --dbname "$POSTGRES_DB" \
     -v api_user="$API_DB_USER" \
     -v api_pass="$API_DB_PASSWORD" \
     -v db_name="$POSTGRES_DB" <<'EOSQL'
CREATE ROLE :"api_user" LOGIN PASSWORD :'api_pass';

GRANT CONNECT ON DATABASE :"db_name" TO :"api_user";
GRANT USAGE ON SCHEMA public TO :"api_user";

-- TODO etapa 2: GRANT SELECT/INSERT/UPDATE por tabla y EXECUTE sobre las
-- funciones que la API necesite. Nada de DELETE ni DDL si no hace falta.
EOSQL
