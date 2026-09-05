"""Route protection, checked declaratively.

A route missing from PUBLIC_ROUTES that has no auth dependency FAILS this test,
so a new unprotected endpoint cannot be merged silently. This is the cheapest
real security test in the codebase and it needs no database.
"""

import pytest

from app.deps import current_user
from app.main import app

# Everything reachable without a token, and why.
PUBLIC_ROUTES = {
    ("/healthz", "GET"),                    # liveness probe
    ("/readyz", "GET"),                     # readiness, no secrets
    # /docs, /redoc and /openapi.json are Starlette routes, not APIRoutes, so
    # they never appear in ROUTES and must not be listed here.
    ("/api/v1/auth/otp/request", "POST"),   # pre-auth by definition
    ("/api/v1/auth/otp/verify", "POST"),    # pre-auth by definition
    ("/api/v1/auth/refresh", "POST"),       # carries its own refresh token
    ("/api/v1/admin/rules", "GET"),         # deliberate transparency
    ("/api/v1/audit/verify", "GET"),        # deliberate transparency
    ("/api/v1/admin/demo/reset", "POST"),   # gated by DEMO_MODE + X-Demo-Key
}


def _dependency_names(route) -> set[str]:
    names = set()
    for dep in route.dependant.dependencies:
        if dep.call is not None:
            names.add(getattr(dep.call, "__name__", ""))
        for sub in dep.dependencies:
            if sub.call is not None:
                names.add(getattr(sub.call, "__name__", ""))
    for param in route.dependant.dependencies:
        names.add(getattr(param.call, "__name__", ""))
    return names


def _requires_auth(route) -> bool:
    if any(
        getattr(d.call, "__name__", "") in ("current_user", "_check")
        for d in route.dependant.dependencies
    ):
        return True
    # current_user injected as a parameter annotation
    for dep in route.dependant.dependencies:
        for sub in dep.dependencies:
            if sub.call is current_user:
                return True
    return current_user in _collect_calls(route.dependant)


def _collect_calls(dependant, seen=None):
    seen = seen if seen is not None else set()
    for dep in dependant.dependencies:
        if dep.call is not None:
            seen.add(dep.call)
        _collect_calls(dep, seen)
    return seen


ROUTES = [
    (r, method)
    for r in app.routes
    if hasattr(r, "methods") and hasattr(r, "dependant")
    for method in sorted(r.methods - {"HEAD", "OPTIONS"})
]


@pytest.mark.parametrize(
    "route,method", ROUTES, ids=[f"{m} {r.path}" for r, m in ROUTES]
)
def test_every_route_is_authenticated_or_explicitly_public(route, method):
    if (route.path, method) in PUBLIC_ROUTES:
        return
    assert _requires_auth(route), (
        f"{method} {route.path} has no auth dependency and is not listed in "
        f"PUBLIC_ROUTES. Add authentication, or add it to the list with a reason."
    )


def test_decision_endpoints_are_role_restricted():
    """Approving a fund release must never be reachable by a citizen."""
    from app.routers import decisions

    dep_names = [
        getattr(d.dependency, "__name__", "") for d in decisions.router.dependencies
    ]
    assert "_check" in dep_names, "decisions router lost its require_role guard"


def test_public_route_list_has_no_stale_entries():
    actual = {(r.path, m) for r, m in ROUTES}
    stale = PUBLIC_ROUTES - actual
    assert not stale, f"PUBLIC_ROUTES lists routes that no longer exist: {stale}"
