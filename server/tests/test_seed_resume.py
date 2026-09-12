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
    monkeypatch.setattr(generate, "_unscored", lambda db: next(remaining))

    def flaky(db):
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
    monkeypatch.setattr(generate, "_unscored", lambda db: 500)
    monkeypatch.setattr(
        generate, "_score_once", lambda db: (_ for _ in ()).throw(_drop())
    )

    with pytest.raises(OperationalError):
        generate.score_pending(_Db())


def test_nothing_to_do_is_not_an_error(monkeypatch):
    monkeypatch.setattr(generate, "_unscored", lambda db: 0)
    monkeypatch.setattr(
        generate, "_score_once", lambda db: pytest.fail("must not score")
    )
    assert generate.score_pending(_Db()) == 0
