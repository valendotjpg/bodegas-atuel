# Bodegas del Atuel

TPI de Base de Datos, UTN FRSR, Ingenieria en Sistemas, 3.er anio, ciclo 2026.
Sistema de gestion y distribucion de una empresa vitivinicola. Motor: PostgreSQL 16.
Acceso a datos con SQL directo (sin ORM). Las reglas de negocio (stock,
descuentos, totales, estados) viven en la base; la API y el front no calculan.

- Version en la nube: <https://bodegas-atuel.onrender.com>
- Informe final: [`docs/informe_final.md`](docs/informe_final.md)

## Requisitos

- Git
- Docker Desktop (con WSL2 en Windows)
- Un cliente SQL: `psql`, DBeaver o pgAdmin
- Python 3.10+ (generador de datos: `psycopg`, `Faker`)
- API: Python (FastAPI + psycopg); front: React (Vite)

## Levantar la base en local

Clonar el repo **fuera de OneDrive/Google Drive/Dropbox** (ej. `C:\dev\`):
la sincronizacion rompe `.git` y los volumenes de Docker.

```bash
cp .env.example .env      # completar las claves
docker compose up -d
docker compose logs -f db # ver que las migraciones corran sin errores
```

Con `docker compose up -d` quedan la API en <http://localhost:8000/docs> y el
front en <http://localhost:8080>.

Para cargar los datos de prueba (etapa 3) sobre la base recien creada:

```bash
docker compose run --rm seed
```

## Migraciones

Los archivos de `db/migrations/` corren solos y en orden (001 a 008) la primera
vez que se crea el volumen de la base. Para aplicarlos a mano sobre otra base
vacia, con el rol propietario y las variables de roles del `.env` cargadas:

```bash
for f in db/migrations/0*.sql; do psql "$DSN_PROPIETARIO" -v ON_ERROR_STOP=1 -f "$f"; done
```

## Pruebas

Reglas de negocio (15 casos) y privilegios de cada rol, con el rol propietario:

```bash
docker compose cp tests/db_tests.sql db:/tmp/db_tests.sql
docker compose exec db sh -c 'psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f /tmp/db_tests.sql'
docker compose cp tests/db_tests_roles.sql db:/tmp/db_tests_roles.sql
docker compose exec db sh -c 'psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f /tmp/db_tests_roles.sql'
```

Consultas de control de la carga y consultas de la seccion 8 (todas terminan en
`ROLLBACK`, no cambian la base):

```bash
docker compose cp db/seed/controles.sql db:/tmp/controles.sql
docker compose exec db sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f /tmp/controles.sql'
docker compose cp consultas/select.sql db:/tmp/select.sql
docker compose exec db sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f /tmp/select.sql'
```

API (con la base levantada y el puerto 5432 expuesto):

```bash
cd api
pip install -r requirements.txt
API_DATABASE_URL="postgresql://<API_DB_USER>:<API_DB_PASSWORD>@localhost:5432/bodegas" pytest -q
```

## Puerto ocupado

Si ya tenes un PostgreSQL instalado en la PC usando el puerto 5432, cambia
`POSTGRES_PORT` en el `.env` (ej. `5433`).

Para recrear la base desde cero (borra los datos). Es obligatorio despues de
que falle una migracion: la init corta en el primer error y, como el volumen ya
existe, no vuelve a correr sola.

```bash
docker compose down -v
docker compose up -d
```

## Estructura

| Carpeta | Contenido |
|---|---|
| `db/migrations/` | `001_esquema.sql` a `008_indices.sql`, en orden (`007_roles.sql` lee las claves de API y reportes del `.env`) |
| `db/seed/` | CSV de catalogos, script de carga masiva, controles e informe de carga |
| `tests/` | `db_tests.sql` (un caso por regla RN-01 a RN-15) y `db_tests_roles.sql` (privilegios de cada rol) |
| `consultas/` | `insert.sql`, `update.sql`, `delete.sql`, `select.sql` |
| `api/` | API REST FastAPI con psycopg |
| `front/` | Front en React + Vite (ver `front/README.md`) |
| `docs/` | Informe final, DER, diccionario de datos e informes por etapa |
| `docs/etapa1_documentacion/` | DER (integrado y por area), esquema relacional, diccionario de datos, normalizacion y decisiones |
| `docs/etapa2_*` | Trazabilidad de reglas y demostracion de concurrencia |
| `docs/etapa4_rendimiento/` | Indices: planes antes y despues, tabla comparativa, costo de escritura |
| `docs/etapa8_despliegue/` | Informe y evidencia del despliegue en Neon y Render |

## Hitos

| Hito | Etapa | Estado |
|---|---|---|
| H1 | Modelado | completado |
| H2 | Integridad y logica en la base | completado |
| H3 | Carga masiva | completado |
| H4 | Indices y rendimiento | completado (informe en `docs/etapa4_rendimiento/informe.md`) |
| H5 | Consultas SQL | completado |
| H6 | API | completado |
| H7 | Front | completado |
| H8 | Nube | completado (`https://bodegas-atuel.onrender.com`, informe en `docs/etapa8_despliegue/`) |
| H9 | Documentacion y defensa | en curso (`docs/informe_final.md`) |

## Flujo de trabajo

- Una rama por etapa (`etapa-1-modelado`, `etapa-2-integridad`, ...).
- Pull request con revision de otro integrante antes de integrar a `main` (no se pushea directo a `main`).
- Cada trigger lleva un comentario con la regla que protege (ej. `-- RN-09`).
- La API y el front no calculan totales, descuentos ni stock: llaman a la base.
- Nunca subir secretos. Usar `.env` (ignorado por git).

## Equipo

Grupo N°7:

- Mansalve Augusto
- Praderio Valentin
- Quiroga Constanza

## URL en la nube

- Base de datos: **Neon**, branch `production` (region `aws-sa-east-1`,
  conexion TLS `sslmode=require`). Roles de minimos privilegios creados con
  `007_roles.sql`.
- URL publica (API + front en Render): <https://bodegas-atuel.onrender.com>
  verificada en `docs/etapa8_despliegue/evidencia/07_url_publica.txt`.
  Con el plan Free hay cold start tras 15 min de inactividad.

## Despliegue en la nube (resumen)

```bash
neon status                          # ver proyecto/branch vinculados
# migraciones en orden con el rol propietario (psql 001..008, 007 lee el .env)
python db/seed/generar.py --dsn "$NEON_DATABASE_URL" --vinos 300 --lotes 1500 \
  --ingresos 1000 --transferencias 1000 --clientes 5000 --comprobantes 30000
docker run --rm -v ./backups:/out postgres:18 \
  pg_dump "$NEON_DATABASE_URL" -Fc -f /out/neon_backup_$(date +%Y%m%d_%H%M).dump
```

Detalle completo (decision de proveedor, seguridad, backup y restauracion
verificados, pasos de Render) en `docs/etapa8_despliegue/informe.md`.
