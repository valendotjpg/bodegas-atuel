# Front

React + Vite, con el estilo "moderno sobrio" (blanco, acento bordó, Inter).
Todas las llamadas a la API están en [`src/api.js`](src/api.js); la URL base se
configura con `VITE_API_URL` y por defecto es `/api`.

| Pantalla | Ruta | Qué muestra |
|---|---|---|
| Catálogo | `/` | Listado paginado con filtros por tipo, cepa, bodega y añada; detalle con composición y maridajes |
| Nuevo vino / Editar | `/vinos/nuevo`, `/vinos/:cod/editar` | Alta con composición y maridajes; edición de nombre y precio (auditado) |
| Nueva venta | `/venta` | Sala, cliente y vinos; el comprobante con los importes que calcula la base |
| Transferencias | `/transferencias` | Crear, cargar renglones y pasar de estado con botones según el estado |
| Tablero | `/tablero` | Top 10 de vinos, ventas por sala del último trimestre (gráfico) y vinos sin stock en una sala |

El front no calcula importes, descuentos ni stock: los muestra tal como los
devuelve la API. Los errores de las reglas de la base se muestran con el
mensaje y el SQLSTATE que devuelve la API.

## Con Docker

`docker compose up -d` levanta base, API y front. El front queda en
<http://localhost:8080> (puerto `FRONT_PORT` del `.env`); nginx sirve la
aplicación compilada y redirige `/api` a la API, así que no hace falta CORS.

## En desarrollo

Con la API corriendo en el puerto 8000:

```bash
cd front
npm install
npm run dev
```

Queda en <http://localhost:5173>; Vite redirige `/api` a `http://localhost:8000`
(se cambia con la variable `API_PROXY`).
