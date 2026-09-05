"""Phone OTP authentication."""

from __future__ import annotations

import uuid

from fastapi import APIRouter, Request, status
from sqlalchemy import select

from app.config import settings
from app.deps import CurrentUser, DbSession
from app.errors import ApiError
from app.models import PushToken, User
from app.schemas import (
    DeviceIn,
    OtpRequestIn,
    OtpRequestOut,
    OtpVerifyIn,
    RefreshIn,
    TokenPair,
    UserOut,
)
from app.security import (
    OTP_RESEND_SECONDS,
    OTP_TTL_SECONDS,
    create_access_token,
    create_refresh_token,
    decode_token,
    issue_otp,
    verify_otp,
)

router = APIRouter(prefix="/api/v1/auth", tags=["auth"])


def _mask(phone: str) -> str:
    return phone[:3] + "X" * max(0, len(phone) - 7) + phone[-4:]


def _user_out(user: User) -> UserOut:
    return UserOut(
        id=user.id,
        name=user.name,
        role=user.role,
        phone_masked=_mask(user.phone),
        district_id=user.district_id,
        district_name=None,
    )


def _tokens(user: User, device_id: str | None) -> TokenPair:
    return TokenPair(
        access_token=create_access_token(user, device_id),
        refresh_token=create_refresh_token(user, device_id),
        expires_in=settings.access_token_days * 86400,
        user=_user_out(user),
    )


def _register_device(db: DbSession, user: User, device: DeviceIn | None) -> None:
    if device is None or not device.fcm_token:
        return
    existing = db.execute(
        select(PushToken).where(PushToken.token == device.fcm_token)
    ).scalar_one_or_none()
    if existing:
        existing.user_id = user.id
        existing.device_id = device.device_id
        existing.revoked_at = None
    else:
        db.add(
            PushToken(
                user_id=user.id,
                token=device.fcm_token,
                platform=device.platform,
                device_id=device.device_id,
            )
        )


@router.post(
    "/otp/request",
    operation_id="requestOtp",
    response_model=OtpRequestOut,
    summary="Request a one-time verification code",
)
def request_otp(body: OtpRequestIn, db: DbSession, request: Request):
    """Always returns 200 whether or not the number is registered.

    Revealing which numbers exist would be free account enumeration.
    """
    challenge, code = issue_otp(db, body.phone, ip=request.client.host if request.client else None)
    return OtpRequestOut(
        request_id=challenge.id,
        expires_in=OTP_TTL_SECONDS,
        resend_after=OTP_RESEND_SECONDS,
        debug_code=code if settings.sms_provider == "console" else None,
    )


@router.post(
    "/otp/verify",
    operation_id="verifyOtp",
    response_model=TokenPair,
    summary="Exchange a verification code for tokens",
)
def verify(body: OtpVerifyIn, db: DbSession):
    verify_otp(db, body.request_id, body.phone, body.otp)

    user = db.execute(select(User).where(User.phone == body.phone)).scalar_one_or_none()
    if user is None:
        # Unregistered numbers self-provision as citizens. Officer roles are
        # pre-provisioned by an admin; verification never elevates a role.
        user = User(phone=body.phone, role="citizen", is_active=True)
        db.add(user)
        db.flush()

    _register_device(db, user, body.device)
    return _tokens(user, body.device.device_id if body.device else None)


@router.post(
    "/refresh", operation_id="refreshToken", response_model=TokenPair, summary="Rotate tokens"
)
def refresh(body: RefreshIn, db: DbSession):
    payload = decode_token(body.refresh_token, expected_type="refresh")
    user = db.get(User, uuid.UUID(payload["sub"]))
    if user is None or not user.is_active or payload.get("tv") != user.token_version:
        raise ApiError("TOKEN_REVOKED", "Session revoked. Please sign in again.", 401)
    return _tokens(user, payload.get("did"))


@router.get("/me", operation_id="getMe", response_model=UserOut, summary="Current user")
def me(user: CurrentUser):
    return _user_out(user)


@router.post(
    "/logout",
    operation_id="logout",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Revoke every session for this user",
)
def logout(user: CurrentUser, db: DbSession):
    user.token_version += 1
    db.add(user)
