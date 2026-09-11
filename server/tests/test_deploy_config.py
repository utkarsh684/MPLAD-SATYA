"""The deployment must be able to boot AND be usable.

A service that starts and then refuses every sign-in is worse than one that
fails to start: it looks healthy. These tests pin the configurations that are
actually deployable.
"""

import pytest
from pydantic import ValidationError

from app.config import Settings

BASE = {
    "database_url": "postgresql+psycopg://u:p@h/db",
    "jwt_secret": "x" * 32,
    "demo_mode": False,
}


def _settings(**over):
    # _env_file=None keeps the developer's local .env (which sets DEMO_MODE=true)
    # out of these assertions -- the question is what the SHIPPED config does.
    return Settings(_env_file=None, **{**BASE, **over})


class TestProductionFailsClosed:
    def test_console_otp_is_refused_in_production(self):
        with pytest.raises((ValidationError, ValueError)):
            _settings(env="production", sms_provider="console")

    def test_demo_mode_is_refused_in_production(self):
        with pytest.raises((ValidationError, ValueError)):
            _settings(env="production", sms_provider="msg91",
                      msg91_auth_key="k", msg91_template_id="t", demo_mode=True)

    def test_short_jwt_secret_is_refused_everywhere(self):
        with pytest.raises((ValidationError, ValueError)):
            _settings(jwt_secret="tooshort")


class TestMsg91MustBeUsableIfSelected:
    """Selecting a provider without credentials used to boot a dead service."""

    def test_msg91_without_credentials_refuses_to_boot(self):
        with pytest.raises((ValidationError, ValueError)):
            _settings(sms_provider="msg91")

    def test_msg91_without_template_refuses_to_boot(self):
        with pytest.raises((ValidationError, ValueError)):
            _settings(sms_provider="msg91", msg91_auth_key="key-only")

    def test_msg91_with_full_credentials_boots(self):
        s = _settings(env="production", sms_provider="msg91",
                      msg91_auth_key="k", msg91_template_id="t")
        assert s.sms_provider == "msg91"
        assert s.env == "production"


class TestRenderConfigIsDeployable:
    """render.yaml must describe a service that a judge can actually sign into."""

    def test_the_shipped_render_settings_boot(self):
        # Mirrors render.yaml exactly: staging + console.
        s = _settings(env="staging", sms_provider="console", demo_mode=False)
        assert s.env == "staging"
        assert s.sms_provider == "console"

    def test_render_yaml_does_not_pair_production_with_console(self):
        import pathlib

        import yaml
        spec = yaml.safe_load(
            (pathlib.Path(__file__).parent.parent / "render.yaml").read_text()
        )
        env_vars = {
            v["key"]: v.get("value")
            for v in spec["services"][0]["envVars"]
        }
        if env_vars.get("ENV") == "production":
            assert env_vars.get("SMS_PROVIDER") not in (None, "console"), (
                "render.yaml pairs ENV=production with console OTP; the "
                "service would crash-loop at boot"
            )

    def test_health_check_path_needs_no_database(self):
        import pathlib

        import yaml
        spec = yaml.safe_load(
            (pathlib.Path(__file__).parent.parent / "render.yaml").read_text()
        )
        # /healthz is deliberately DB-free; pointing the platform health check
        # at a DB-backed route turns a brief Postgres blip into a restart loop.
        assert spec["services"][0]["healthCheckPath"] == "/healthz"

    def test_migrations_run_once_per_deploy_not_per_worker(self):
        import pathlib

        import yaml
        spec = yaml.safe_load(
            (pathlib.Path(__file__).parent.parent / "render.yaml").read_text()
        )
        svc = spec["services"][0]
        assert "alembic upgrade head" in svc.get("preDeployCommand", "")
        assert "alembic" not in svc["startCommand"], (
            "migrating in the start command races every uvicorn worker"
        )
