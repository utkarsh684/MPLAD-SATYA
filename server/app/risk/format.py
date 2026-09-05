"""Explanation-string formatting.

Rule templates use `{field|filter}` placeholders. Filters exist because the
strings land verbatim on an officer's screen and in a statutory dossier, so
"Rs 1560000.0" is not acceptable where "Rs 15.60 L" is expected.
"""

from __future__ import annotations

import re
from typing import Any

_PLACEHOLDER = re.compile(r"\{([a-z0-9_]+)(?:\|([a-z]+))?\}", re.IGNORECASE)


def inr(paise: Any) -> str:
    """Indian lakh/crore grouping. Input is PAISE."""
    if paise is None:
        return "-"
    rupees = float(paise) / 100.0
    if rupees >= 1_00_00_000:
        return f"Rs {rupees / 1_00_00_000:.2f} Cr".replace(".00 Cr", " Cr")
    if rupees >= 1_00_000:
        return f"Rs {rupees / 1_00_000:.2f} L".replace(".00 L", " L")
    return f"Rs {rupees:,.0f}"


def times(v: Any) -> str:
    return "-" if v is None else f"{float(v):.1f}x"


def metres(v: Any) -> str:
    return "-" if v is None else f"{float(v):.0f} m"


def pct(v: Any) -> str:
    """Accepts either a 0-1 fraction or an already-scaled percentage."""
    if v is None:
        return "-"
    f = float(v)
    return f"{f * 100:.0f}%" if f <= 1.0 else f"{f:.0f}%"


def days(v: Any) -> str:
    return "-" if v is None else f"{int(v)} days"


def plain(v: Any) -> str:
    if v is None:
        return "-"
    if isinstance(v, float) and v.is_integer():
        return str(int(v))
    return str(v)


FILTERS = {
    "inr": inr,
    "x": times,
    "m": metres,
    "pct": pct,
    "days": days,
    None: plain,
}


def render(template: str, facts: dict) -> str:
    """Substitute `{field|filter}` placeholders from the facts dict."""

    def _sub(match: re.Match[str]) -> str:
        field, filt = match.group(1), match.group(2)
        fn = FILTERS.get(filt, plain)
        return fn(facts.get(field))

    return _PLACEHOLDER.sub(_sub, template)
