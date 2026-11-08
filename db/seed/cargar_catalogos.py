#!/usr/bin/env python3
"""Load only the real catalog CSV files."""

import argparse
import os

import psycopg

from generar import load_catalogs


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dsn", default=os.environ.get("DATABASE_URL"))
    args = parser.parse_args()
    if not args.dsn:
        parser.error("--dsn or DATABASE_URL is required")
    with psycopg.connect(args.dsn) as connection:
        load_catalogs(connection.cursor())


if __name__ == "__main__":
    main()
