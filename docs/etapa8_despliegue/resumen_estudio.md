# Etapa 8 — Resumen para estudiar

Que hice y por que, en orden. Sirve como guia para repasar el codigo
desplegado antes de la defensa.

## 1. Separar el .env local del de la nube

`neon env pull` sobrescribio `DATABASE_URL` (la que usa el Docker local) con
la URL de Neon. Quedo asi:

- `DATABASE_URL` -> contenedor local de Docker (compose).
- `NEON_DATABASE_URL` -> branch `production` de Neon (rol propietario,
  con `sslmode=require&channel_binding=require`).

Leccion: cada entorno tiene su DSN; el rol propietario NUNCA lo usa la API.

## 2. Reaprovisionar la base de Neon desde el repo

La nube tenia datos de origen desconocido (no reproducibles). Proceso:

1. `DROP SCHEMA public CASCADE` + `CREATE SCHEMA` con el rol propietario.
2. Migraciones `001` a `008` en orden, una corrida de psql por archivo
   (`ON_ERROR_STOP=1`), con `API_DB_*` y `REPORT_DB_*` del `.env` pasadas
   como env (las usa `007_roles.sql`).
3. `007_roles.sql` volvio **idempotente**: crea los roles solo si no existen
   (`SELECT NOT EXISTS ... \gset` + `\if`), para poder re-ejecutarlo.
4. Carga con `db/seed/generar.py` (semilla fija 20261108) a escala reducida
   por el plan Free de Neon (1 GB): 5.000 clientes, 30.000 comprobantes,
   120.000 renglones (supera el minimo de 10.000 filas en una tabla).
5. `db/seed/controles.sql` -> 0 inconsistencias.

## 3. Idempotencia del rol (007_roles.sql)

```sql
SELECT NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'api_user') AS crear_api \gset
\if :crear_api
    CREATE ROLE :"api_user" LOGIN PASSWORD :'api_pass';
\endif
```

Los GRANT van igual (idempotentes por naturaleza).

## 4. La API sirve tambien el front (un solo dominio)

En `api/main.py`:

- Todas las rutas se movieron a `api_router = APIRouter()`.
- Se monta dos veces: `app.include_router(api_router)` y
  `app.include_router(api_router, prefix="/api")`. El front llama a `/api/...`
  (default de `front/src/api.js`) y las rutas raiz tambien existen.
- Si existe la carpeta `front_dist/` (front compilado, solo en la imagen de
  deploy), se monta `/assets` con `StaticFiles` y las rutas de la SPA
  (`/`, `/venta`, `/transferencias`, ...) devuelven `index.html` con
  `FileResponse`. Sin esa carpeta (local/compose) no cambia nada.
- Ventaja: una sola URL publica, HTTPS gratis, CORS innecesario.

## 5. Dockerfile.deploy + render.yaml

`Dockerfile.deploy` (multi-stage): compila el front con Node, copia
`front/dist` a `front_dist/` en la imagen de Python que corre uvicorn.
Render exige escuchar en `$PORT`, por eso:

```dockerfile
CMD ["sh", "-c", "uvicorn main:app --host 0.0.0.0 --port \"${PORT:-8000}\""]
```

`render.yaml` (Blueprint): tipo web, docker, `healthCheckPath: /salud`;
solo hay una variable `sync: false` (`API_DATABASE_URL`, DSN pooled de Neon
con el rol `bodegas_api`, se carga desde el dashboard).

## 6. Verificaciones hechas (todo con evidencia en evidencia/)

| Prueba | Resultado |
|---|---|
| `/salud` en la nube | `{"status":"ok","user":"bodegas_api"}` |
| Backup (`pg_dump -Fc`) | 201 KB, en `backups/` (igtr ignoreado) |
| Restore a base nueva PG18 | `pg_restore --no-owner --no-acl` -> conteos COINCIDEN en 32 tablas |
| Trigger RN-09 en la nube | `ERROR: Stock insuficiente ... (RN-09)` + `ROLLBACK`, cero filas a medias |
| Venta sin stock por la API | HTTP 409, `sqlstate P0001`, mensaje de la regla |

Detalles a tener en cuenta para explicar:

- El dump custom se restaura con `pg_restore` de una version **igual o mas
  nueva** que la del servidor (el formato 1.16 de PG18 no lo lee PG16).
- En la base de prueba el restore va con `--no-acl`: los `GRANT` a los roles
  se recrean ejecutando `007_roles.sql` (no dependen de paquetes del dump).
- Postgres no indexa automaticamente las claves foraneas -> la `008` crea
  `idx_ventas_trimestre` con `INCLUDE (id_sala, total)` (Index Only Scan
  posible para la venta por sala del ultimo trimestre).

## 7. Que falta para cerrar el hito

Importar el Blueprint en Render con la cuenta del grupo, cargar la variable,
y terminar la lista del README con la URL publica + capturas de la demo.
