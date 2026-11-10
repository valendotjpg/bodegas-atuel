from __future__ import annotations

from contextlib import asynccontextmanager
import os
from pathlib import Path
from typing import Annotated, Literal

from fastapi import APIRouter, Depends, FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from psycopg import Error as PsycopgError
from psycopg_pool import ConnectionPool

from db import connection, create_pool
from errors import postgres_error_handler
from repositories import (
    add_income_line,
    add_transfer_line,
    create_client,
    create_income,
    create_receipt,
    create_transfer,
    create_wine,
    delete_client,
    delete_wine,
    get_client,
    get_receipt,
    get_transfer,
    get_wine,
    health,
    list_bodegas,
    list_cepas,
    list_clients,
    list_depositos,
    list_maridajes,
    list_salas,
    list_transfers,
    list_wines,
    process_income,
    process_transfer,
    report_pending,
    report_sales_by_room,
    report_top_wines,
    report_traceability,
    report_transport_active,
    report_wines_without_stock,
    transition_income,
    transition_transfer,
    update_client,
    update_wine,
)
from schemas import (
    ClientCreate,
    ClientUpdate,
    DocumentCreate,
    DocumentLine,
    ReceiptCreate,
    WineCreate,
    WineUpdate,
)


@asynccontextmanager
async def lifespan(app: FastAPI):
    pool = create_pool()
    pool.open()
    pool.wait()
    app.state.pool = pool
    yield
    pool.close()


app = FastAPI(
    title="Bodegas del Atuel API",
    version="1.0.0",
    description="API REST con SQL parametrizado y reglas de negocio en PostgreSQL.",
    lifespan=lifespan,
)
cors_origins = [
    origin.strip()
    for origin in os.environ.get("CORS_ORIGINS", "").split(",")
    if origin.strip()
]
if cors_origins:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=cors_origins,
        allow_methods=["*"],
        allow_headers=["*"],
    )
app.add_exception_handler(PsycopgError, postgres_error_handler)


def get_pool() -> ConnectionPool:
    return app.state.pool


Pool = Annotated[ConnectionPool, Depends(get_pool)]

# Todas las rutas viven en este router, montado dos veces: los clientes pueden
# llamar a /vinos (raiz, front servido por esta misma API) o a /api/vinos
# (default de front/src/api.js; en local lo usa el proxy de nginx/vite).
api_router = APIRouter()


@api_router.get("/salud")
def health_check(pool: Pool):
    with connection(pool) as conn:
        return health(conn)


