"""Application settings.

Secrets have no defaults on purpose: a missing value must crash at boot rather
than silently run with `JWT_SECRET="changeme"`.
"""

from functools import lru_cache
from typing import Literal

from pydantic import model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    env: Literal["dev", "staging", "production"] = "dev"
    log_level: str = "INFO"

    database_url: str

    jwt_secret: str
    access_token_days: int = 30
    refresh_token_days: int = 180

    # `console` prints the OTP instead of texting it. It is NOT a bypass code:
    # generation, expiry, attempt limits and verification are byte-identical.
    sms_provider: Literal["console", "msg91"] = "console"

    # Only read when sms_provider == "msg91". Validated at boot so a
    # misconfigured production deploy fails immediately rather than at the
    # moment the first officer tries to sign in.
    msg91_auth_key: str = ""
    msg91_template_id: str = ""
    msg91_sender_id: str = "SATYA"

    demo_mode: bool = False
    demo_reset_key: str = ""

    media_root: str = "./media"
    max_upload_bytes: int = 15_000_000

    satellite_adapter: Literal["fixture", "bhuvan"] = "fixture"

    @model_validator(mode="after")
    def _fail_closed_in_production(self):
        if self.env == "production":
            if self.sms_provider == "console":
                raise ValueError(
                    "console OTP delivery is forbidden in production; "
                    "set SMS_PROVIDER to a real provider"
                )
            if self.demo_mode:
                raise ValueError("DEMO_MODE must be false in production")
        if self.sms_provider == "msg91" and not (
            self.msg91_auth_key and self.msg91_template_id
        ):
            # Booting without these would leave the service up and every
            # sign-in answering 503 -- running, and completely unusable.
            raise ValueError(
                "SMS_PROVIDER=msg91 requires MSG91_AUTH_KEY and MSG91_TEMPLATE_ID"
            )
        if len(self.jwt_secret) < 32:
            raise ValueError("JWT_SECRET must be at least 32 characters")
        return self


@lru_cache
def get_settings() -> Settings:
    return Settings()  # type: ignore[call-arg]


settings = get_settings()
