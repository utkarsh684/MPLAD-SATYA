"""Pydantic request/response models.

Rules that keep the generated Dart client sane:
  * every response field is required-and-non-null or explicitly Optional
  * collections are empty lists, never null
  * money travels as integer paise, with a server-rendered display string
  * all datetimes are tz-aware UTC
"""

from __future__ import annotations

import uuid
from datetime import date, datetime
from typing import Generic, Literal, TypeVar

from pydantic import BaseModel, ConfigDict, Field

from app.risk.format import inr

T = TypeVar("T")


class Page(BaseModel, Generic[T]):
    items: list[T] = Field(default_factory=list)
    next_cursor: str | None = None
    has_more: bool = False


class Money(BaseModel):
    paise: int
    display: str

    @classmethod
    def of(cls, paise: int | None) -> Money | None:
        return None if paise is None else cls(paise=paise, display=inr(paise))


# ---------------------------------------------------------------- auth
class OtpRequestIn(BaseModel):
    phone: str = Field(min_length=8, max_length=16, examples=["+919876543210"])


class OtpRequestOut(BaseModel):
    request_id: uuid.UUID
    expires_in: int
    resend_after: int
    # Present ONLY when SMS_PROVIDER=console (never in production, which
    # refuses to boot in that mode). Same code, same expiry, same attempt cap.
    debug_code: str | None = None


class DeviceIn(BaseModel):
    device_id: str = Field(max_length=64)
    platform: Literal["android", "ios"]
    fcm_token: str | None = None
    app_version: str | None = None


class OtpVerifyIn(BaseModel):
    request_id: uuid.UUID
    phone: str
    otp: str = Field(min_length=4, max_length=8)
    device: DeviceIn | None = None


class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: uuid.UUID
    name: str | None
    role: str
    phone_masked: str
    district_id: uuid.UUID | None
    district_name: str | None = None


