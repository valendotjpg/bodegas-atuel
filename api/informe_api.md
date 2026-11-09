# Informe de implementación de la API REST

## 1. Objetivo

La API REST es la etapa 6 del proyecto Bodegas del Atuel. Su objetivo es
exponer operaciones HTTP para consultar y modificar datos de la bodega sin
duplicar las reglas de negocio que ya existen en PostgreSQL.

La implementación utiliza:

- **Python** como lenguaje.
- **FastAPI** para definir la API HTTP y generar Swagger.
- **psycopg 3** para conectarse a PostgreSQL.
- **psycopg_pool** para reutilizar conexiones.
- **Pydantic** para validar los cuerpos de las solicitudes.
- **SQL directo parametrizado**, sin ORM.

La base de datos continúa siendo responsable de calcular totales, descuentos,
stock, auditoría y validar las restricciones de negocio.

## 2. Carpetas y archivos creados

```text
api/
├── main.py
├── db.py
├── repositories.py
├── schemas.py
├── errors.py
├── requirements.txt
├── Dockerfile
├── README.md
├── informe_api.md
├── .gitignore
└── tests/
    └── test_api.py
```

### `api/main.py`

Es el punto de entrada de la aplicación:

- Crea la instancia de FastAPI.
- Define las rutas HTTP.
- Inicializa y cierra el pool durante el ciclo de vida de la aplicación.
- Abre transacciones para las operaciones que modifican varias tablas.
- Registra el manejador centralizado de errores de PostgreSQL.

### `api/db.py`

Centraliza la conexión a PostgreSQL:

- Lee `API_DATABASE_URL` o `DATABASE_URL`.
- Crea un pool de entre 1 y 10 conexiones.
- Entrega conexiones mediante un context manager.
- Devuelve automáticamente la conexión al pool al terminar la operación.

### `api/repositories.py`

Contiene el acceso a datos:

- Las consultas SQL están separadas de las rutas HTTP.
- Los datos enviados por el usuario se pasan como parámetros `%s`.
- Los filtros dinámicos agregan solamente fragmentos SQL fijos.
- Incluye operaciones de vinos, clientes, comprobantes, ingresos,
  transferencias y reportes.
- Invoca procedimientos almacenados para procesar ingresos y transferencias.

Esta separación permite que `main.py` se concentre en HTTP y que el SQL sea
más fácil de revisar y probar.

### `api/schemas.py`

Define los modelos de entrada y sus validaciones con Pydantic:

- Tipos de vino permitidos.
- Volumen y graduación alcohólica.
- Precios mayores que cero.
- Cantidades positivas.
- Identificadores positivos.
- Formato de CUIT.
- Composición con porcentajes válidos.
- Campos obligatorios según el tipo de solicitud.

Si un cuerpo no cumple estas reglas, FastAPI responde con HTTP `422` sin
ejecutar la consulta.

### `api/errors.py`

Traduce errores de PostgreSQL a respuestas HTTP comprensibles:

| SQLSTATE | HTTP | Significado |
|---|---:|---|
| `23505` | 409 | Registro duplicado |
| `23503` | 409 | Clave foránea inexistente |
| `23514` | 422 | Violación de `CHECK` |
| `23502` | 422 | Campo obligatorio nulo |
| `22P02` | 400 | Formato inválido |
| `P0001` | 409 | Regla de negocio de la base |
| `40001`, `40P01` | 503 | Conflicto o bloqueo transitorio |

### `api/tests/test_api.py`

Contiene 11 pruebas HTTP. Verifica:

- Estado de salud.
- Paginación de vinos.
- Filtros parametrizados.
- Respuestas `404`.
- Validaciones `422`.
- Violaciones de claves foráneas traducidas a `409`.
- Procesamiento de documentos inexistentes.

Las pruebas requieren que PostgreSQL y la API puedan conectarse a una base
inicializada.

### `api/requirements.txt`

Fija las versiones de las dependencias de ejecución y pruebas para que el
entorno sea reproducible.

### `api/Dockerfile`

Construye una imagen Python 3.12, instala las dependencias y ejecuta Uvicorn
en el puerto 8000.

### `api/README.md`

Explica cómo instalar dependencias, iniciar Uvicorn, abrir Swagger y ejecutar
las pruebas.

### `api/.gitignore`

Evita subir cachés de Python y archivos generados localmente.

## 3. Endpoints implementados

### Salud y consultas

| Método | Ruta | Función |
|---|---|---|
| GET | `/salud` | Comprueba la conexión y devuelve base/usuario |
| GET | `/vinos` | Lista vinos con paginación y filtros |
| GET | `/vinos/{cod_vino}` | Consulta un vino con composición y maridajes |
| GET | `/clientes` | Lista clientes paginados |
| GET | `/clientes/{id_cliente}` | Consulta un cliente |
| GET | `/comprobantes/{id}` | Consulta un comprobante y sus renglones |

Los filtros disponibles para vinos son `tipo`, `id_cepa`, `cuit_bodega` y
`anada`. `limit` está limitado entre 1 y 100 para evitar respuestas
excesivamente grandes.

### ABM de vinos

