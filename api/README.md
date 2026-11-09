# API REST

La API usa FastAPI, `psycopg` y `psycopg_pool`. No usa ORM: el SQL está en
[`repositories.py`](repositories.py), con parámetros separados de las
sentencias. La base sigue siendo responsable de stock, descuentos, totales,
auditoría y transiciones de estado.

Para estudiar la arquitectura, las carpetas y el funcionamiento de cada
componente, consultar el [informe de implementación](informe_api.md).

## Ejecución local

```bash
python -m pip install -r api/requirements.txt
set -a; source .env; set +a
export API_DATABASE_URL="postgresql://${API_DB_USER}:${API_DB_PASSWORD}@localhost:${POSTGRES_PORT:-5432}/${POSTGRES_DB}"
cd api
uvicorn main:app --reload
```

Swagger queda disponible en <http://localhost:8000/docs>.

Las pruebas se ejecutan con la base disponible:

```bash
cd api
pytest -q
```

La suite cubre 11 casos, incluyendo filtros parametrizados, validaciones
HTTP, claves foráneas inexistentes y procesamiento de documentos inválidos.

Los endpoints transaccionales hacen `BEGIN`, ejecutan todas las sentencias y
confirman con `COMMIT`; cualquier error provoca `ROLLBACK`. Los errores de
PostgreSQL se traducen según su SQLSTATE en [`errors.py`](errors.py).
