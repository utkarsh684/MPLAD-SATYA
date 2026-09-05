"""Tests for eSAKSHI data structures (no DB needed)."""

from app.services.esakshi import EsakshiVerification, EsakshiWorkRecord


def test_esakshi_record_fields():
    record = EsakshiWorkRecord(
        esakshi_ref="ESK-MP-2026-1142",
        work_code="MP/2026/1142",
        title="Road Construction - Ward 12",
        category="road",
        sanctioned_amount_paise=156_000_000,
        sanction_date=None,
        status="in_progress",
        physical_progress_pct=65,
        implementing_agency="PWD Division 1",
        total_released_paise=78_000_000,
        total_pending_paise=78_000_000,
        installments_count=2,
    )
    assert record.found is True
    total = record.total_released_paise + record.total_pending_paise
    assert total == record.sanctioned_amount_paise


def test_esakshi_verification_match():
    v = EsakshiVerification(
        matches=True, amount_match=True, status_match=True,
        agency_match=True, discrepancies=[],
    )
    assert v.matches
    assert len(v.discrepancies) == 0


def test_esakshi_verification_mismatch():
    v = EsakshiVerification(
        matches=False, amount_match=False, status_match=True,
        agency_match=True, discrepancies=["Amount mismatch: local 100 vs eSAKSHI 200"],
    )
    assert not v.matches
    assert len(v.discrepancies) == 1
