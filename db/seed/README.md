# Carga de datos (etapa 3)

## Catálogos reales (`catalogos/`)

La consigna pide que los catálogos se carguen desde CSV y no se generen al azar
(Anexo B). Todos los archivos son UTF-8 sin BOM, separados por coma, con LF y
con la fila de encabezado.

| Archivo | Tabla destino | Filas | Fuente |
|---|---|---|---|
| `cepas.csv` | `Cepa (nombre, tipo)` | 12 | Anexo B.1 |
| `maridajes.csv` | `Maridaje (nombre, temperatura_servicio)` | 8 | Anexo B.2 (temperaturas orientativas) |
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
con Faker y una semilla fija (pendiente: `generar.py`).
