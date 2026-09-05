"""One error envelope for every non-2xx response.

FastAPI's defaults are inconsistent with themselves: HTTPException produces
{"detail": "a string"} while RequestValidationError produces
{"detail": [ {...} ]} -- same key, different type. That forces the Flutter team
to write two parsers and guess which applies. Thirty lines removes it for good.
"""

from __future__ import annotations

import logging
import uuid
from typing import Any

from fastapi import FastAPI, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from starlette.exceptions import HTTPException as StarletteHTTPException

log = logging.getLogger("satya")


class ErrorBody(BaseModel):
    code: str
    message: str
    message_key: str | None = None
    details: dict[str, Any] | None = None
    field_errors: list[dict[str, Any]] | None = None
    request_id: str | None = None


class ErrorResponse(BaseModel):
    error: ErrorBody


class ApiError(Exception):
    """Raise this, not HTTPException, so `code` is always a stable string."""

    def __init__(
        self,
        code: str,
        message: str,
        status_code: int = status.HTTP_400_BAD_REQUEST,
        details: dict | None = None,
    ):
        self.code = code
        self.message = message
        self.status_code = status_code
        self.details = details
        super().__init__(message)


def _envelope(
    request: Request, status_code: int, code: str, message: str, **extra
) -> JSONResponse:
    rid = getattr(request.state, "request_id", None)
    body = {
        "error": {
            "code": code,
            "message": message,
            "message_key": f"error.{code.lower()}",
            "request_id": rid,
            **extra,
        }
    }
    return JSONResponse(status_code=status_code, content=body, headers={"X-Request-ID": rid or ""})


def install(app: FastAPI) -> None:
    @app.exception_handler(ApiError)
    async def _api_error(request: Request, exc: ApiError):
        return _envelope(
            request, exc.status_code, exc.code, exc.message, details=exc.details
        )

    @app.exception_handler(StarletteHTTPException)
    async def _http_error(request: Request, exc: StarletteHTTPException):
        code = {
            401: "UNAUTHENTICATED", 403: "FORBIDDEN", 404: "NOT_FOUND",
            405: "METHOD_NOT_ALLOWED", 409: "CONFLICT", 413: "PAYLOAD_TOO_LARGE",
            429: "RATE_LIMITED",
        }.get(exc.status_code, "HTTP_ERROR")
        return _envelope(request, exc.status_code, code, str(exc.detail))

    @app.exception_handler(RequestValidationError)
    async def _validation_error(request: Request, exc: RequestValidationError):
        fields = [
            {"field": ".".join(str(p) for p in e["loc"]), "message": e["msg"]}
            for e in exc.errors()
        ]
        return _envelope(
            request, status.HTTP_422_UNPROCESSABLE_ENTITY,
            "VALIDATION_ERROR", "Request validation failed", field_errors=fields,
        )

    @app.exception_handler(Exception)
    async def _unhandled(request: Request, exc: Exception):
        rid = getattr(request.state, "request_id", None)
        # Log the traceback against the request id; never leak it to the client.
        log.exception("unhandled error request_id=%s path=%s", rid, request.url.path)
        return _envelope(
            request, status.HTTP_500_INTERNAL_SERVER_ERROR,
            "INTERNAL_ERROR", "An unexpected error occurred.",
        )


def new_request_id() -> str:
    return uuid.uuid4().hex[:16]
