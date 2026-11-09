from fastapi import Request
from fastapi.responses import JSONResponse
from psycopg import Error as PsycopgError


SQLSTATE_STATUS = {
    "23502": 422,
    "23503": 409,
    "23505": 409,
    "23514": 422,
    "22P02": 400,
    "40001": 503,
    "40P01": 503,
    "P0001": 409,
    "P0002": 404,
    "55000": 409,
}


def database_error_response(exc: PsycopgError) -> JSONResponse:
    status = SQLSTATE_STATUS.get(exc.sqlstate or "", 500)
    detail = exc.diag.message_primary if exc.diag else str(exc)
    return JSONResponse(status_code=status, content={"detail": detail, "sqlstate": exc.sqlstate})


async def postgres_error_handler(_: Request, exc: PsycopgError) -> JSONResponse:
    return database_error_response(exc)
