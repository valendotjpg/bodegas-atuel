# Etapa 8 — Despliegue en la nube

Etapa 8 del TPI: el sistema funciona en un servidor que no es la computadora del
grupo, con las medidas básicas de seguridad y operación. La base de datos quedó
desplegada en **Neon** (branch `production`); el despliegue público de la API y el
front está en curso (ver «Pendiente» al final).

Evidencia: carpeta [`evidencia/`](evidencia). Los secretos se omiten de todos los
comandos con `<NEON_DATABASE_URL>`; las credenciales viven en el `.env`
(ignorado por git, verificado también en el historial).

## 1. Comparación de proveedores y elección

| Criterio | Neon (elegido) | Supabase Postgres | Render PostgreSQL |
|---|---|---|---|
| Motor / versiones | PostgreSQL serverless, versiones recientes (18 en este proyecto) | PostgreSQL administrado | PostgreSQL administrado, versión fija por tier |
| Plan gratuito | 0 $/mes: 1 GB de almacenamiento por proyecto, 100 CU-h/computo por proyecto por mes, 5 GB de egress, scale-to-zero (5 min) | 0 $/mes pero pausa tras 7 días de inactividad y ~500 MB de DB | La DB gratuita expira 30 días después de crearla |
| Conexión | TLS obligatorio (`sslmode=require`, `channel_binding=require` en el DSN) | TLS disponible | TLS disponible |
| Roles con privilegios mínimos | Roles SQL normales (`CREATE ROLE ... LOGIN`) | Igual | Igual |
| Backups / restauración | `pg_dump`/`pg_restore` + snapshot manual del plan (1 en Free) | `pg_dump`/`pg_restore` + backups automáticos en planes pagos | Plus en planes pagos |
| Extra útil para el TPI | Branches instantáneas y snapshots (útil para restaurar a un punto y para probar migraciones), CLI `neon` integrado en el repo | Ecosistema propio (Auth, Storage) no requerido por el TPI | Solo hosting genérico |
| Riesgo visto | Scale-to-zero: primer request tras inactividad suma un "cold start" | Pausa por inactividad similar | DB gratuita de 30 días obligaría a recrearla en la defensa |

Decisión: **Neon**. Motivos: plan gratuito compatible con el volumen del TPI,
PostgreSQL real (sin capas propietarias arriba del motor), TLS por defecto,
proyecto ya vinculado en el repo con el CLI `neon` (`.neon`, `neon.ts`), y las
branches/snapshots simplifican restaurar y probar migraciones.

Límites tenidos en cuenta del plan Free (documentación de Neon, nov. 2026):
1 GB de Postgres storage por proyecto, 20 GB de cuenta; 100 CU-hours de cómputo
por proyecto por mes (un compute de 0.25 CU puede correr ~400 h/mes); scale-to-zero
a los 5 minutos (no desactivable); historial de restore instantáneo de 6 h /
1 GB; 1 snapshot manual. La carga de la nube se cambió a escala reducida por esto.

## 2. Ambiente desplegado

- Organización: `org-blue-butterfly-71145070`
- Proyecto: `bodegas-atuel` (`young-boat-55271872`)
- Branch: `production` (`br-bitter-mountain-b6mondxm`, default)
- Región: `aws-sa-east-1` (São Paulo, la más cercana a Mendoza)
- PostgreSQL 18.x (`evidencia/01_ambiente.txt`)

## 3. Migraciones aplicadas en orden

Con el rol propietario (`neondb_owner`) se aplicaron los archivos de
`db/migrations/` en orden (dentro de un contenedor con el cliente `psql`,
montando el directorio de migraciones como volumen de solo lectura):

