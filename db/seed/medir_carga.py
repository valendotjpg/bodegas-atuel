#!/usr/bin/env python3
"""Compare row-by-row and COPY insertion on the same PostgreSQL session."""

import argparse
import os
import time

import psycopg


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dsn", default=os.environ.get("DATABASE_URL"))
    parser.add_argument("--filas", type=int, default=10000)
    args = parser.parse_args()
    if not args.dsn:
        parser.error("--dsn or DATABASE_URL is required")
    rows = [(i, f"fila-{i}") for i in range(args.filas)]

    with psycopg.connect(args.dsn) as connection:
        with connection.cursor() as cur:
            cur.execute("CREATE TEMP TABLE medicion_carga (id integer, nombre text)")
            inicio = time.perf_counter()
            cur.executemany("INSERT INTO medicion_carga VALUES (%s, %s)", rows)
            fila_a_fila = time.perf_counter() - inicio

            cur.execute("TRUNCATE medicion_carga")
            inicio = time.perf_counter()
            with cur.copy("COPY medicion_carga (id, nombre) FROM STDIN") as copy:
                for row in rows:
                    copy.write_row(row)
            por_lotes = time.perf_counter() - inicio

    print(f"filas={args.filas}")
    print(f"fila_a_fila_segundos={fila_a_fila:.6f}")
    print(f"copy_segundos={por_lotes:.6f}")
    print(f"mejora={fila_a_fila / por_lotes:.2f}x")


if __name__ == "__main__":
    main()
