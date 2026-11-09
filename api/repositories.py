from __future__ import annotations

from datetime import date
from typing import Any

from psycopg import Connection


def _rows(cursor) -> list[dict[str, Any]]:
    columns = [column.name for column in cursor.description]
    return [dict(zip(columns, row)) for row in cursor.fetchall()]


def health(conn: Connection) -> dict[str, str]:
    row = conn.execute("SELECT current_database() AS database, current_user AS user").fetchone()
    return {"status": "ok", "database": row[0], "user": row[1]}


def list_wines(
    conn: Connection,
    limit: int,
    offset: int,
    tipo: str | None,
    id_cepa: int | None,
    cuit_bodega: str | None,
    anada: int | None,
) -> list[dict[str, Any]]:
    filters = []
    params: list[Any] = []
    if tipo is not None:
        filters.append("v.tipo = %s")
        params.append(tipo)
    if id_cepa is not None:
        filters.append("EXISTS (SELECT 1 FROM composicion c WHERE c.cod_vino = v.cod_vino AND c.id_cepa = %s)")
        params.append(id_cepa)
    if cuit_bodega is not None:
        filters.append("v.cuit_bodega = %s")
        params.append(cuit_bodega)
    if anada is not None:
        filters.append("v.anada = %s")
        params.append(anada)
    where = f"WHERE {' AND '.join(filters)}" if filters else ""
    params.extend([limit, offset])
    cursor = conn.execute(
        f"""
        SELECT v.cod_vino, v.anada, v.tipo, v.nombre_comercial, v.precio,
               v.graduacion, v.volumen_ml, v.cuit_bodega
        FROM vino v
        {where}
        ORDER BY v.cod_vino
        LIMIT %s OFFSET %s
        """,
        params,
    )
    return _rows(cursor)


def get_wine(conn: Connection, cod_vino: int) -> dict[str, Any] | None:
    cursor = conn.execute(
        """
        SELECT v.cod_vino, v.anada, v.tipo, v.nombre_comercial, v.precio,
               v.graduacion, v.volumen_ml, v.cuit_bodega,
               COALESCE(jsonb_agg(DISTINCT jsonb_build_object(
                   'id_cepa', c.id_cepa, 'nombre', c.nombre, 'porcentaje', cp.porcentaje
               )) FILTER (WHERE c.id_cepa IS NOT NULL), '[]') AS composicion,
               COALESCE(jsonb_agg(DISTINCT jsonb_build_object(
                   'id_maridaje', m.id_maridaje, 'nombre', m.nombre_maridaje
               )) FILTER (WHERE m.id_maridaje IS NOT NULL), '[]') AS maridajes
        FROM vino v
        LEFT JOIN composicion cp ON cp.cod_vino = v.cod_vino
        LEFT JOIN cepa c ON c.id_cepa = cp.id_cepa
        LEFT JOIN vino_maridaje vm ON vm.cod_vino = v.cod_vino
        LEFT JOIN maridaje m ON m.id_maridaje = vm.id_maridaje
        WHERE v.cod_vino = %s
        GROUP BY v.cod_vino
        """,
        (cod_vino,),
    )
    row = cursor.fetchone()
    if row is None:
        return None
    columns = [column.name for column in cursor.description]
    return dict(zip(columns, row))


def create_wine(conn: Connection, payload: dict[str, Any]) -> int:
    row = conn.execute(
        """
        INSERT INTO vino (anada, tipo, nombre_comercial, precio, graduacion, volumen_ml, cuit_bodega)
        VALUES (%s, %s, %s, %s, %s, %s, %s)
        RETURNING cod_vino
        """,
        tuple(payload[key] for key in ("anada", "tipo", "nombre_comercial", "precio", "graduacion", "volumen_ml", "cuit_bodega")),
    ).fetchone()
    cod_vino = row[0]
    for composition in payload["composicion"]:
        conn.execute(
            "INSERT INTO composicion (cod_vino, id_cepa, porcentaje) VALUES (%s, %s, %s)",
            (cod_vino, composition["id_cepa"], composition["porcentaje"]),
        )
    for id_maridaje in payload["maridajes"]:
        conn.execute(
            "INSERT INTO vino_maridaje (cod_vino, id_maridaje) VALUES (%s, %s)",
            (cod_vino, id_maridaje),
        )
    conn.execute("SET CONSTRAINTS ALL IMMEDIATE")
    return cod_vino


def update_wine(conn: Connection, cod_vino: int, payload: dict[str, Any]) -> bool:
    fields = []
    params: list[Any] = []
    for key in ("precio", "nombre_comercial"):
        if payload.get(key) is not None:
            fields.append(f"{key} = %s")
            params.append(payload[key])
    if not fields:
        return get_wine(conn, cod_vino) is not None
    params.append(cod_vino)
    cursor = conn.execute(
        f"UPDATE vino SET {', '.join(fields)} WHERE cod_vino = %s",
        params,
    )
    return cursor.rowcount == 1


