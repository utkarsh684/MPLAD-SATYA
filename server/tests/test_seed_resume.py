"""Seeding must survive the link dropping, because it always does.

Scoring 2000 works is roughly 20,000 queries over a long-haul link to a
managed database. A drop partway through is the normal case, and a run that
needs a human to notice and restart it is a run that does not finish - this
seeder was restarted by hand four times before it was made to do it itself.
"""

import pytest
from sqlalchemy.exc import OperationalError

from app.seed import generate


def _drop() -> OperationalError:
    return OperationalError("SELECT 1", {}, Exception("Network is unreachable"))


class _Db:
    def __init__(self): self.rollbacks = 0
    def rollback(self): self.rollbacks += 1


@pytest.fixture(autouse=True)
def _no_waiting(monkeypatch):
    monkeypatch.setattr(generate.time, "sleep", lambda _s: None)


def test_a_dropped_connection_is_retried_not_fatal(monkeypatch):
    calls = []
    # 900 unscored, then 400, then 0: two drops, each after real progress.
    remaining = iter([900, 400, 400, 0, 0])
    monkeypatch.setattr(generate, "_needs_scoring", lambda db, **k: next(remaining))

    def flaky(db, **k):
        calls.append(1)
        if len(calls) < 3:
            raise _drop()

    monkeypatch.setattr(generate, "_score_once", flaky)

    db = _Db()
    scored = generate.score_pending(db)

    assert len(calls) == 3, "should have retried twice before succeeding"
    assert db.rollbacks == 2, "a poisoned session must be rolled back each time"
    # 900 unscored at the start, 0 at the end.
    assert scored == 900


def test_it_gives_up_rather_than_looping_forever(monkeypatch):
    monkeypatch.setattr(generate, "_needs_scoring", lambda db, **k: 500)
    monkeypatch.setattr(
        generate, "_score_once", lambda db, **k: (_ for _ in ()).throw(_drop())
    )

    with pytest.raises(OperationalError):
        generate.score_pending(_Db())


def test_nothing_to_do_is_not_an_error(monkeypatch):
    monkeypatch.setattr(generate, "_needs_scoring", lambda db, **k: 0)
    monkeypatch.setattr(
        generate, "_score_once", lambda db, **k: pytest.fail("must not score")
    )
    assert generate.score_pending(_Db()) == 0


def test_a_rescore_resumes_instead_of_restarting(monkeypatch):
    """A rescore marks its own assessments, so an interrupted one picks up.

    Without that marker every drop would send the pass back to work one, and
    a 2000-work rescore over a flaky link would never finish.
    """
    seen = {}

    def capture(db, *, rescore=False, trigger=""):
        seen["rescore"], seen["trigger"] = rescore, trigger

    monkeypatch.setattr(generate, "_needs_scoring", lambda db, **k: 3)
    monkeypatch.setattr(generate, "_score_once", capture)

    generate.score_pending(_Db(), rescore=True)
    assert seen["rescore"] is True
    assert seen["trigger"] == generate.RESCORE_TRIGGER

    generate.score_pending(_Db())
    assert seen["rescore"] is False
    assert seen["trigger"] != generate.RESCORE_TRIGGER
