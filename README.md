# Bodegas del Atuel

TPI de Base de Datos, UTN FRSR, Ingenieria en Sistemas, 3.er anio, ciclo 2026.
Sistema de gestion y distribucion de una empresa vitivinicola. Motor: PostgreSQL 14+.
Acceso a datos con SQL directo (sin ORM).

## Requisitos

- Git
- Docker Desktop (con WSL2 en Windows)
- Un cliente SQL: `psql`, DBeaver o pgAdmin
- Python 3.10+ (generador de datos: `psycopg`, `Faker`)
- Lenguaje de la API: *a definir*

## Levantar la base en local

```bash
cp .env.example .env      # completar las claves
docker compose up -d
docker compose logs -f db # ver que las migraciones corran sin errores
```

Para recrear la base desde cero (borra los datos):

```bash
docker compose down -v && docker compose up -d
```

## Estructura

| Carpeta | Contenido |
|---|---|
| `db/migrations/` | `001_esquema.sql` a `008_indices.sql`, en orden |
| `db/seed/` | CSV de catalogos y script de carga masiva |
| `tests/` | `db_tests.sql` (un caso por regla RN-01 a RN-15) |
| `consultas/` | `insert.sql`, `update.sql`, `delete.sql`, `select.sql` |
| `api/` | API REST |
| `front/` | Front |
| `docs/` | DER, diccionario de datos, informes por etapa |

## Hitos

| Hito | Etapa | Estado |
|---|---|---|
| H1 | Modelado | pendiente |
| H2 | Integridad y logica en la base | pendiente |
| H3 | Carga masiva | pendiente |
| H4 | Indices y rendimiento | pendiente |
| H5 | Consultas SQL | pendiente |
| H6 | API | pendiente |
| H7 | Front | pendiente |
| H8 | Nube | pendiente |
| H9 | Documentacion y defensa | pendiente |

## Flujo de trabajo

- Una rama por etapa (`etapa-1-modelado`, `etapa-2-integridad`, ...).
- Pull request con revision de otro integrante antes de integrar a `main`.
- Cada trigger lleva un comentario con la regla que protege (ej. `-- RN-09`).
- La API y el front no calculan totales, descuentos ni stock: llaman a la base.
- Nunca subir secretos. Usar `.env` (ignorado por git).

## Equipo 
Grupo N°7:
- *Mansalve Augusto*
- *Praderio Valentin*
- *Quiroga Constanza*

## URL en la nube

*Pendiente (etapa 8).*