def delete_wine(conn: Connection, cod_vino: int) -> bool:
    cursor = conn.execute("DELETE FROM vino WHERE cod_vino = %s", (cod_vino,))
    return cursor.rowcount == 1


def list_clients(conn: Connection, limit: int, offset: int) -> list[dict[str, Any]]:
    cursor = conn.execute(
        """
        SELECT c.*, CASE
          WHEN s.id_cliente IS NOT NULL THEN 'socio'
          WHEN d.id_cliente IS NOT NULL THEN 'distribuidor'
          WHEN e.id_cliente IS NOT NULL THEN 'exportador'
        END AS tipo_cliente
        FROM cliente c
        LEFT JOIN socio s ON s.id_cliente = c.id_cliente
        LEFT JOIN distribuidor d ON d.id_cliente = c.id_cliente
        LEFT JOIN exportador e ON e.id_cliente = c.id_cliente
        ORDER BY c.id_cliente LIMIT %s OFFSET %s
        """,
        (limit, offset),
    )
    return _rows(cursor)


def create_client(conn: Connection, payload: dict[str, Any]) -> int:
    row = conn.execute(
        """
        INSERT INTO cliente (apellido, nombre, razon_social, tipo_documento, nro_documento, calle, numero, cod_postal)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s) RETURNING id_cliente
        """,
        tuple(payload[key] for key in ("apellido", "nombre", "razon_social", "tipo_documento", "nro_documento", "calle", "numero", "cod_postal")),
    ).fetchone()
    client_id = row[0]
    if payload["tipo_cliente"] == "socio":
        conn.execute("INSERT INTO socio (id_cliente) VALUES (%s)", (client_id,))
    elif payload["tipo_cliente"] == "distribuidor":
        conn.execute(
            "INSERT INTO distribuidor (id_cliente, zona_cobertura, nro_habilitacion) VALUES (%s, %s, %s)",
            (client_id, payload["zona_cobertura"], payload["nro_habilitacion"]),
        )
    else:
        conn.execute(
            "INSERT INTO exportador (id_cliente, pais_destino) VALUES (%s, %s)",
            (client_id, payload["pais_destino"]),
        )
    return client_id


def get_client(conn: Connection, client_id: int) -> dict[str, Any] | None:
    cursor = conn.execute(
        """
        SELECT c.*, CASE
          WHEN s.id_cliente IS NOT NULL THEN 'socio'
          WHEN d.id_cliente IS NOT NULL THEN 'distribuidor'
          WHEN e.id_cliente IS NOT NULL THEN 'exportador'
        END AS tipo_cliente
        FROM cliente c
        LEFT JOIN socio s ON s.id_cliente = c.id_cliente
        LEFT JOIN distribuidor d ON d.id_cliente = c.id_cliente
        LEFT JOIN exportador e ON e.id_cliente = c.id_cliente
        WHERE c.id_cliente = %s
        """,
        (client_id,),
    )
    rows = _rows(cursor)
    return rows[0] if rows else None


def update_client(conn: Connection, client_id: int, payload: dict[str, Any]) -> bool:
    fields = []
    params: list[Any] = []
    for key in ("apellido", "nombre", "razon_social", "calle", "numero", "cod_postal"):
        if payload.get(key) is not None:
            fields.append(f"{key} = %s")
            params.append(payload[key])
    if not fields:
        return get_client(conn, client_id) is not None
    params.append(client_id)
    return conn.execute(
        f"UPDATE cliente SET {', '.join(fields)} WHERE id_cliente = %s", params
    ).rowcount == 1


def delete_client(conn: Connection, client_id: int) -> bool:
    return conn.execute("DELETE FROM cliente WHERE id_cliente = %s", (client_id,)).rowcount == 1


def create_receipt(conn: Connection, payload: dict[str, Any]) -> int:
    row = conn.execute(
        """
        INSERT INTO comprobante (fecha, subtotal, descuento, total, id_sala, id_cliente)
        VALUES (COALESCE(%s, CURRENT_DATE), 0, 0, 0, %s, %s)
        RETURNING nro_comprobante
        """,
        (payload["fecha"], payload["id_sala"], payload["id_cliente"]),
    ).fetchone()
    receipt_id = row[0]
    for line in payload["renglones"]:
        conn.execute(
            """
            INSERT INTO detalle_comprobante
                (nro_comprobante, cod_vino, cantidad, precio_unitario, descuento_aplicado, subtotal_renglon)
            VALUES (%s, %s, %s, 0, 0, 0)
            """,
            (receipt_id, line["cod_vino"], line["cantidad"]),
        )
    return receipt_id


