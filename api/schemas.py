from __future__ import annotations

from datetime import date
from decimal import Decimal
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class CompositionInput(BaseModel):
    id_cepa: int = Field(gt=0)
    porcentaje: Decimal = Field(gt=0, le=100)


class WineCreate(BaseModel):
    anada: int = Field(ge=1990, le=2100)
    tipo: Literal["tinto", "blanco", "rosado", "espumante"]
    nombre_comercial: str = Field(min_length=1, max_length=80)
    precio: Decimal = Field(gt=0)
    graduacion: Decimal = Field(ge=5, le=20)
    volumen_ml: Literal[187, 375, 750, 1500, 3000]
    cuit_bodega: str = Field(pattern=r"^\d{11}$")
    composicion: list[CompositionInput] = Field(min_length=1)
    maridajes: list[int] = Field(default_factory=list)


class WineUpdate(BaseModel):
    precio: Decimal | None = Field(default=None, gt=0)
    nombre_comercial: str | None = Field(default=None, min_length=1, max_length=80)


class ClientCreate(BaseModel):
    apellido: str | None = None
    nombre: str | None = None
    razon_social: str | None = None
    tipo_documento: Literal["DNI", "Pasaporte", "CUIT", "CUIL"]
    nro_documento: str = Field(min_length=1, max_length=20)
    calle: str
    numero: int = Field(gt=0)
    cod_postal: int
    tipo_cliente: Literal["socio", "distribuidor", "exportador"]
    zona_cobertura: str | None = None
    nro_habilitacion: str | None = None
    pais_destino: str | None = None


class ClientUpdate(BaseModel):
    apellido: str | None = None
    nombre: str | None = None
    razon_social: str | None = None
    calle: str | None = None
    numero: int | None = Field(default=None, gt=0)
    cod_postal: int | None = None


class ReceiptLine(BaseModel):
    cod_vino: int = Field(gt=0)
    cantidad: int = Field(gt=0)


class ReceiptCreate(BaseModel):
    id_sala: int = Field(gt=0)
    id_cliente: int = Field(gt=0)
    fecha: date | None = None
    renglones: list[ReceiptLine] = Field(min_length=1)


class DocumentCreate(BaseModel):
    id_sala: int | None = Field(default=None, gt=0)
    cuit_bodega: str | None = Field(default=None, pattern=r"^\d{11}$")
    cod_transporte: int | None = Field(default=None, gt=0)


class DocumentLine(BaseModel):
    cod_vino: int = Field(gt=0)
    cantidad: int = Field(gt=0)


class WineResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    cod_vino: int
    anada: int
    tipo: str
    nombre_comercial: str
    precio: Decimal
    graduacion: Decimal
    volumen_ml: int
    cuit_bodega: str
