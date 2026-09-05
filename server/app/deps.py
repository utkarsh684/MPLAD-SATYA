"""Shared FastAPI dependencies: auth, RBAC, pagination."""

from __future__ import annotations

import uuid
from collections.abc import Iterator
from typing import Annotated

from fastapi import Depends, Header
from sqlalchemy.orm import Session

from app.db import SessionLocal
from app.errors import ApiError
from app.models import User
from app.security import decode_token


def get_db() -> Iterator[Session]:
    db = SessionLocal()
    try:
        yield db
        db.commit()
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()


DbSession = Annotated[Session, Depends(get_db)]


def current_user(
    db: DbSession,
    authorization: Annotated[str | None, Header()] = None,
) -> User:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise ApiError("UNAUTHENTICATED", "Authentication required.", 401)

    payload = decode_token(authorization.split(" ", 1)[1])
    user = db.get(User, uuid.UUID(payload["sub"]))
    if user is None or not user.is_active:
        raise ApiError("UNAUTHENTICATED", "Account is not active.", 401)

    # Real revocation: bumping token_version invalidates every token for this
    # user in one UPDATE. Free, because RBAC already loaded the row.
    if payload.get("tv") != user.token_version:
        raise ApiError("TOKEN_REVOKED", "Session revoked. Please sign in again.", 401)
    return user


CurrentUser = Annotated[User, Depends(current_user)]


def require_role(*roles: str):
    """Dependency factory enforcing role membership."""

    def _check(user: CurrentUser) -> User:
        if user.role not in roles:
            raise ApiError(
                "FORBIDDEN",
                f"This action requires one of: {', '.join(roles)}.",
                403,
                details={"required_roles": list(roles), "your_role": user.role},
            )
        return user

    return _check
