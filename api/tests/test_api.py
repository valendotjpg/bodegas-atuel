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
