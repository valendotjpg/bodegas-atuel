from __future__ import annotations

import os
from contextlib import contextmanager
from typing import Iterator

from psycopg import Connection
from psycopg_pool import ConnectionPool


def create_pool() -> ConnectionPool:
    dsn = os.environ.get("API_DATABASE_URL") or os.environ.get("DATABASE_URL")
    if not dsn:
        raise RuntimeError("DATABASE_URL es obligatoria")
    return ConnectionPool(conninfo=dsn, min_size=1, max_size=10, open=False)


@contextmanager
def connection(pool: ConnectionPool) -> Iterator[Connection]:
    with pool.connection() as conn:
        yield conn
