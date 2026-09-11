"""Authentication primitives: OTP issuance/verification and JWT.

There is no bypass code. `SMS_PROVIDER=console` changes only the DELIVERY
CHANNEL of an OTP that is generated, expired, rate-limited and verified through
exactly the same code path as a texted one. Production refuses to boot with
console delivery (see config.py), so this cannot be live in a real deployment.
"""

from __future__ import annotations

import hashlib
import hmac
import logging
import secrets
import uuid
from datetime import UTC, datetime, timedelta

import jwt
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.config import settings
from app.errors import ApiError
from app.models import OtpChallenge, User

log = logging.getLogger("satya.auth")

OTP_TTL_SECONDS = 300
OTP_MAX_ATTEMPTS = 5
OTP_MAX_PER_PHONE_PER_WINDOW = 3
OTP_WINDOW_MINUTES = 15
OTP_RESEND_SECONDS = 30

ALGORITHM = "HS256"
# Field officers work offline for days. A token that expires mid-field-day is
# both a demo killer and a real-world one. The long TTL is safe because every
# authenticated request already loads the user for RBAC, so checking
# token_version costs no extra round trip and gives us real revocation.
LEEWAY_SECONDS = 120


def _now() -> datetime:
    return datetime.now(UTC)


def hash_otp(code: str, phone: str) -> str:
    """Peppered SHA-256.

    bcrypt is pointless for a 6-digit code that dies in five minutes under a
    five-attempt cap, and it costs real CPU on a small instance.
    """
    return hmac.new(
        settings.jwt_secret.encode(), f"{phone}:{code}".encode(), hashlib.sha256
    ).hexdigest()


def generate_otp() -> str:
    return f"{secrets.randbelow(1_000_000):06d}"


def issue_otp(db: Session, phone: str, ip: str | None = None) -> tuple[OtpChallenge, str]:
    """Rate-limit, create and (in console mode) log an OTP."""
    window_start = _now() - timedelta(minutes=OTP_WINDOW_MINUTES)

    recent = db.execute(
        select(func.count())
        .select_from(OtpChallenge)
        .where(OtpChallenge.phone == phone, OtpChallenge.created_at >= window_start)
    ).scalar_one()
    if recent >= OTP_MAX_PER_PHONE_PER_WINDOW:
        raise ApiError(
            "OTP_RATE_LIMITED",
            "Too many verification codes requested. Try again in a few minutes.",
            status_code=429,
        )

    last = db.execute(
        select(OtpChallenge)
        .where(OtpChallenge.phone == phone)
        .order_by(OtpChallenge.created_at.desc())
        .limit(1)
    ).scalar_one_or_none()
    if last and (_now() - last.created_at).total_seconds() < OTP_RESEND_SECONDS:
        raise ApiError(
            "OTP_RESEND_TOO_SOON",
            f"Please wait {OTP_RESEND_SECONDS} seconds before requesting another code.",
            status_code=429,
        )

    code = generate_otp()
    challenge = OtpChallenge(
        phone=phone,
        code_hash=hash_otp(code, phone),
        expires_at=_now() + timedelta(seconds=OTP_TTL_SECONDS),
        ip=ip,
    )
    db.add(challenge)
    db.flush()

    if settings.sms_provider == "console":
        log.warning("OTP for %s is %s (console delivery)", phone, code)
    else:
        _send_sms_msg91(phone, code)
    return challenge, code


