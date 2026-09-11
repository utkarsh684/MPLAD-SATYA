"""Real HTTP through the ASGI app.

The rest of the suite tests pure functions. This file boots the actual
application - middleware, routing, dependencies, error handlers - and drives
requests through it, which is how the 500-instead-of-503 on a database outage
was found.

No Postgres is required, and that is the point: these assertions describe how
the API must behave when its database is unreachable.
"""

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.exc import OperationalError

from app.deps import get_db
from app.main import app


@pytest.fixture(scope="module")
def client():
    with TestClient(app, raise_server_exceptions=False) as c:
        yield c


@pytest.fixture
def db_down(client):
    """Force the database to look unreachable.

    These assertions used to rely on there simply being no Postgres around,
    which quietly inverted the moment a real DATABASE_URL was configured. The
    outage is now simulated, so the behaviour is pinned whether or not the
    developer has a database.
    """
    def _raise():
        raise OperationalError("SELECT 1", {}, Exception("connection refused"))

    app.dependency_overrides[get_db] = _raise
    yield client
    app.dependency_overrides.pop(get_db, None)


class TestServesWithoutDatabase:
    """Endpoints that must work even when Postgres is down."""

    def test_liveness_is_ok(self, client):
        r = client.get("/healthz")
        assert r.status_code == 200
        assert r.json()["status"] == "ok"

    def test_readiness_reports_degraded_rather_than_lying(self, client):
        r = client.get("/readyz")
        assert r.status_code == 200
        body = r.json()
        # Readiness must always answer, and must report the DB truthfully
        # either way - never claim ok while the database is unreachable.
        assert body["status"] in ("ok", "degraded")
        if body["status"] == "degraded":
            assert "error" in str(body.get("db", "")).lower()
        assert body["engine_version"]
        assert body["rules_sha256"]
        assert "demo_mode" in body, "the demo flag is never hidden"

    def test_rulebook_is_public_and_needs_no_database(self, client):
        r = client.get("/api/v1/admin/rules")
        assert r.status_code == 200
        body = r.json()
        assert body["rule_count"] == 33
        assert len(body["engine_rules_sha256"]) == 64


class TestDatabaseOutageIsNotAnInternalError:
    """A dependency being down is a 503, not a 500.

    Every DB-backed route returned INTERNAL_ERROR / 'An unexpected error
    occurred' with Postgres down. That is indistinguishable from a bug in our
    own code, tells an officer nothing, and gives the client nothing to act on.
    """

    def test_outage_returns_503_with_a_usable_code(self, db_down):
        r = db_down.post("/api/v1/auth/otp/request", json={"phone": "+919876543210"})
        assert r.status_code == 503
        error = r.json()["error"]
        assert error["code"] == "DATABASE_UNAVAILABLE"
        assert "temporary" in error["message"].lower()

    def test_outage_does_not_leak_connection_details(self, db_down):
        r = db_down.post("/api/v1/auth/otp/request", json={"phone": "+919876543210"})
        body = r.text.lower()
        for leak in ["psycopg", "5432", "password", "traceback", "sqlalchemy"]:
            assert leak not in body, f"connection detail leaked: {leak}"

    def test_every_error_carries_a_request_id(self, db_down):
        r = db_down.post("/api/v1/auth/otp/request", json={"phone": "+919876543210"})
        assert r.json()["error"]["request_id"]
        assert r.headers.get("X-Request-ID")


class TestAuthBoundaryHoldsWithoutDatabase:
    """RBAC must reject before anything touches the database.

    If an unauthenticated caller reached the DB layer they would get a 503,
    which would mean the auth check ran too late to be a real boundary.
    """

    @pytest.mark.parametrize("path", [
        "/api/v1/works",
        "/api/v1/me/dashboard",
        "/api/v1/me/verifications",
        "/api/v1/decisions/queue",
        "/api/v1/decisions/summary",
        "/api/v1/analytics/overview",
        "/api/v1/analytics/top-risk",
        "/api/v1/auth/me",
        "/api/v1/map/works",
    ])
    def test_protected_route_rejects_anonymous(self, client, path):
        r = client.get(path)
        assert r.status_code == 401, f"{path} did not require authentication"
        assert r.json()["error"]["code"] == "UNAUTHENTICATED"

    def test_a_bad_token_is_rejected_the_same_way(self, client):
        r = client.get("/api/v1/works", headers={"Authorization": "Bearer not-a-jwt"})
        assert r.status_code == 401


class TestContract:
    def test_openapi_documents_every_route(self, client):
        spec = client.get("/openapi.json").json()
        ops = [
            (m, p) for p, item in spec["paths"].items()
            for m in item if m in ("get", "post", "put", "patch", "delete")
        ]
        assert len(ops) == 40, f"expected 40 operations, found {len(ops)}"

    def test_every_operation_has_a_stable_id_for_client_generation(self, client):
        spec = client.get("/openapi.json").json()
        missing = [
            f"{m.upper()} {p}" for p, item in spec["paths"].items()
            for m, op in item.items()
            if m in ("get", "post", "put", "patch", "delete")
            and not op.get("operationId")
        ]
        assert not missing, f"routes without operationId: {missing}"

    def test_validation_error_uses_the_single_envelope(self, client):
        r = client.post("/api/v1/auth/otp/request", json={"phone": "x"})
        assert r.status_code == 422
        assert r.json()["error"]["code"] == "VALIDATION_ERROR"
        assert r.json()["error"]["field_errors"]

    def test_unknown_route_uses_the_same_envelope(self, client):
        r = client.get("/api/v1/does-not-exist")
        assert r.status_code == 404
        assert r.json()["error"]["code"] == "NOT_FOUND"