| Método | Ruta | Función |
|---|---|---|
| POST | `/vinos` | Crea un vino, su composición y sus maridajes |
| PUT | `/vinos/{cod_vino}` | Actualiza nombre o precio |
| DELETE | `/vinos/{cod_vino}` | Elimina un vino |

La creación se ejecuta en una única transacción porque inserta el vino y sus
tablas relacionadas.

### ABM de clientes

| Método | Ruta | Función |
|---|---|---|
| POST | `/clientes` | Crea el cliente y su subtipo |
| PUT | `/clientes/{id_cliente}` | Actualiza datos básicos |
| DELETE | `/clientes/{id_cliente}` | Elimina un cliente |

Al crear un cliente se inserta también su registro en `socio`, `distribuidor`
o `exportador`, según `tipo_cliente`.

### Comprobantes

| Método | Ruta | Función |
|---|---|---|
| POST | `/comprobantes` | Crea un comprobante con sus renglones |
| GET | `/comprobantes/{id}` | Devuelve cabecera y detalle |

La API inserta los datos iniciales y PostgreSQL aplica sus triggers y reglas
para calcular los valores definitivos.

### Ingresos y transferencias

| Método | Ruta | Función |
|---|---|---|
| POST | `/ingresos` | Crea un ingreso |
| POST | `/ingresos/{id}/renglones` | Agrega un vino al ingreso |
| POST | `/ingresos/{id}/terminar` | Termina el ingreso |
| POST | `/ingresos/{id}/procesar` | Procesa el ingreso en un depósito |
| POST | `/transferencias` | Crea una transferencia |
| POST | `/transferencias/{id}/renglones` | Agrega un vino a la transferencia |
| POST | `/transferencias/{id}/terminar` | Termina la transferencia |
| POST | `/transferencias/{id}/procesar` | Procesa la transferencia |

El procesamiento llama a `sp_procesar_ingreso` o
`sp_procesar_transferencia`, en lugar de repetir esa lógica en Python.

### Reportes

| Método | Ruta | Función |
|---|---|---|
| GET | `/reportes/top-vinos` | Diez vinos más vendidos |
| GET | `/reportes/ventas-por-sala` | Ventas agrupadas por sala |
| GET | `/reportes/vinos-sin-stock` | Vinos cuyo stock total es cero |
| GET | `/reportes/transportista-activo` | Ingresos por transportista |
| GET | `/reportes/trazabilidad/{cod_vino}` | Historial de ingresos y transferencias |

Los reportes consultan vistas o consultas SQL de solo lectura.

## 4. Flujo de una solicitud

Ejemplo: `POST /vinos`.

1. El cliente envía un JSON.
2. FastAPI recibe la solicitud.
3. Pydantic valida el JSON usando `WineCreate`.
4. FastAPI obtiene una conexión del pool.
5. El repositorio ejecuta SQL parametrizado.
6. La inserción del vino, composición y maridajes ocurre dentro de una
   transacción.
7. PostgreSQL aplica claves foráneas, `CHECK` y triggers.
8. Si todo es correcto, se confirma la transacción y se devuelve HTTP `201`.
9. Si hay un error, se hace rollback y `errors.py` lo convierte en una
   respuesta HTTP adecuada.

## 5. Seguridad y consistencia

- No se concatenan valores recibidos del usuario en el SQL.
- Los valores se envían como parámetros de psycopg.
- Los filtros dinámicos solo utilizan nombres de columnas y condiciones
  definidos por el código.
- La API usa el rol `bodegas_api`, no el propietario de la base.
- Las reglas centrales permanecen en PostgreSQL.
- Las operaciones de varias sentencias utilizan transacciones.
- Los secretos se configuran mediante `.env` y no se suben al repositorio.

## 6. Ejecución

### Con Docker Compose

Desde la raíz del proyecto:

```bash
docker compose --env-file .env up -d --build
```

Luego se puede acceder a:

- Salud: <http://localhost:8000/salud>
- Swagger: <http://localhost:8000/docs>
- ReDoc: <http://localhost:8000/redoc>

### En forma local

```bash
python -m pip install -r api/requirements.txt
set -a; source .env; set +a
export API_DATABASE_URL="postgresql://${API_DB_USER}:${API_DB_PASSWORD}@localhost:${POSTGRES_PORT:-5432}/${POSTGRES_DB}"
cd api
uvicorn main:app --reload
```

## 7. Pruebas

Con PostgreSQL disponible y la API configurada:

```bash
cd api
pytest -q
```

La suite existente contiene 11 pruebas. La implementación fue verificada en
cuanto a sintaxis, registro de rutas y configuración de Compose. La ejecución
integrada contra contenedores debe realizarse con Docker iniciado y con las
variables del archivo `.env` completas.

## 8. Qué queda para completar

La base de la API REST está implementada, pero antes de presentar la etapa
como terminada conviene:

1. Levantar PostgreSQL y la API con Docker.
2. Ejecutar las 11 pruebas contra la base real.
3. Probar manualmente los endpoints desde Swagger.
4. Agregar pruebas específicas para venta sin stock y transiciones de estado
   inválidas.
5. Confirmar que la rama `etapa-6-api` incluya los cambios de base y carga que
   se quieran presentar junto con la API.