def _send_sms_msg91(phone: str, code: str) -> None:
    """Deliver the OTP over MSG91's transactional SMS API.

    Previously this branch raised unconditionally, so ENV=production - which
    config.py forces onto a real provider - booted a service on which nobody
    could ever sign in. The credentials are now checked at startup too, so a
    misconfigured deploy fails at boot rather than at an officer's first login.

    MSG91 wants a bare 91XXXXXXXXXX, not +91XXXXXXXXXX.
    """
    import httpx

    mobile = phone.lstrip("+")
    payload = {
        "template_id": settings.msg91_template_id,
        "short_url": "0",
        "recipients": [{"mobiles": mobile, "OTP": code}],
    }
    if settings.msg91_sender_id:
        payload["sender"] = settings.msg91_sender_id

    try:
        response = httpx.post(
            "https://control.msg91.com/api/v5/flow/",
            json=payload,
            headers={
                "authkey": settings.msg91_auth_key,
                "Content-Type": "application/json",
            },
            timeout=10.0,
        )
    except Exception as exc:
        # Never let the provider's exception text reach the client: it can
        # carry the auth key.
        log.exception("MSG91 transport failure for %s", _mask(phone))
        raise ApiError(
            "SMS_DELIVERY_FAILED",
            "We could not send the verification code. Please try again.",
            status_code=503,
        ) from exc

    if response.status_code != 200:
        log.error(
            "MSG91 rejected the request: status=%s body=%s",
            response.status_code, response.text[:200],
        )
        raise ApiError(
            "SMS_DELIVERY_FAILED",
            "We could not send the verification code. Please try again.",
            status_code=503,
        )

    # MSG91 answers 200 with {"type": "error"} for a rejected send, so the
    # status code alone does not mean the message went out.
    body = response.json() if response.content else {}
    if isinstance(body, dict) and body.get("type") == "error":
        log.error("MSG91 error response: %s", str(body)[:200])
        raise ApiError(
            "SMS_DELIVERY_FAILED",
            "We could not send the verification code. Please try again.",
            status_code=503,
        )
    log.info("OTP dispatched via MSG91 to %s", _mask(phone))


def _mask(phone: str) -> str:
    """Never write a full number to the logs."""
    return f"{phone[:3]}****{phone[-3:]}" if len(phone) > 6 else "****"


def verify_otp(db: Session, request_id: uuid.UUID, phone: str, code: str) -> None:
    challenge = db.get(OtpChallenge, request_id)
    if challenge is None or challenge.phone != phone:
        raise ApiError("OTP_INVALID", "That verification code is not valid.", 400)
    if challenge.consumed_at is not None:
        raise ApiError("OTP_ALREADY_USED", "That code has already been used.", 400)
    if challenge.expires_at < _now():
        raise ApiError("OTP_EXPIRED", "That code has expired. Request a new one.", 400)
    if challenge.attempts >= OTP_MAX_ATTEMPTS:
        challenge.consumed_at = _now()
        raise ApiError("OTP_TOO_MANY_ATTEMPTS", "Too many incorrect attempts.", 429)

    challenge.attempts += 1
    if not hmac.compare_digest(challenge.code_hash, hash_otp(code, phone)):
        raise ApiError("OTP_INVALID", "That verification code is not valid.", 400)

    challenge.consumed_at = _now()


def create_access_token(user: User, device_id: str | None = None) -> str:
    now = _now()
    payload = {
        "sub": str(user.id),
        "role": user.role,
        "tv": user.token_version,
        "did": device_id,
        "dist": str(user.district_id) if user.district_id else None,
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(days=settings.access_token_days)).timestamp()),
        "typ": "access",
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm=ALGORITHM)


def create_refresh_token(user: User, device_id: str | None = None) -> str:
    now = _now()
    payload = {
        "sub": str(user.id),
        "tv": user.token_version,
        "did": device_id,
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(days=settings.refresh_token_days)).timestamp()),
        "typ": "refresh",
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm=ALGORITHM)


def decode_token(token: str, expected_type: str = "access") -> dict:
    try:
        payload = jwt.decode(
            token,
            settings.jwt_secret,
            algorithms=[ALGORITHM],
            # Field phones have wrong clocks; allow a little skew.
            leeway=LEEWAY_SECONDS,
        )
    except jwt.ExpiredSignatureError as exc:
        raise ApiError("TOKEN_EXPIRED", "Session expired. Please sign in again.", 401) from exc
    except jwt.PyJWTError as exc:
        raise ApiError("TOKEN_INVALID", "Invalid authentication token.", 401) from exc

    if payload.get("typ") != expected_type:
        raise ApiError("TOKEN_WRONG_TYPE", "Invalid authentication token.", 401)
    return payload


def hash_phone(phone: str) -> str:
    """Pseudonymise a citizen identity for DPDP purpose-limitation."""
    return hmac.new(
        settings.jwt_secret.encode(), phone.encode(), hashlib.sha256
    ).hexdigest()
