# Carga de datos (etapa 3)

## Catálogos reales (`catalogos/`)

La consigna pide que los catálogos se carguen desde CSV y no se generen al azar
(Anexo B). Todos los archivos son UTF-8 sin BOM, separados por coma, con LF y
con la fila de encabezado.

| Archivo | Tabla destino | Filas | Fuente |
|---|---|---|---|
| `cepas.csv` | `Cepa (nombre, tipo)` | 12 | Anexo B.1 |
| `maridajes.csv` | `Maridaje (nombre_maridaje, temperatura_servicio)` | 8 | Anexo B.2 (temperaturas orientativas) |
| `departamentos.csv` | — (lo usa el generador para `Finca.departamento`) | 18 | Anexo B.3 |
| `localidades.csv` | `Localidad (cod_postal, nombre, provincia)` | 24 | Cabecera de cada departamento y localidades vitivinícolas |
| `tipos_vino.csv` | — (valores válidos de `Vino.tipo`) | 4 | Anexo B.4 |
| `presentaciones.csv` | — (valores válidos de `Vino.volumen_ml`) | 5 | Anexo B.4 |

Los ID (`id_cepa`, `id_maridaje`) no van en los CSV: los genera la base.

`localidades.csv` trae la columna `departamento` aunque la tabla `Localidad` no
la tiene: sirve para que el generador ubique fincas y salas de forma coherente.
Al cargar se usan solo `cod_postal`, `nombre` y `provincia`.

### Ojo con el código postal como PK

En Argentina el código postal de 4 dígitos no es único por localidad: varias
localidades chicas comparten el mismo (por ejemplo, varios distritos de Maipú).
Por eso este catálogo tiene una sola localidad por código. Si se quieren sumar
más localidades con códigos repetidos, `Localidad` necesita una clave subrogada
(`id_localidad`, como está en el DER) y `cod_postal` como atributo común.

Los códigos son los de 4 dígitos de Correo Argentino. Antes de la entrega
conviene verificarlos en el buscador oficial: https://www.correoargentino.com.ar/formularios/cpa

## Datos ficticios

Bodegas, fincas, clientes, transportistas, empleados y movimientos se generan
con Faker y una semilla fija en [`generar.py`](generar.py). La escala por
defecto cumple los mínimos de la consigna: 20.000 clientes, 150.000
comprobantes y 600.000 renglones de comprobante, además de filas en todas las
tablas.

El orden de dependencias, los volúmenes, los riesgos y los comandos de backup
están documentados en [`informe_carga.md`](informe_carga.md).

### Ejecución

La carga parte de una **base vacía** y se corre con el **usuario dueño**
(`POSTGRES_USER`), no con `DATABASE_URL`: el generador desactiva los triggers
durante la carga y eso solo lo puede hacer el dueño. Con el rol de la API
falla con `must be owner of table`.

La forma más simple es con Docker, sin instalar Python. El comando anda igual
en PowerShell, CMD y Git Bash, desde la raíz del repo:

```bash
docker compose down -v
docker compose up -d db
docker run --rm --network bodegas-atuel_default -v "${PWD}/db/seed:/seed:ro" --env-file .env python:3.12-slim sh -c 'pip install -q "psycopg[binary]" Faker && python /seed/generar.py --dsn "postgresql://$POSTGRES_USER:$POSTGRES_PASSWORD@db:5432/$POSTGRES_DB"'
```

`bodegas-atuel_default` es la red que crea `docker compose` (nombre de la
carpeta del repo + `_default`); si la carpeta se llama distinto, cambia.

Con Python instalado en la PC (3.10 a 3.13), reemplazando las claves por las
del `.env`:

```bash
python -m pip install "psycopg[binary]" Faker
python db/seed/generar.py --dsn "postgresql://bodegas_owner:CLAVE@localhost:5432/bodegas"
```

`--seed` conserva la reproducibilidad. Para una prueba rápida se pueden
reducir `--clientes`, `--comprobantes` y el resto de parámetros de volumen.
La carga parte de una base vacía (para reiniciarla con Docker usar
`docker compose down -v` y luego `docker compose up -d`).
La carga usa `COPY` y lotes de 1.000 filas; el tiempo total se imprime al
finalizar.

Para registrar la comparación pedida entre inserción fila a fila y carga por
lotes:

```bash
python db/seed/medir_carga.py --dsn "postgresql://bodegas_owner:CLAVE@localhost:5432/bodegas" --filas 10000
```

También con el dueño: crea una tabla temporal y el rol de la API no tiene
permiso para eso (007 se lo quita a PUBLIC).

El script informa ambos tiempos y la mejora de `COPY` sobre
`executemany`.

Durante la carga se deshabilitan únicamente los triggers de usuario de las
tablas históricas (`ALTER TABLE ... DISABLE TRIGGER USER`). Las claves
foráneas y restricciones `CHECK` permanecen activas. Se vuelven a habilitar
en un bloque `finally`; después deben ejecutarse [`controles.sql`](controles.sql).
Esto permite cargar comprobantes históricos sin ejecutar descuentos ni
descontar stock nuevamente, pero exige que los controles validen los importes y
stocks generados por el script.

Los catálogos se cargan desde los CSV y no se generan al azar. Para cargar
solamente esos archivos:

```bash
python db/seed/cargar_catalogos.py --dsn "postgresql://bodegas_owner:CLAVE@localhost:5432/bodegas"
```