class TokenPair(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "Bearer"
    expires_in: int
    user: UserOut


class RefreshIn(BaseModel):
    refresh_token: str


# ---------------------------------------------------------------- works
class WorkSummary(BaseModel):
    id: uuid.UUID
    work_code: str
    title: str
    category: str
    status: str
    ward: str | None
    district_name: str | None
    sanctioned_amount: Money
    risk_score: int | None
    risk_band: str | None
    band_label: str | None
    lat: float | None
    lon: float | None
    distance_m: float | None = None
    distance_label: str | None = None


class WorkDetail(WorkSummary):
    description: str | None
    implementing_agency: str | None
    sanctioned_qty: float | None
    qty_unit: str | None
    physical_progress_pct: int
    recommendation_date: date | None
    sanction_date: date | None
    expected_completion_date: date | None
    actual_completion_date: date | None
    esakshi_ref: str | None


# ---------------------------------------------------------------- risk
class RiskReasonOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    rank: int
    code: str
    category: str
    severity: str
    title: str
    points: int
    explanation: str
    provenance: str
    refs: dict = Field(default_factory=dict)


class RiskAssessmentOut(BaseModel):
    id: uuid.UUID
    work_id: uuid.UUID
    work_code: str
    score: int
    band: str
    band_label: str
    recommended_action: str
    action_label: str
    disclaimer: str
    consistency_pct: int | None
    subscores: dict[str, int]
    reasons: list[RiskReasonOut] = Field(default_factory=list)
    engine_version: str
    rules_sha256: str
    computed_at: datetime


class SourceCardOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    source: str
    status: str
    headline: str
    confidence: float | None
    observed_value: float | None
    expected_value: float | None
    observed_unit: str | None
    report_count: int


class VerificationOut(BaseModel):
    work: WorkSummary
    score: int | None
    band: str | None
    consistency_pct: int | None
    sources: list[SourceCardOut] = Field(default_factory=list)


# ---------------------------------------------------------------- dashboard
class FieldDashboardOut(BaseModel):
    assigned: int
    due_today: int
    high_risk: int
    # Server cannot know a phone's unsynced outbox depth; the client fills this.
    pending_sync: int | None = None


class AssignmentOut(BaseModel):
    id: uuid.UUID
    work: WorkSummary
    status: str
    assigned_at: datetime
    due_at: datetime


class FieldVerificationSubmitIn(BaseModel):
    client_uuid: uuid.UUID
    measured_value: float | None = None
    measured_unit: str | None = None
    measure_method: Literal["ar_arcore", "ar_arkit", "tape", "gps_walk", "odometer"] | None = None
    measure_accuracy_m: float | None = None
    observed_status: Literal[
        "not_started", "partial", "complete", "different_work", "inaccessible"
    ]
    lat: float | None = None
    lon: float | None = None
    notes: str | None = None
    evidence_ids: list[uuid.UUID] = Field(default_factory=list)


# ---------------------------------------------------------------- decisions
class FundReleaseOut(BaseModel):
    id: uuid.UUID
    work: WorkSummary
    installment_no: int
    tranche_label: str | None
    claimed_amount: Money
    status: str
    requested_at: datetime
    evidence_summary: str | None = None


class DecisionIn(BaseModel):
    action: Literal["approve", "hold", "partial_release", "field_review", "re_audit"]
    justification: str | None = None
    remarks: str | None = None
    statutory_ref: str | None = None
    partial_pct: int | None = Field(default=None, ge=1, le=99)


class DecisionOut(BaseModel):
    id: uuid.UUID
    fund_release_id: uuid.UUID
    action: str
    ai_score_at_decision: int | None
    ai_recommendation_at_decision: str | None
    created_at: datetime
    audit_seq: int | None = None


class DecisionSummaryOut(BaseModel):
    total_sanctioned: Money
    funds_held: Money
    approved_for_release: Money
    pending_review: Money
    counts: dict[str, int]


# ---------------------------------------------------------------- citizen
class CitizenReportIn(BaseModel):
    client_uuid: uuid.UUID
    work_id: uuid.UUID | None = None
    category: Literal[
        "not_started", "incomplete", "poor_quality", "ghost_work", "wrong_location", "other"
    ]
    verdict: Literal["exists", "not_found", "partial", "different"]
    description: str | None = None
    lat: float
    lon: float
    evidence_ids: list[uuid.UUID] = Field(default_factory=list)


class CitizenReportOut(BaseModel):
    id: uuid.UUID
    work_id: uuid.UUID | None
    status: str
    created_at: datetime


# ---------------------------------------------------------------- sync
class SyncPullOut(BaseModel):
    cursor: int
    has_more: bool
    server_time: datetime
    entities: dict[str, list[dict]] = Field(default_factory=dict)


class SyncOp(BaseModel):
    client_uuid: uuid.UUID
    type: str
    payload: dict


class SyncPushIn(BaseModel):
    device_id: str
    client_version: str | None = None
    ops: list[SyncOp] = Field(default_factory=list)


class SyncOpResult(BaseModel):
    client_uuid: uuid.UUID
    status: Literal["applied", "duplicate", "conflict", "rejected"]
    server_id: uuid.UUID | None = None
    error_code: str | None = None
    message: str | None = None


class SyncPushOut(BaseModel):
    cursor: int
    results: list[SyncOpResult] = Field(default_factory=list)


# ---------------------------------------------------------------- audit
class AuditVerifyOut(BaseModel):
    valid: bool
    checked: int
    first_seq: int | None = None
    last_seq: int | None = None
    head_hash: str | None = None
    broken_at_seq: int | None = None
    problem: str | None = None


# ---------------------------------------------------------------- evidence
class EvidenceOut(BaseModel):
    id: uuid.UUID
    work_id: uuid.UUID
    source: str
    kind: str
    storage_url: str
    sha256: str
    mime: str | None
    bytes_len: int | None
    width: int | None
    height: int | None
    captured_at: datetime | None
    gps_trust: int | None
    gps_flags: list[str] = Field(default_factory=list)
    faces_blurred: int
    phash_hex: str | None
    client_uuid: uuid.UUID | None
    created_at: datetime


# ---------------------------------------------------------------- esakshi
class EsakshiRecordOut(BaseModel):
    esakshi_ref: str | None
    work_code: str
    title: str
    category: str
    sanctioned_amount_paise: int
    sanction_date: str | None
    status: str
    physical_progress_pct: int
    implementing_agency: str | None
    total_released_paise: int
    total_pending_paise: int
    installments_count: int
    source: str = "esakshi"
    found: bool


class EsakshiVerifyOut(BaseModel):
    matches: bool
    amount_match: bool
    status_match: bool
    agency_match: bool
    discrepancies: list[str] = Field(default_factory=list)


# ---------------------------------------------------------------- satellite
class SatelliteResultOut(BaseModel):
    status: str
    confidence: float
    method: str
    resolution_m: float
    min_detectable_m: float
    target_dimension_m: float
    detectability_ratio: float
    reason: str
    ndbi_delta: float | None = None
