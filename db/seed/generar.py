#!/usr/bin/env python3
"""Generate and bulk-load a coherent Bodegas del Atuel dataset.

The default scale satisfies the stage-three volume requirements.  The loader
uses COPY for large tables and temporarily disables only user triggers while
loading historical facts; foreign-key and CHECK constraints remain active.
"""

from __future__ import annotations

import argparse
import csv
import os
import random
import time
from collections import defaultdict
from datetime import date, datetime, timedelta
from decimal import Decimal
from pathlib import Path

import psycopg
from faker import Faker
from psycopg import sql

ROOT = Path(__file__).parent
SEED = 20261108
# Las fechas recientes se calculan desde hoy: las consultas usan CURRENT_DATE.
HOY = date.today()


def read_csv(name: str) -> list[dict[str, str]]:
    with (ROOT / "catalogos" / name).open(encoding="utf-8", newline="") as stream:
        return list(csv.DictReader(stream))


def copy_rows(cur: psycopg.Cursor, table: str, columns: list[str], rows: list[tuple]) -> None:
    if not rows:
        return
    statement = sql.SQL("COPY {} ({}) FROM STDIN").format(
        sql.Identifier(table.lower()), sql.SQL(", ").join(
            map(lambda column: sql.Identifier(column.lower()), columns)
        )
    )
    with cur.copy(statement) as copy:
        for row in rows:
            copy.write_row(row)


def insert_returning(
    cur: psycopg.Cursor, table: str, columns: list[str], rows: list[tuple], key: str
) -> list[int]:
    if not rows:
        return []
    placeholders = "(" + ", ".join(["%s"] * len(columns)) + ")"
    values = ", ".join([placeholders] * len(rows))
    statement = sql.SQL("INSERT INTO {} ({}) VALUES {} RETURNING {}").format(
        sql.Identifier(table.lower()),
        sql.SQL(", ").join(map(lambda column: sql.Identifier(column.lower()), columns)),
        sql.SQL(values),
        sql.Identifier(key.lower()),
    )
    args = [value for row in rows for value in row]
    return [row[0] for row in cur.execute(statement, args).fetchall()]


def chunks(items: list, size: int):
    for start in range(0, len(items), size):
        yield items[start : start + size]


def cuit(number: int) -> str:
    return f"{number:011d}"


def load_catalogs(cur: psycopg.Cursor) -> tuple[list[int], list[int], list[int], list[str], list[int]]:
    localidades = read_csv("localidades.csv")
    cepas = read_csv("cepas.csv")
    maridajes = read_csv("maridajes.csv")
    tipos_vino = [row["tipo"] for row in read_csv("tipos_vino.csv")]
    presentaciones = [int(row["volumen_ml"]) for row in read_csv("presentaciones.csv")]
    copy_rows(
        cur,
        "Localidad",
        ["cod_postal", "nombre", "provincia"],
        [(int(row["cod_postal"]), row["nombre"], row["provincia"]) for row in localidades],
    )
    cepa_ids = insert_returning(
        cur,
        "Cepa",
        ["nombre", "tipo"],
        [(row["nombre"], row["tipo"]) for row in cepas],
        "id_cepa",
    )
    maridaje_ids = insert_returning(
        cur,
        "Maridaje",
        ["nombre_maridaje", "temperatura_servicio"],
        [(row["nombre_maridaje"], Decimal(row["temperatura_servicio"])) for row in maridajes],
        "id_maridaje",
    )
    return (
        [int(row["cod_postal"]) for row in localidades],
        cepa_ids,
        maridaje_ids,
        tipos_vino,
        presentaciones,
    )