def get_receipt(conn: Connection, receipt_id: int) -> dict[str, Any] | None:
    head = conn.execute("SELECT * FROM comprobante WHERE nro_comprobante = %s", (receipt_id,)).fetchone()
    if head is None:
        return None
    head_columns = [column.name for column in conn.execute("SELECT * FROM comprobante LIMIT 0").description]
    lines_cursor = conn.execute(
        "SELECT * FROM detalle_comprobante WHERE nro_comprobante = %s ORDER BY cod_vino",
        (receipt_id,),
    )
    return {"comprobante": dict(zip(head_columns, head)), "renglones": _rows(lines_cursor)}


def create_transfer(conn: Connection, id_sala: int) -> int:
    return conn.execute(
        "INSERT INTO transferencia (id_sala) VALUES (%s) RETURNING nro_solicitud",
        (id_sala,),
    ).fetchone()[0]


def add_transfer_line(conn: Connection, transfer_id: int, line: dict[str, Any]) -> None:
    conn.execute(
        "INSERT INTO transferencia_vino (nro_solicitud, cod_vino, cantidad) VALUES (%s, %s, %s)",
        (transfer_id, line["cod_vino"], line["cantidad"]),
    )


def transition_transfer(conn: Connection, transfer_id: int, state: str) -> None:
    conn.execute("UPDATE transferencia SET estado = %s WHERE nro_solicitud = %s", (state, transfer_id))


def process_transfer(conn: Connection, transfer_id: int, deposit_id: int) -> None:
    conn.execute("CALL sp_procesar_transferencia(%s, %s)", (transfer_id, deposit_id))


def create_income(conn: Connection, payload: dict[str, Any]) -> int:
    return conn.execute(
        """
        INSERT INTO ingreso (cuit_bodega, cod_transporte)
        VALUES (%s, %s) RETURNING cod_ingreso
        """,
        (payload["cuit_bodega"], payload["cod_transporte"]),
    ).fetchone()[0]


def add_income_line(conn: Connection, income_id: int, line: dict[str, Any]) -> None:
    conn.execute(
        "INSERT INTO ingreso_vino (cod_ingreso, cod_vino, cantidad) VALUES (%s, %s, %s)",
        (income_id, line["cod_vino"], line["cantidad"]),
    )


def process_income(conn: Connection, income_id: int, deposit_id: int) -> None:
    conn.execute("CALL sp_procesar_ingreso(%s, %s)", (income_id, deposit_id))


def report_stock(conn: Connection) -> list[dict[str, Any]]:
    return _rows(conn.execute("SELECT * FROM v_stock_total ORDER BY cod_vino"))


def report_sales_by_room(conn: Connection) -> list[dict[str, Any]]:
    return _rows(conn.execute("SELECT * FROM v_ventas_mensuales ORDER BY mes DESC, id_sala"))


def report_pending(conn: Connection) -> list[dict[str, Any]]:
    return _rows(conn.execute("SELECT * FROM v_documentos_pendientes ORDER BY fecha_ingreso DESC"))


def report_top_wines(conn: Connection) -> list[dict[str, Any]]:
    return _rows(
        conn.execute(
            """
            SELECT d.cod_vino, v.nombre_comercial, SUM(d.cantidad) AS botellas_vendidas
            FROM detalle_comprobante d
            JOIN vino v ON v.cod_vino = d.cod_vino
            GROUP BY d.cod_vino, v.nombre_comercial
            ORDER BY botellas_vendidas DESC, d.cod_vino
            LIMIT 10
            """
        )
    )


def report_transport_active(conn: Connection) -> list[dict[str, Any]]:
    return _rows(
        conn.execute(
            """
            SELECT t.cod_transporte, t.razon_social, COUNT(i.cod_ingreso) AS ingresos
            FROM transportista t
            LEFT JOIN ingreso i ON i.cod_transporte = t.cod_transporte
            GROUP BY t.cod_transporte, t.razon_social
            ORDER BY ingresos DESC, t.cod_transporte
            """
        )
    )


def report_traceability(conn: Connection, wine_id: int) -> list[dict[str, Any]]:
    return _rows(
        conn.execute(
            """
            SELECT 'ingreso' AS tipo, i.cod_ingreso::text AS documento,
                   i.estado::text AS estado, i.fecha_ingreso AS fecha, iv.cantidad
            FROM ingreso i JOIN ingreso_vino iv ON iv.cod_ingreso = i.cod_ingreso
            WHERE iv.cod_vino = %s
            UNION ALL
            SELECT 'transferencia', t.nro_solicitud::text, t.estado::text,
                   t.fecha, tv.cantidad
            FROM transferencia t JOIN transferencia_vino tv ON tv.nro_solicitud = t.nro_solicitud
            WHERE tv.cod_vino = %s
            ORDER BY fecha DESC
            """,
            (wine_id, wine_id),
        )
    )