@api_router.get("/vinos")
def wines(
    pool: Pool,
    limit: int = Query(default=20, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    tipo: str | None = None,
    id_cepa: int | None = Query(default=None, gt=0),
    cuit_bodega: str | None = None,
    anada: int | None = Query(default=None, ge=1990, le=2100),
    q: str | None = Query(default=None, min_length=1, max_length=80),
):
    with connection(pool) as conn:
        return list_wines(conn, limit, offset, tipo, id_cepa, cuit_bodega, anada, q)


@api_router.get("/vinos/{cod_vino}")
def wine(cod_vino: int, pool: Pool):
    with connection(pool) as conn:
        result = get_wine(conn, cod_vino)
    if result is None:
        raise HTTPException(status_code=404, detail="Vino no encontrado")
    return result


@api_router.post("/vinos", status_code=201)
def create_wine_endpoint(payload: WineCreate, pool: Pool):
    with connection(pool) as conn:
        with conn.transaction():
            wine_id = create_wine(conn, payload.model_dump())
        return get_wine(conn, wine_id)


@api_router.put("/vinos/{cod_vino}")
def update_wine_endpoint(cod_vino: int, payload: WineUpdate, pool: Pool):
    with connection(pool) as conn:
        with conn.transaction():
            updated = update_wine(conn, cod_vino, payload.model_dump(exclude_unset=True))
        if not updated:
            raise HTTPException(status_code=404, detail="Vino no encontrado")
        return get_wine(conn, cod_vino)


@api_router.delete("/vinos/{cod_vino}", status_code=204)
def delete_wine_endpoint(cod_vino: int, pool: Pool):
    with connection(pool) as conn:
        with conn.transaction():
            deleted = delete_wine(conn, cod_vino)
    if not deleted:
        raise HTTPException(status_code=404, detail="Vino no encontrado")


@api_router.get("/clientes")
def clients(
    pool: Pool,
    limit: int = Query(default=20, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    q: str | None = Query(default=None, min_length=1, max_length=50),
):
    with connection(pool) as conn:
        return list_clients(conn, limit, offset, q)


@api_router.get("/clientes/{client_id}")
def client(client_id: int, pool: Pool):
    with connection(pool) as conn:
        result = get_client(conn, client_id)
    if result is None:
        raise HTTPException(status_code=404, detail="Cliente no encontrado")
    return result


@api_router.post("/clientes", status_code=201)
def create_client_endpoint(payload: ClientCreate, pool: Pool):
    with connection(pool) as conn:
        with conn.transaction():
            client_id = create_client(conn, payload.model_dump())
        return get_client(conn, client_id)


@api_router.put("/clientes/{client_id}")
def update_client_endpoint(client_id: int, payload: ClientUpdate, pool: Pool):
    with connection(pool) as conn:
        with conn.transaction():
            updated = update_client(conn, client_id, payload.model_dump(exclude_unset=True))
        if not updated:
            raise HTTPException(status_code=404, detail="Cliente no encontrado")
        return get_client(conn, client_id)


@api_router.delete("/clientes/{client_id}", status_code=204)
def delete_client_endpoint(client_id: int, pool: Pool):
    with connection(pool) as conn:
        with conn.transaction():
            deleted = delete_client(conn, client_id)
    if not deleted:
        raise HTTPException(status_code=404, detail="Cliente no encontrado")


@api_router.post("/comprobantes", status_code=201)
def create_receipt_endpoint(payload: ReceiptCreate, pool: Pool):
    with connection(pool) as conn:
        with conn.transaction():
            receipt_id = create_receipt(conn, payload.model_dump())
        return get_receipt(conn, receipt_id)


@api_router.get("/comprobantes/{receipt_id}")
def receipt(receipt_id: int, pool: Pool):
    with connection(pool) as conn:
        result = get_receipt(conn, receipt_id)
    if result is None:
        raise HTTPException(status_code=404, detail="Comprobante no encontrado")
    return result


@api_router.get("/transferencias")
def transfers(
    pool: Pool,
    limit: int = Query(default=20, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    estado: Literal["en_confeccion", "terminado", "procesado"] | None = None,
    id_sala: int | None = Query(default=None, gt=0),
):
    with connection(pool) as conn:
        return list_transfers(conn, limit, offset, estado, id_sala)


@api_router.get("/transferencias/{transfer_id}")
def transfer(transfer_id: int, pool: Pool):
    with connection(pool) as conn:
        result = get_transfer(conn, transfer_id)
    if result is None:
        raise HTTPException(status_code=404, detail="Transferencia no encontrada")
    return result


@api_router.post("/transferencias", status_code=201)
def create_transfer_endpoint(payload: DocumentCreate, pool: Pool):
    if payload.id_sala is None:
        raise HTTPException(status_code=422, detail="id_sala es obligatorio")
    with connection(pool) as conn:
        with conn.transaction():
            return {"nro_solicitud": create_transfer(conn, payload.id_sala)}


@api_router.post("/transferencias/{transfer_id}/renglones", status_code=201)
def transfer_line(transfer_id: int, payload: DocumentLine, pool: Pool):
    with connection(pool) as conn:
        with conn.transaction():
            add_transfer_line(conn, transfer_id, payload.model_dump())
    return {"status": "ok"}


@api_router.post("/transferencias/{transfer_id}/terminar")
def finish_transfer(transfer_id: int, pool: Pool):
    with connection(pool) as conn:
        with conn.transaction():
            found = transition_transfer(conn, transfer_id, "terminado")
    if not found:
        raise HTTPException(status_code=404, detail="Transferencia no encontrada")
    return {"status": "terminado", "nro_solicitud": transfer_id}


@api_router.post("/transferencias/{transfer_id}/procesar")
def process_transfer_endpoint(transfer_id: int, deposit_id: int, pool: Pool):
    with connection(pool) as conn:
        with conn.transaction():
            process_transfer(conn, transfer_id, deposit_id)
    return {"status": "procesado", "nro_solicitud": transfer_id}


@api_router.post("/ingresos", status_code=201)
def create_income_endpoint(payload: DocumentCreate, pool: Pool):
    if payload.cuit_bodega is None or payload.cod_transporte is None:
        raise HTTPException(status_code=422, detail="cuit_bodega y cod_transporte son obligatorios")
    with connection(pool) as conn:
        with conn.transaction():
            return {"cod_ingreso": create_income(conn, payload.model_dump())}


@api_router.post("/ingresos/{income_id}/renglones", status_code=201)
def income_line(income_id: int, payload: DocumentLine, pool: Pool):
    with connection(pool) as conn:
        with conn.transaction():
            add_income_line(conn, income_id, payload.model_dump())
    return {"status": "ok"}


@api_router.post("/ingresos/{income_id}/terminar")
def finish_income(income_id: int, pool: Pool):
    with connection(pool) as conn:
        with conn.transaction():
            found = transition_income(conn, income_id, "terminado")
    if not found:
        raise HTTPException(status_code=404, detail="Ingreso no encontrado")
    return {"status": "terminado", "cod_ingreso": income_id}


@api_router.post("/ingresos/{income_id}/procesar")
def process_income_endpoint(income_id: int, deposit_id: int, pool: Pool):
    with connection(pool) as conn:
        with conn.transaction():
            process_income(conn, income_id, deposit_id)
    return {"status": "procesado", "cod_ingreso": income_id}


@api_router.get("/reportes/top-vinos")
def top_wines(pool: Pool):
    with connection(pool) as conn:
        return report_top_wines(conn)


@api_router.get("/reportes/ventas-por-sala")
def sales_by_room(pool: Pool):
    with connection(pool) as conn:
        return report_sales_by_room(conn)


@api_router.get("/reportes/vinos-sin-stock")
def wines_without_stock(pool: Pool, id_sala: int = Query(gt=0)):
    with connection(pool) as conn:
        return report_wines_without_stock(conn, id_sala)


@api_router.get("/reportes/transportista-activo")
def active_carriers(pool: Pool):
    with connection(pool) as conn:
        return report_transport_active(conn)


@api_router.get("/reportes/trazabilidad/{cod_vino}")
def traceability(cod_vino: int, pool: Pool):
    with connection(pool) as conn:
        return report_traceability(conn, cod_vino)


@api_router.get("/cepas")
def cepas(pool: Pool):
    with connection(pool) as conn:
        return list_cepas(conn)


@api_router.get("/bodegas")
def bodegas(pool: Pool):
    with connection(pool) as conn:
        return list_bodegas(conn)


@api_router.get("/maridajes")
def maridajes(pool: Pool):
    with connection(pool) as conn:
        return list_maridajes(conn)


@api_router.get("/salas")
def salas(pool: Pool):
    with connection(pool) as conn:
        return list_salas(conn)


@api_router.get("/depositos")
def depositos(pool: Pool):
    with connection(pool) as conn:
        return list_depositos(conn)


# Doble montaje del mismo router: raiz + /api.
app.include_router(api_router)
app.include_router(api_router, prefix="/api")

# Despliegue en la nube (etapa 8): cuando la imagen incluye el front compilado en
# front_dist/, esta misma API lo sirve (misma URL publica, sin CORS). En local y
# en docker compose no existe esa carpeta y las rutas no cambian.
FRONT_DIST = Path(__file__).resolve().parent / "front_dist"
if FRONT_DIST.is_dir():
    app.mount("/assets", StaticFiles(directory=FRONT_DIST / "assets"), name="assets")
    @app.get("/", include_in_schema=False)
    @app.get("/vinos/nuevo", include_in_schema=False)
    @app.get("/vinos/{cod_vino}/editar", include_in_schema=False)
    @app.get("/venta", include_in_schema=False)
    @app.get("/transferencias", include_in_schema=False)
    @app.get("/tablero", include_in_schema=False)
    def front(cod_vino: int | None = None):
        return FileResponse(FRONT_DIST / "index.html")