def load(args: argparse.Namespace) -> dict[str, int | float]:
    fake = Faker("es_AR")
    Faker.seed(args.seed)
    random.seed(args.seed)
    departamentos = [row["nombre"] for row in read_csv("departamentos.csv")]
    started = time.perf_counter()
    counts: dict[str, int | float] = {}
    with psycopg.connect(args.dsn) as connection:
        with connection.cursor() as cur:
            connection.execute("SET TIME ZONE 'America/Argentina/Mendoza'")
            user_tables = [
                "Composicion", "Vino_Maridaje", "Comprobante",
                "Detalle_Comprobante", "Ingreso_Vino", "Transferencia_Vino",
                "Ingreso", "Transferencia", "Vino", "Lote", "Analisis_Calidad",
                "Stock_Deposito", "Sala_Venta_Vino",
            ]
            for table in user_tables:
                cur.execute(sql.SQL("ALTER TABLE {} DISABLE TRIGGER USER").format(sql.Identifier(table.lower())))
            try:
                localidades, cepa_ids, maridaje_ids, tipos_vino, presentaciones = load_catalogs(cur)

                bodega_rows = [
                    (cuit(30000000000 + i), f"Bodega {i:03d}", fake.street_name(), i + 1)
                    for i in range(args.bodegas)
                ]
                copy_rows(cur, "Bodega", ["cuit_bodega", "razon_social", "calle", "numero"], bodega_rows)
                bodega_ids = [row[0] for row in bodega_rows]

                finca_rows = [
                    (f"Finca {i:04d}", Decimal("10") + i % 200, departamentos[i % len(departamentos)], "Mendoza")
                    for i in range(args.fincas)
                ]
                finca_ids = []
                for batch in chunks(finca_rows, 1000):
                    finca_ids.extend(insert_returning(cur, "Finca", ["nombre", "superficie_ha", "departamento", "provincia"], batch, "id_finca"))

                # D2: la ultima cepa del catalogo no se planta ni compone vinos
                cepas_en_uso = cepa_ids[:-1]
                parcela_rows = []
                parcela_refs = []
                for finca_id in finca_ids:
                    for nro in range(1, args.parcelas_por_finca + 1):
                        parcela_rows.append((finca_id, nro, Decimal("5.00"), 2000 + nro, random.choice(cepas_en_uso)))
                        parcela_refs.append((finca_id, nro))
                copy_rows(cur, "Parcela", ["id_finca", "nro_parcela", "superficie", "anio_plantacion", "id_cepa"], parcela_rows)

                # S12: la ultima bodega es boutique y elabora solo los ultimos 3 vinos
                boutique = bodega_ids[-1]
                vino_rows = []
                for i in range(args.vinos):
                    tipo, presentacion, bodega = random.choice(tipos_vino), None, None
                    fila = (2015 + i % 11, tipo,
                            f"Reserva Atuel {i:05d}", Decimal(400 + i % 1000), Decimal("12.50") + Decimal(i % 40) / 10)
                    presentacion = random.choice(presentaciones)
                    bodega = random.choice(bodega_ids)
                    if i >= args.vinos - 3:
                        bodega = boutique
                    elif bodega == boutique:
                        bodega = bodega_ids[0]
                    vino_rows.append(fila + (presentacion, bodega))
                vino_ids = []
                for batch in chunks(vino_rows, 1000):
                    vino_ids.extend(insert_returning(cur, "Vino", ["anada", "tipo", "nombre_comercial", "precio", "graduacion", "volumen_ml", "cuit_bodega"], batch, "cod_vino"))
                composition = [(vino_id, cepas_en_uso[i % len(cepas_en_uso)], Decimal("100.00")) for i, vino_id in enumerate(vino_ids)]
                copy_rows(cur, "Composicion", ["cod_vino", "id_cepa", "porcentaje"], composition)
                vino_maridaje = [(vino_id, maridaje_ids[i % len(maridaje_ids)]) for i, vino_id in enumerate(vino_ids)]
                copy_rows(cur, "Vino_Maridaje", ["cod_vino", "id_maridaje"], vino_maridaje)
                copy_rows(
                    cur,
                    "Auditoria",
                    ["cod_vino", "usuario", "precio_anterior", "precio_nuevo", "fecha_hora"],
                    [(vino_ids[0], "carga_masiva", (vino_rows[0][3] / Decimal("1.10")).quantize(Decimal("0.01")), vino_rows[0][3], datetime(2025, 1, 1, 0, 0))],
                )

                sala_rows = [(fake.street_name(), i + 1, random.choice(["Lunes", "Martes", "Miércoles", "Jueves", "Viernes"]), localidades[i % len(localidades)]) for i in range(args.salas)]
                sala_ids = []
                for batch in chunks(sala_rows, 1000):
                    sala_ids.extend(insert_returning(cur, "Sala_Venta", ["calle", "numero", "dia_cierre", "cod_postal"], batch, "id_sala"))
                empleado_rows = [
                    (cuit(20000000000 + i), fake.first_name(), fake.last_name(),
                     Decimal("250000") + i, date(2012, 1, 1) + timedelta(days=(i * 97) % 5000),
                     sala_ids[i % len(sala_ids)])
                    for i in range(args.empleados)
                ]
                copy_rows(cur, "Empleado", ["cuit_empleado", "nombre", "apellido", "salario", "fecha_ingreso", "id_sala"], empleado_rows)
                encargado_rows = [(fake.first_name(), fake.last_name(), localidades[i % len(localidades)]) for i in range(max(1, args.salas // 2))]
                copy_rows(cur, "Encargado", ["nombre", "apellido", "cod_postal"], encargado_rows)

                transport_rows = [(f"Transportes Atuel {i:04d}", f"transporte{i}@atuel.test", cuit(27000000000 + i), fake.street_name(), i + 1) for i in range(args.transportistas)]
                transport_ids = []
                for batch in chunks(transport_rows, 1000):
                    transport_ids.extend(insert_returning(cur, "Transportista", ["razon_social", "email", "cuit", "calle", "numero"], batch, "cod_transporte"))
                copy_rows(cur, "Transportista_Telefono", ["cod_transporte", "telefono"], [(i, f"2604{i:06d}") for i in transport_ids])
                copy_rows(cur, "Transportista_Localidad", ["cod_transporte", "cod_postal"], [(i, localidades[n % len(localidades)]) for n, i in enumerate(transport_ids)])

                # RN-04: una cosecha por parcela y campania; hay 5 campanias, asi que entran 5 lotes por parcela
                if args.lotes > 5 * len(parcela_refs):
                    raise SystemExit(f"--lotes no puede superar {5 * len(parcela_refs)} (5 campanias por parcela)")
                lote_rows = []
                for i in range(args.lotes):
                    finca_id, parcela = parcela_refs[i % len(parcela_refs)]
                    fecha = date(HOY.year - 4 + i // len(parcela_refs), 2 + i % 3, 1 + i % 28)
                    lote_rows.append((fecha.year, fecha, Decimal("1000") + i, bodega_ids[i % len(bodega_ids)], finca_id, parcela))
                lote_ids = []
                for batch in chunks(lote_rows, 1000):
                    lote_ids.extend(insert_returning(cur, "Lote", ["campania", "fecha_cosecha", "kilos", "cuit_bodega", "id_finca", "nro_parcela"], batch, "nro_lote"))
                analisis = [(lote_rows[i][1] + timedelta(days=10), Decimal("22.00"), Decimal("3.40"), Decimal("6.00"), lote_id) for i, lote_id in enumerate(lote_ids)]
                copy_rows(cur, "Analisis_Calidad", ["fecha", "grado_brix", "ph", "acidez_total", "nro_lote"], analisis)

                cliente_rows = []
                for i in range(args.clientes):
                    cliente_rows.append((f"Cliente {i:06d}", random.choice(["DNI", "CUIT", "CUIL"]), f"{10000000 + i}", date(2020, 1, 1) + timedelta(days=i % 1500), fake.street_name(), i + 1, localidades[i % len(localidades)]))
                cliente_ids = []
                for batch in chunks(cliente_rows, 1000):
                    cliente_ids.extend(insert_returning(cur, "Cliente", ["razon_social", "tipo_documento", "nro_documento", "fecha_alta", "calle", "numero", "cod_postal"], batch, "id_cliente"))
                copy_rows(cur, "Socio", ["id_cliente"], [(i,) for i in cliente_ids[: max(1, len(cliente_ids) // 3)]])
                distribuidor_ids = cliente_ids[max(1, len(cliente_ids) // 3): max(2, 2 * len(cliente_ids) // 3)]
                copy_rows(cur, "Distribuidor", ["id_cliente", "zona_cobertura", "nro_habilitacion"], [(i, "Cuyo", f"HAB-{i}") for i in distribuidor_ids])
                exportador_ids = cliente_ids[max(2, 2 * len(cliente_ids) // 3):]
                copy_rows(cur, "Exportador", ["id_cliente", "pais_destino"], [(i, "Chile") for i in exportador_ids])
                permisos = [
                    (date(2021, 1, 1) + timedelta(days=365 * n), date(2022, 1, 1) + timedelta(days=365 * n), i)
                    for k, i in enumerate(exportador_ids) for n in range(1 + k % 5)
                ]
                copy_rows(cur, "Permiso_exportacion", ["fecha_emision", "fecha_vencimiento", "id_cliente"], permisos)
                # RN-06: mismos porcentajes que los DEFAULT de Socio, Distribuidor y Exportador
                cliente_descuento = {cliente_id: Decimal("20") for cliente_id in distribuidor_ids}
                cliente_descuento.update({cliente_id: Decimal("30") for cliente_id in exportador_ids})
                cliente_descuento.update({cliente_id: Decimal("10") for cliente_id in cliente_ids[: max(1, len(cliente_ids) // 3)]})

                deposito_ids = insert_returning(cur, "Deposito_Central", ["nombre"], [("Depósito Central",)], "id_deposito")
                deposito_id = deposito_ids[0]
                stock_deposito = [(deposito_id, vino_id, 100000) for vino_id in vino_ids]
                copy_rows(cur, "Stock_Deposito", ["id_deposito", "cod_vino", "cantidad"], stock_deposito)
                # Ultimos 2 anios hasta hoy (I1, S7, D5), con los tres estados y
                # transportistas con actividad desigual (unos mucho, otros casi nada)
                ingreso_rows = [
                    (random.choice(["en_confeccion", "terminado", "procesado"]),
                     HOY - timedelta(days=i % 730),
                     bodega_ids[i % len(bodega_ids)],
                     transport_ids[int(len(transport_ids) * random.random() ** 2)])
                    for i in range(args.ingresos)
                ]
                ingreso_ids = []
                for batch in chunks(ingreso_rows, 1000):
                    ingreso_ids.extend(insert_returning(cur, "Ingreso", ["estado", "fecha_ingreso", "cuit_bodega", "cod_transporte"], batch, "cod_ingreso"))
                ingreso_lines = [(ingreso_id, vino_ids[i % len(vino_ids)], 100 + i % 100) for i, ingreso_id in enumerate(ingreso_ids)]
                copy_rows(cur, "Ingreso_Vino", ["cod_ingreso", "cod_vino", "cantidad"], ingreso_lines)

                # Ultimo anio hasta hoy (S4) y con los tres estados (S5)
                transfer_rows = [
                    (random.choice(["en_confeccion", "terminado", "procesado"]),
                     HOY - timedelta(days=i % 365),
                     sala_ids[i % len(sala_ids)])
                    for i in range(args.transferencias)
                ]
                transfer_ids = []
                for batch in chunks(transfer_rows, 1000):
                    transfer_ids.extend(insert_returning(cur, "Transferencia", ["estado", "fecha", "id_sala"], batch, "nro_solicitud"))
                transfer_lines = [(transfer_id, vino_ids[int(len(vino_ids) * random.random() ** 2)], 10 + i % 20) for i, transfer_id in enumerate(transfer_ids)]
                copy_rows(cur, "Transferencia_Vino", ["nro_solicitud", "cod_vino", "cantidad"], transfer_lines)

                # D4 y D6: 1 de cada 20 clientes nunca compra
                compradores = [cliente_id for k, cliente_id in enumerate(cliente_ids) if k % 20 != 0]
                sales_stock = defaultdict(int)
                price_by_vino = {vino_id: row[3] for vino_id, row in zip(vino_ids, vino_rows)}
                for start in range(0, args.comprobantes, 1000):
                    size = min(1000, args.comprobantes - start)
                    comp_rows = []
                    detail_sets = []
                    for offset in range(size):
                        client_id = compradores[(start + offset) % len(compradores)]
                        sala_id = sala_ids[(start + offset) % len(sala_ids)]
                        # U5, S1, S11: los primeros vinos se venden mucho mas que los ultimos
                        base = int(len(vino_ids) * random.random() ** 2)
                        details = []
                        subtotal = Decimal("0")
                        total = Decimal("0")
                        pct = cliente_descuento[client_id]
                        for line in range(4):
                            idx = (base + line) % len(vino_ids)
                            # S2: el 40 % de los vinos (los ultimos) solo se vende en 1 de cada 3 salas
                            if idx >= len(vino_ids) * 6 // 10 and ((start + offset) % len(sala_ids)) % 3 != 0:
                                idx -= len(vino_ids) * 6 // 10
                            vino_id = vino_ids[idx]
                            quantity = 1 + (start + offset + line) % 3
                            price = price_by_vino[vino_id]
                            # Mismo calculo que fn_total_comprobante y los triggers del 005
                            subtotal += (price * quantity).quantize(Decimal("0.01"))
                            line_total = (price * quantity * (1 - pct / 100)).quantize(Decimal("0.01"))
                            total += line_total
                            details.append((vino_id, quantity, price, pct, line_total))
                            sales_stock[(sala_id, vino_id)] += quantity
                        # Ultimos 7 anios hasta hoy: hay ventas de la ultima semana (S3) y de mas de 5 anios (D1)
                        fecha = HOY - timedelta(days=(start + offset) % 2555)
                        comp_rows.append((fecha, subtotal, subtotal - total, total, sala_id, client_id))
                        detail_sets.append(details)
                    comp_ids = insert_returning(cur, "Comprobante", ["fecha", "subtotal", "descuento", "total", "id_sala", "id_cliente"], comp_rows, "nro_comprobante")
                    detail_rows = [(comp_id, vino_id, quantity, price, discount, line_total) for comp_id, details in zip(comp_ids, detail_sets) for vino_id, quantity, price, discount, line_total in details]
                    copy_rows(cur, "Detalle_Comprobante", ["nro_comprobante", "cod_vino", "cantidad", "precio_unitario", "descuento_aplicado", "subtotal_renglon"], detail_rows)
                copy_rows(cur, "Sala_Venta_Vino", ["id_sala", "cod_vino", "cantidad"], [(sala, vino, quantity + 100) for (sala, vino), quantity in sales_stock.items()])

                counts.update({
                    "clientes": len(cliente_ids), "comprobantes": args.comprobantes,
                    "detalle_comprobante": args.comprobantes * 4, "vinos": len(vino_ids),
                    "elapsed_seconds": round(time.perf_counter() - started, 2),
                })
            finally:
                if connection.info.transaction_status.name == "INERROR":
                    connection.rollback()
                for table in user_tables:
                    cur.execute(
                        sql.SQL("ALTER TABLE {} ENABLE TRIGGER USER").format(
                            sql.Identifier(table.lower())
                        )
                    )
    return counts


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dsn", default=os.environ.get("DATABASE_URL"), help="PostgreSQL DSN (or DATABASE_URL)")
    parser.add_argument("--seed", type=int, default=SEED)
    parser.add_argument("--bodegas", type=int, default=20)
    parser.add_argument("--fincas", type=int, default=50)
    parser.add_argument("--parcelas-por-finca", type=int, default=20)
    parser.add_argument("--vinos", type=int, default=500)
    parser.add_argument("--salas", type=int, default=30)
    parser.add_argument("--empleados", type=int, default=60)
    parser.add_argument("--transportistas", type=int, default=30)
    parser.add_argument("--lotes", type=int, default=5000)
    parser.add_argument("--clientes", type=int, default=20000)
    parser.add_argument("--ingresos", type=int, default=5000)
    parser.add_argument("--transferencias", type=int, default=5000)
    parser.add_argument("--comprobantes", type=int, default=150000)
    args = parser.parse_args()
    if not args.dsn:
        parser.error("--dsn or DATABASE_URL is required")
    print(load(args))


if __name__ == "__main__":
    main()
