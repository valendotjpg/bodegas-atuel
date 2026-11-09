import os
import sys
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

os.environ.setdefault("DATABASE_URL", "postgresql://bodegas_api:password@localhost:5432/bodegas")
sys.path.insert(0, str(Path(__file__).parents[1]))

from main import app


@pytest.fixture(scope="module")
def client():
    with TestClient(app) as test_client:
        yield test_client


def test_health(client):
    response = client.get("/salud")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"


def test_wine_list_is_paginated(client):
    response = client.get("/vinos?limit=1&offset=0")
    assert response.status_code == 200
    assert isinstance(response.json(), list)
    assert len(response.json()) <= 1


def test_wine_filter_is_parameterized(client):
    response = client.get("/vinos", params={"tipo": "' OR 1=1 --"})
    assert response.status_code == 200
    assert isinstance(response.json(), list)


def test_missing_wine_returns_404(client):
    assert client.get("/vinos/2147483647").status_code == 404


def test_missing_client_returns_404(client):
    assert client.get("/clientes/2147483647").status_code == 404


def test_missing_receipt_returns_404(client):
    assert client.get("/comprobantes/2147483647").status_code == 404


def test_invalid_wine_payload_is_rejected(client):
    response = client.post("/vinos", json={"precio": -1})
    assert response.status_code == 422


def test_invalid_transfer_payload_is_rejected(client):
    response = client.post("/transferencias", json={"id_sala": 0})
    assert response.status_code == 422


def test_missing_bodega_is_a_database_conflict(client):
    response = client.post(
        "/vinos",
        json={
            "anada": 2025,
            "tipo": "tinto",
            "nombre_comercial": "Vino API test",
            "precio": 100,
            "graduacion": 12,
            "volumen_ml": 750,
            "cuit_bodega": "30999999999",
            "composicion": [{"id_cepa": 1, "porcentaje": 100}],
        },
    )
    assert response.status_code == 409


def test_missing_transfer_is_a_database_conflict(client):
    response = client.post(
        "/transferencias/2147483647/renglones",
        json={"cod_vino": 1, "cantidad": 1},
    )
    assert response.status_code == 409


def test_missing_income_is_a_database_conflict(client):
    response = client.post("/ingresos/2147483647/procesar?deposit_id=1")
    assert response.status_code == 409


# --- Reglas de la base que la API traduce a HTTP (necesitan la carga masiva) ---

def _ids(client):
    sala = client.get("/salas").json()[0]["id_sala"]
    cliente = client.get("/clientes?limit=1").json()[0]["id_cliente"]
    vinos = [v["cod_vino"] for v in client.get("/vinos?limit=2").json()]
    deposito = client.get("/depositos").json()[0]["id_deposito"]
    return sala, cliente, vinos, deposito


def test_sale_without_stock_is_409(client):
    sala, cliente, vinos, _ = _ids(client)
    response = client.post(
        "/comprobantes",
        json={"id_sala": sala, "id_cliente": cliente, "renglones": [{"cod_vino": vinos[0], "cantidad": 999999}]},
    )
    assert response.status_code == 409
    assert "Stock insuficiente" in response.json()["detail"]
    assert response.json()["sqlstate"] == "P0001"


def test_process_unfinished_transfer_is_409(client):
    sala, _, _, deposito = _ids(client)
    nro = client.post("/transferencias", json={"id_sala": sala}).json()["nro_solicitud"]
    response = client.post(f"/transferencias/{nro}/procesar?deposit_id={deposito}")
    assert response.status_code == 409
    assert client.get(f"/transferencias/{nro}").json()["estado"] == "en_confeccion"


def test_line_on_finished_transfer_is_409(client):
    sala, _, vinos, _ = _ids(client)
    nro = client.post("/transferencias", json={"id_sala": sala}).json()["nro_solicitud"]
    assert client.post(f"/transferencias/{nro}/renglones", json={"cod_vino": vinos[0], "cantidad": 1}).status_code == 201
    assert client.post(f"/transferencias/{nro}/terminar").status_code == 200
    response = client.post(f"/transferencias/{nro}/renglones", json={"cod_vino": vinos[1], "cantidad": 1})
    assert response.status_code == 409
    assert "RN-12" in response.json()["detail"]


def test_wine_composition_not_100_is_409(client):
    bodega = client.get("/bodegas").json()[0]["cuit_bodega"]
    cepa = client.get("/cepas").json()[0]["id_cepa"]
    response = client.post(
        "/vinos",
        json={
            "anada": 2024, "tipo": "tinto", "nombre_comercial": "Corte incompleto API",
            "precio": 100, "graduacion": 13, "volumen_ml": 750, "cuit_bodega": bodega,
            "composicion": [{"id_cepa": cepa, "porcentaje": 60}],
        },
    )
    assert response.status_code == 409
    assert "RN-05" in response.json()["detail"]


def test_finish_missing_transfer_is_404(client):
    assert client.post("/transferencias/2147483647/terminar").status_code == 404


def test_catalog_endpoints(client):
    for path in ("/cepas", "/bodegas", "/maridajes", "/salas", "/depositos"):
        response = client.get(path)
        assert response.status_code == 200
        assert len(response.json()) > 0


def test_wines_without_stock_needs_a_room(client):
    assert client.get("/reportes/vinos-sin-stock").status_code == 422
    sala = client.get("/salas").json()[0]["id_sala"]
    assert client.get(f"/reportes/vinos-sin-stock?id_sala={sala}").status_code == 200