```bash
docker run --rm \
  -e API_DB_USER=... -e API_DB_PASSWORD=... \
  -e REPORT_DB_USER=... -e REPORT_DB_PASSWORD=... \
  -v ./db/migrations:/mig:ro \
  postgres:18 \
  psql "<NEON_DATABASE_URL>" -v ON_ERROR_STOP=1 -f /mig/001_esquema.sql
# ... repetir con 002..007 exportando las mismas variables ...
# (007 las necesita para crear los roles de la API y de reportes)
docker run --rm -v ./db/migrations:/mig:ro postgres:18 \
  psql "<NEON_DATABASE_URL>" -v ON_ERROR_STOP=1 -f /mig/008_indices.sql
```

Para evaluar el ciclo completo se reaprovisionó la base desde cero:
`DROP SCHEMA public CASCADE` + `CREATE SCHEMA`, y luego las ocho migraciones
corriendo de punta a punta. `007_roles.sql` se volvió idempotente (crea los roles
de la API y de reportes solo si no existen) para poder re-ejecutarlo.

## 4. Roles y conexión

- Rol API: `bodegas_api` (lectura/escritura sin privilegios de propietario,
  sin acceso a `Auditoria`). La API se conecta con este rol.
- Rol reportes: `bodegas_report` (solo `SELECT`).
- `REVOKE ALL ... FROM PUBLIC` activo (schema, tablas, rutinas y database).
- Conexión cifrada: el DSN de Neon incluye
  `sslmode=require&channel_binding=require`; cualquier cliente queda obligado a
  TLS. El puerto de Postgres no es un puerto de "internet abierto" en el sentido
  clásico: el acceso es por endpoint con credenciales. La restricción por IP
  (IP Allow) está disponible solo en el plan Scale; el grupo la documentó como
  next step si se migra de plan.

## 5. Carga de datos (reducida, reproducible)

El plan Free limita la base a 1 GB por proyecto, así que en la nube se cargó
escala reducida (el TPI lo permite con justificación) y el volumen completo queda
en la versión local (etapa 3). La carga usa el **mismo script reproducible**
`db/seed/generar.py` con semilla fija (`SEED = 20261108`):

```bash
python db/seed/generar.py --dsn "<NEON_DATABASE_URL>" \
  --vinos 300 --lotes 1500 --ingresos 1000 --transferencias 1000 \
  --clientes 5000 --comprobantes 30000
```

Resultado (12,8 s de carga, ~165 000 filas en total; detalle en
`evidencia/02_inventario_objects.txt`): 300 vinos, 5000 clientes, 30 000
comprobantes y **120 000 renglones de comprobante** (supera el mínimo de
10 000 filas en una tabla), 1500 lotes con sus análisis, 1000 ingresos y 1000
transferencias con renglones. Los triggers de usuario se deshabilitaron durante
la carga histórica (el propio script lo hace y los reactiva, igual que en local).

## 6. Consultas de control

Las consultas de control de la etapa 3 (`db/seed/controles.sql`) corren sobre la
base de Neon tras la carga:

```
vino_sin_bodega                       0
stock_negativo                        0
stock_sala_negativo                   0
detalle_sin_comprobante               0
totales_incorrectos                   0
descuento_distinto_al_tipo_de_cliente 0
subtotal_renglon_incorrecto           0
```

Salida completa en `evidencia/03_controles.txt`. Tamaño de la base en la nube:
una fracción del GB del plan (consultable en el Console; `pg_database_size`
registrado en la evidencia).

## 7. Backup y restauración probados

```bash
# 1) backup (formato custom, desde un cliente igual o más nuevo que el servidor)
docker run --rm -v ./backups:/out postgres:18 \
  pg_dump "<NEON_DATABASE_URL>" -Fc -f /out/neon_backup_<stamp>.dump

# 2) base nueva (contenedor efímero postgres:18 con base vacia prueba_restore)
# 3) restaurar
docker run --rm --network bodegas-atuel_default -e PGPASSWORD=... \
  -v ./backups:/out postgres:18 \
  pg_restore --no-owner --no-acl --role=bodegas_owner \
    -h prueba_pg18 -U bodegas_owner -d prueba_restore /out/neon_backup_<stamp>.dump

# 4) verificar conteos Neon vs restaurada
#    -> COINCIDEN en las 32 tablas (evidencia/05_backup_restore.txt)
```

Notas del proceso: el dump custom se lee con `pg_restore` 18 (formato nuevo del
servidor PG18); en la base de prueba se usó `--no-acl` porque los `GRANT` a los
roles se recrean con `007_roles.sql`. El archivo quedó en `backups/` (`.gitignore`
cubre `*.dump`: los dumps con datos completos no entran al repo). Neon además
ofrece 1 snapshot manual incluido en el plan Free para restores de un clic.

## 8. Regla de negocio comprobada en la nube

Venta sin stock (RN-09) conectado **con el rol de la API** (`bodegas_api`) a la
base de Neon: se elige la combinación sala/vino con menos stock, se inserta un
renglón pidiendo una botella más de las que hay, el trigger `BEFORE INSERT` la
rechaza y la transacción se revierte completa:

```
psql:/dev/stdin:29: ERROR:  Stock insuficiente del vino 261 en la sala 19: hay 101, se piden 102 (RN-09)
CONTEXT:  PL/pgSQL function fn_trg_detalle_validar() line 38 at RAISE
ROLLBACK
comprobantes_de_hoy=0    (no queda ninguna fila a medias)
```

Evidencia completa: `evidencia/04_rn09_venta_sin_stock.txt`.

## 9. Secretos

- `.env` sigue en `.gitignore`; `git log --all -- .env` no muestra ningún commit
  (también se verificó que no existan claves `npg_*` en el historial).
- En el proveedor elegido para la API/front, el DSN y la clave del rol API se
  configuran como variables de entorno del servicio, nunca en el repositorio.
- `.env.example` documenta las variables sin valores reales.

## 10. Despliegue público de API y front (Render)

Neon Functions solo ejecuta JavaScript/TypeScript (la API es FastAPI/Python) y
solo existe en algunas regiones, así que el frente HTTP se publica en **Render**
y la base queda en Neon. `main.py` fue preparado para una sola URL pública:
la API montada en `/` y en `/api` **sirve también el front compilado** de
`front_dist/`, con lo que el sistema entero vive en un único dominio HTTPS y no
hace falta CORS ni copiar URLs entre servicios (la env `CORS_ORIGINS` queda
igual de disponible por si se separa el front más adelante).

### Archivos nuevos

- `Dockerfile.deploy`: imagen única (compila el front con Node, corre la API
  con Python y copia el build del front a `front_dist/`).
- `render.yaml`: Blueprint de Render (servicio `type: web`, `runtime: docker`,
  `healthCheckPath: /salud`).

### Smoke test local de la imagen de despliegue

Probado contra la base de Neon con el rol API (`evidencia/06_api_despliegue.txt`):
`/salud`, `/api/salud`, `/api/vinos` (lecturas de la base en la nube con
`bodegas_api`), `/` y `/transferencias` (SPA) y la venta sin stock:

```
POST /api/comprobantes
{"detail":"Stock insuficiente del vino 261 en la sala 19: hay 101, se piden 5000 (RN-09)","sqlstate":"P0001"}
HTTP 409
```

### Pasos para completar el despliegue (requiere la cuenta del grupo)

1. Hacer push del repo a GitHub.
2. En Render: **New → Blueprint**, elegir el repo (lee `render.yaml`).
3. Cuando pida las variables no sincronizadas, cargar `API_DATABASE_URL`
   con la URL *pooled* de Neon usando el rol de la API:
   `postgresql://bodegas_api:<CLAVE>@ep-...-pooler...sa-east-1.aws.neon.tech/neondb?sslmode=require`
   (tomarla del `.env` local, nunca de un commit).
4. Al terminar, Render asigna `https://bodegas-atuel.onrender.com` (o similar):
   completar la URL en el README y setearla también en `CORS_ORIGINS` si el
   front se separa a otro dominio.
5. Capturar la demo (defensa): `/salud`, tablero con datos de la nube y la
   venta sin stock respondiendo 409 con el mensaje de la regla.

