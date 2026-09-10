"""All SQLAlchemy models.

One file on purpose: ~16 tables with heavy cross-references. Splitting into a
package buys nothing here and costs circular-import pain on the FK cycle
between `works` and `risk_assessments`.

Money is stored as integer PAISE everywhere (BigInteger). Never float.
Rs 15.60 Lakh == 156_000_000 paise.
"""

from __future__ import annotations

import uuid
from datetime import date, datetime

from geoalchemy2 import Geography
from sqlalchemy import (
    ARRAY,
    BigInteger,
    Boolean,
    CheckConstraint,
    Date,
    DateTime,
    Enum,
    Float,
    ForeignKey,
    Index,
    Integer,
    Numeric,
    SmallInteger,
    String,
    Text,
    UniqueConstraint,
    func,
)
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db import Base


def _uuid() -> uuid.UUID:
    return uuid.uuid4()


def _enum(*values: str, name: str) -> Enum:
    return Enum(*values, name=name, native_enum=True, validate_strings=True)


# --------------------------------------------------------------------------
# enumerations (kept as module constants so seed/tests reference one source)
# --------------------------------------------------------------------------
ROLES = ("mospi_admin", "district_officer", "mp", "field_officer", "citizen")
WORK_CATEGORIES = (
    "road", "drain", "water_supply", "school_building", "community_hall",
    "streetlight", "toilet_block", "pond", "health_centre", "other",
)
WORK_STATUSES = (
    "proposed", "recommended", "sanctioned", "in_progress",
    "completed", "held", "cancelled",
)
BANDS = ("green", "yellow", "red")
RECOMMENDED_ACTIONS = ("auto_approve", "manual_review", "hold_field_verify")
REASON_CATEGORIES = ("rule", "anomaly", "fraud", "inefficiency")
SEVERITIES = ("HIGH", "MEDIUM", "LOW")
SOURCES = ("official_record", "satellite", "citizen", "field")
SOURCE_STATUSES = ("available", "match", "mismatch", "inconclusive", "unavailable")
RELEASE_STATUSES = ("pending", "approved", "held", "partial", "rejected")
FV_STATUSES = ("assigned", "in_progress", "submitted", "cancelled")
MEASURE_METHODS = ("ar_arcore", "ar_arkit", "tape", "gps_walk", "odometer")
EVIDENCE_SOURCES = ("citizen", "field_officer", "contractor", "esakshi", "satellite")


class SyncMixin:
    """Global monotonic revision, stamped by a DB trigger (migration 0003).

    One integer cursor across every syncable table beats per-table timestamps:
    no clock skew, no equal-timestamp pagination hole.
    """

    rev: Mapped[int | None] = mapped_column(BigInteger, index=True)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


# --------------------------------------------------------------------------
# identity & org
# --------------------------------------------------------------------------
class District(Base):
    __tablename__ = "districts"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=_uuid)
    name: Mapped[str] = mapped_column(String(80), nullable=False)
    state: Mapped[str] = mapped_column(String(60), nullable=False)
    lgd_code: Mapped[str] = mapped_column(String(10), unique=True, nullable=False)
    centroid = mapped_column(Geography("POINT", srid=4326), nullable=False)

    __table_args__ = (Index("gix_districts_centroid", "centroid", postgresql_using="gist"),)


class User(Base, SyncMixin):
    __tablename__ = "users"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=_uuid)
    phone: Mapped[str] = mapped_column(String(16), unique=True, nullable=False)
    name: Mapped[str | None] = mapped_column(Text)
    role: Mapped[str] = mapped_column(_enum(*ROLES, name="role_t"), nullable=False)
    district_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("districts.id"))
    constituency: Mapped[str | None] = mapped_column(Text)
    employee_code: Mapped[str | None] = mapped_column(String(24))
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    # Bumping token_version revokes every token for this user in one UPDATE.
    token_version: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    last_location = mapped_column(Geography("POINT", srid=4326))
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )

    __table_args__ = (
        Index("ix_users_role_district", "role", "district_id"),
        Index("gix_users_last_location", "last_location", postgresql_using="gist"),
    )


class OtpChallenge(Base):
    __tablename__ = "otp_challenges"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=_uuid)
    phone: Mapped[str] = mapped_column(String(16), nullable=False)
    code_hash: Mapped[str] = mapped_column(String(120), nullable=False)
    attempts: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    consumed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    ip: Mapped[str | None] = mapped_column(String(45))
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )

    __table_args__ = (
        Index("ix_otp_phone_created", "phone", "created_at"),
        Index("ix_otp_ip_created", "ip", "created_at"),
    )


class PushToken(Base):
    __tablename__ = "push_tokens"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=_uuid)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), nullable=False)
    token: Mapped[str] = mapped_column(Text, unique=True, nullable=False)
    platform: Mapped[str] = mapped_column(_enum("android", "ios", name="platform_t"))
    device_id: Mapped[str] = mapped_column(String(64), nullable=False)
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )


# --------------------------------------------------------------------------
# core scheme data
# --------------------------------------------------------------------------
class Work(Base, SyncMixin):
    __tablename__ = "works"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=_uuid)
    work_code: Mapped[str] = mapped_column(String(24), unique=True, nullable=False)
    title: Mapped[str] = mapped_column(Text, nullable=False)
    description: Mapped[str | None] = mapped_column(Text)
    category: Mapped[str] = mapped_column(_enum(*WORK_CATEGORIES, name="work_cat_t"))
    district_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("districts.id"), nullable=False)
    ward: Mapped[str | None] = mapped_column(String(60))
    village: Mapped[str | None] = mapped_column(String(80))
    mp_user_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("users.id"))
    implementing_agency: Mapped[str | None] = mapped_column(String(120))

    sanctioned_amount_paise: Mapped[int] = mapped_column(BigInteger, nullable=False)
    estimated_amount_paise: Mapped[int | None] = mapped_column(BigInteger)
    sanctioned_qty: Mapped[float | None] = mapped_column(Numeric(12, 2))
    qty_unit: Mapped[str | None] = mapped_column(String(8))

    status: Mapped[str] = mapped_column(_enum(*WORK_STATUSES, name="work_status_t"))
    recommendation_date: Mapped[date | None] = mapped_column(Date)
    sanction_date: Mapped[date | None] = mapped_column(Date)
    expected_completion_date: Mapped[date | None] = mapped_column(Date)
    actual_completion_date: Mapped[date | None] = mapped_column(Date)
    physical_progress_pct: Mapped[int] = mapped_column(SmallInteger, default=0)

    location = mapped_column(Geography("POINT", srid=4326), nullable=False)
    esakshi_ref: Mapped[str | None] = mapped_column(String(40), unique=True)
    data_source: Mapped[str] = mapped_column(
        _enum("esakshi_sync", "manual", "seed", name="data_source_t"), default="seed"
    )

    # Denormalised pointer: without it the field dashboard needs a lateral join
    # per row to show score+band. use_alter breaks the FK cycle with
    # risk_assessments.work_id.
    current_assessment_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("risk_assessments.id", use_alter=True, name="fk_works_current_assessment")
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )

    district: Mapped[District] = relationship()
    current_assessment: Mapped[RiskAssessment | None] = relationship(
        foreign_keys=[current_assessment_id], post_update=True
    )

    __table_args__ = (
        Index("gix_works_location", "location", postgresql_using="gist"),
        Index("ix_works_district_status", "district_id", "status"),
        Index("ix_works_cat_district", "category", "district_id"),
        CheckConstraint("sanctioned_amount_paise >= 0", name="ck_works_amount_nonneg"),
    )


class FundRelease(Base, SyncMixin):
    __tablename__ = "fund_releases"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=_uuid)
    work_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("works.id"), nullable=False)
    installment_no: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    tranche_label: Mapped[str | None] = mapped_column(String(40))
    claimed_amount_paise: Mapped[int] = mapped_column(BigInteger, nullable=False)
    invoice_ref: Mapped[str | None] = mapped_column(String(40))
    requested_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    status: Mapped[str] = mapped_column(
        _enum(*RELEASE_STATUSES, name="release_status_t"), default="pending"
    )
    partial_pct: Mapped[int | None] = mapped_column(SmallInteger)

    # Which score gated this decision, and what the band was at that moment.
    gate_band: Mapped[str | None] = mapped_column(_enum(*BANDS, name="band_t"))
    assessment_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("risk_assessments.id"))

    decided_by_user_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("users.id"))
    decided_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    decision_note: Mapped[str | None] = mapped_column(Text)
    hold_reason_code: Mapped[str | None] = mapped_column(String(40))
    statutory_ref: Mapped[str | None] = mapped_column(String(60))
    pfms_ref: Mapped[str | None] = mapped_column(String(40))
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )

    work: Mapped[Work] = relationship()

    __table_args__ = (
        UniqueConstraint("work_id", "installment_no", name="uq_fr_work_installment"),
        Index("ix_fr_status_requested", "status", "requested_at"),
    )


class BenchmarkRate(Base):
    """CPWD DSR rates. `source` is rendered into the provenance line on screen 3."""

    __tablename__ = "benchmark_rates"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=_uuid)
    category: Mapped[str] = mapped_column(_enum(*WORK_CATEGORIES, name="work_cat_t2"))
    item_code: Mapped[str] = mapped_column(String(24), nullable=False)
    description: Mapped[str] = mapped_column(Text, nullable=False)
    unit: Mapped[str] = mapped_column(String(8), nullable=False)
    rate_paise: Mapped[int] = mapped_column(BigInteger, nullable=False)
    state: Mapped[str | None] = mapped_column(String(60))
    region_factor: Mapped[float] = mapped_column(Numeric(5, 3), default=1.0)
    source: Mapped[str] = mapped_column(Text, nullable=False)
    effective_from: Mapped[date] = mapped_column(Date, nullable=False)

    __table_args__ = (Index("ix_bench_cat_state", "category", "state", "effective_from"),)


# --------------------------------------------------------------------------
# evidence
# --------------------------------------------------------------------------
class Evidence(Base, SyncMixin):
    __tablename__ = "evidence"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=_uuid)
    work_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("works.id"), nullable=False)
    uploaded_by: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("users.id"))
    source: Mapped[str] = mapped_column(_enum(*EVIDENCE_SOURCES, name="ev_source_t"))
    kind: Mapped[str] = mapped_column(_enum("photo", "video", "document", name="ev_kind_t"))

    storage_key: Mapped[str] = mapped_column(Text, nullable=False)
    blurred_key: Mapped[str | None] = mapped_column(Text)
    thumb_key: Mapped[str | None] = mapped_column(Text)
    sha256: Mapped[str] = mapped_column(String(64), nullable=False)
    mime: Mapped[str | None] = mapped_column(String(40))
    bytes_len: Mapped[int | None] = mapped_column(Integer)
    width: Mapped[int | None] = mapped_column(Integer)
    height: Mapped[int | None] = mapped_column(Integer)

    captured_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    received_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    exif: Mapped[dict | None] = mapped_column(JSONB)
    gps = mapped_column(Geography("POINT", srid=4326))
    gps_accuracy_m: Mapped[float | None] = mapped_column(Float)
    gps_trust: Mapped[int | None] = mapped_column(SmallInteger)
    gps_flags: Mapped[list[str] | None] = mapped_column(ARRAY(Text))

    # 64-bit perceptual hash stored SIGNED, plus four 16-bit bands for the
    # pigeonhole near-duplicate lookup (see services/phash.py).
    phash: Mapped[int | None] = mapped_column(BigInteger)
    pb0: Mapped[int | None] = mapped_column(Integer)
    pb1: Mapped[int | None] = mapped_column(Integer)
    pb2: Mapped[int | None] = mapped_column(Integer)
    pb3: Mapped[int | None] = mapped_column(Integer)

    faces_blurred: Mapped[int] = mapped_column(SmallInteger, default=0)
    client_uuid: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), unique=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )

    __table_args__ = (
        Index("gix_evidence_gps", "gps", postgresql_using="gist"),
        Index("ix_ev_work", "work_id"),
        Index("ix_ev_pb0", "pb0"),
        Index("ix_ev_pb1", "pb1"),
        Index("ix_ev_pb2", "pb2"),
        Index("ix_ev_pb3", "pb3"),
    )


class UploadSession(Base):
    __tablename__ = "upload_sessions"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=_uuid)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), nullable=False)
    work_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("works.id"), nullable=False)
    filename: Mapped[str] = mapped_column(Text, nullable=False)
    total_bytes: Mapped[int] = mapped_column(BigInteger, nullable=False)
    chunk_size: Mapped[int] = mapped_column(Integer, nullable=False)
    chunk_count: Mapped[int] = mapped_column(Integer, nullable=False)
    received: Mapped[list[bool]] = mapped_column(ARRAY(Boolean), nullable=False)
    sha256_expected: Mapped[str] = mapped_column(String(64), nullable=False)
    tmp_dir: Mapped[str] = mapped_column(Text, nullable=False)
    source: Mapped[str] = mapped_column(_enum(*EVIDENCE_SOURCES, name="ev_source_t2"))
    evidence_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("evidence.id"))
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)


# --------------------------------------------------------------------------
# the four verification sources
# --------------------------------------------------------------------------
class VerificationSource(Base, SyncMixin):
    """One row per (work, source). This table *is* the 4-source screen."""

    __tablename__ = "verification_sources"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=_uuid)
    work_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("works.id"), nullable=False)
    source: Mapped[str] = mapped_column(_enum(*SOURCES, name="src_t"))
    status: Mapped[str] = mapped_column(_enum(*SOURCE_STATUSES, name="src_status_t"))
    confidence: Mapped[float | None] = mapped_column(Numeric(4, 3))
    # Server renders the card sentence; four sources have four sentence shapes
    # and duplicating that formatting across clients makes the demo fragile.
    headline: Mapped[str] = mapped_column(Text, nullable=False)
    observed_value: Mapped[float | None] = mapped_column(Numeric(12, 2))
    observed_unit: Mapped[str | None] = mapped_column(String(8))
    expected_value: Mapped[float | None] = mapped_column(Numeric(12, 2))
    report_count: Mapped[int] = mapped_column(Integer, default=0)
    detail: Mapped[dict | None] = mapped_column(JSONB)
    computed_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )

    __table_args__ = (UniqueConstraint("work_id", "source", name="uq_vs_work_source"),)


class FieldVerification(Base, SyncMixin):
    __tablename__ = "field_verifications"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=_uuid)
    work_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("works.id"), nullable=False)
    officer_user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), nullable=False)
    assigned_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    due_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    started_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    submitted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    status: Mapped[str] = mapped_column(
        _enum(*FV_STATUSES, name="fv_status_t"), default="assigned"
    )

    measured_value: Mapped[float | None] = mapped_column(Numeric(12, 2))
    measured_unit: Mapped[str | None] = mapped_column(String(8))
    measure_method: Mapped[str | None] = mapped_column(
        _enum(*MEASURE_METHODS, name="measure_method_t")
    )
    measure_accuracy_m: Mapped[float | None] = mapped_column(Float)
    observed_status: Mapped[str | None] = mapped_column(
        _enum(
            "not_started", "partial", "complete", "different_work", "inaccessible",
            name="observed_status_t",
        )
    )
    gps = mapped_column(Geography("POINT", srid=4326))
    notes: Mapped[str | None] = mapped_column(Text)
    evidence_ids: Mapped[list[uuid.UUID] | None] = mapped_column(ARRAY(UUID(as_uuid=True)))
    client_uuid: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), unique=True)

    __table_args__ = (
        Index("ix_fv_officer_status", "officer_user_id", "status", "due_at"),
        Index("ix_fv_work", "work_id"),
    )


class CitizenReport(Base, SyncMixin):
    __tablename__ = "citizen_reports"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=_uuid)
    work_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("works.id"))
    reporter_user_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("users.id"))
    # Pseudonymised under DPDP: we never render citizen identity in any report.
    phone_hash: Mapped[str] = mapped_column(String(64), nullable=False)
    category: Mapped[str] = mapped_column(
        _enum(
            "not_started", "incomplete", "poor_quality", "ghost_work",
            "wrong_location", "other", name="cr_category_t",
        )
    )
    verdict: Mapped[str] = mapped_column(
        _enum("exists", "not_found", "partial", "different", name="cr_verdict_t")
    )
    description: Mapped[str | None] = mapped_column(Text)
    gps = mapped_column(Geography("POINT", srid=4326))
    evidence_ids: Mapped[list[uuid.UUID] | None] = mapped_column(ARRAY(UUID(as_uuid=True)))
    credibility_weight: Mapped[float] = mapped_column(Numeric(4, 3), default=1.0)
    status: Mapped[str] = mapped_column(
        _enum("new", "triaged", "verified", "rejected", name="cr_status_t"), default="new"
    )
    client_uuid: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), unique=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )

    __table_args__ = (
        Index("gix_cr_gps", "gps", postgresql_using="gist"),
        Index("ix_cr_work_status", "work_id", "status"),
    )


class SatelliteObservation(Base):
    __tablename__ = "satellite_observations"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=_uuid)
    work_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("works.id"), nullable=False)
    capture_date: Mapped[date] = mapped_column(Date, nullable=False)
    provider: Mapped[str] = mapped_column(String(24), nullable=False)
    resolution_m: Mapped[float] = mapped_column(Float, nullable=False)
    ndvi_before: Mapped[float | None] = mapped_column(Float)
    ndvi_after: Mapped[float | None] = mapped_column(Float)
    # Physical column is still named ndbi_delta (renaming it needs a migration
    # we cannot rehearse without Postgres in this environment), but the value
    # is a visual brightness contrast, NOT a Normalized Difference Built-up
    # Index: Bhuvan's public WMS serves a rendered PNG with no SWIR or NIR
    # band. The attribute name is what the codebase reads, so it tells the
    # truth; see BhuvanAdapter._brightness_index.
    brightness_index: Mapped[float | None] = mapped_column("ndbi_delta", Float)
    status: Mapped[str] = mapped_column(_enum(*SOURCE_STATUSES, name="src_status_t2"))
    confidence: Mapped[float] = mapped_column(Numeric(4, 3), nullable=False)
    method: Mapped[str] = mapped_column(String(40), nullable=False)
    min_detectable_m2: Mapped[float | None] = mapped_column(Float)
    target_footprint_m2: Mapped[float | None] = mapped_column(Float)
    reason: Mapped[str] = mapped_column(Text, nullable=False)
    raw: Mapped[dict | None] = mapped_column(JSONB)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )

    __table_args__ = (
        UniqueConstraint("work_id", "capture_date", "provider", name="uq_sat_obs"),
    )


# --------------------------------------------------------------------------
# risk
# --------------------------------------------------------------------------
class RiskAssessment(Base, SyncMixin):
    """Immutable. A recompute inserts a new row and flips is_current."""

    __tablename__ = "risk_assessments"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=_uuid)
    work_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("works.id"), nullable=False)
    score: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    band: Mapped[str] = mapped_column(_enum(*BANDS, name="band_t2"), nullable=False)
    subscores: Mapped[dict] = mapped_column(JSONB, nullable=False)
    consistency_pct: Mapped[int | None] = mapped_column(SmallInteger)
    recommended_action: Mapped[str] = mapped_column(
        _enum(*RECOMMENDED_ACTIONS, name="rec_action_t")
    )

    # Reproducibility: a score computed today must be re-explainable in a year,
    # even after the rulebook changes underneath it.
    engine_version: Mapped[str] = mapped_column(String(24), nullable=False)
    rules_sha256: Mapped[str] = mapped_column(String(64), nullable=False)
    weights_sha256: Mapped[str] = mapped_column(String(64), nullable=False)
    inputs_snapshot: Mapped[dict] = mapped_column(JSONB, nullable=False)

    is_current: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    trigger_reason: Mapped[str] = mapped_column(String(40), default="manual")
    computed_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )

    reasons: Mapped[list[RiskReason]] = relationship(
        back_populates="assessment", cascade="all, delete-orphan", order_by="RiskReason.rank"
    )

    __table_args__ = (
        Index("ix_ra_work_current", "work_id", postgresql_where=(is_current.is_(True))),
        Index("ix_ra_band", "band", "computed_at"),
        CheckConstraint("score BETWEEN 0 AND 100", name="ck_ra_score_range"),
    )


class RiskReason(Base):
    """One row per list item on the risk-breakdown screen.

    `points` are apportioned so they sum EXACTLY to the parent score.
    `raw_points` keeps the pre-weight rule output for the audit trail.
    """

    __tablename__ = "risk_reasons"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=_uuid)
    assessment_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("risk_assessments.id", ondelete="CASCADE"), nullable=False
    )
    rank: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    code: Mapped[str] = mapped_column(String(40), nullable=False)
    category: Mapped[str] = mapped_column(_enum(*REASON_CATEGORIES, name="reason_cat_t"))
    severity: Mapped[str] = mapped_column(_enum(*SEVERITIES, name="severity_t"))
    title: Mapped[str] = mapped_column(Text, nullable=False)
    points: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    raw_points: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    explanation: Mapped[str] = mapped_column(Text, nullable=False)
    provenance: Mapped[str] = mapped_column(Text, nullable=False)
    refs: Mapped[dict | None] = mapped_column(JSONB)

    assessment: Mapped[RiskAssessment] = relationship(back_populates="reasons")

    __table_args__ = (UniqueConstraint("assessment_id", "rank", name="uq_rr_assessment_rank"),)


class Decision(Base, SyncMixin):
    """Human decision, kept deliberately separate from the AI recommendation.

    "Approval is an administrative action - SATYA provides evidence, not verdicts."
    Storing what the AI said *at the time* alongside what the officer chose is
    what makes that claim auditable rather than decorative.
    """

    __tablename__ = "decisions"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=_uuid)
    fund_release_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("fund_releases.id"), nullable=False
    )
    work_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("works.id"), nullable=False)
    officer_user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), nullable=False)
    action: Mapped[str] = mapped_column(
        _enum(
            "approve", "hold", "partial_release", "field_review", "re_audit",
            name="decision_action_t",
        )
    )
    justification: Mapped[str | None] = mapped_column(Text)
    remarks: Mapped[str | None] = mapped_column(Text)
    statutory_ref: Mapped[str | None] = mapped_column(String(60))
    signature_token: Mapped[str | None] = mapped_column(String(60))
    ai_score_at_decision: Mapped[int | None] = mapped_column(SmallInteger)
    ai_recommendation_at_decision: Mapped[str | None] = mapped_column(String(40))
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )

    __table_args__ = (Index("ix_decisions_release", "fund_release_id"),)


# --------------------------------------------------------------------------
# audit
# --------------------------------------------------------------------------
class AuditLog(Base):
    """Append-only hash chain.

    Migration 0002 REVOKEs UPDATE/DELETE from the app role and installs a
    BEFORE UPDATE OR DELETE trigger. Two layers, because one is not enough:
    the grant stops the application, the trigger stops a stray migration or a
    DBA with psql open.
    """

    __tablename__ = "audit_log"

    seq: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    ts: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    actor_user_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True))
    actor_role: Mapped[str | None] = mapped_column(String(24))
    action: Mapped[str] = mapped_column(String(48), nullable=False)
    entity_type: Mapped[str | None] = mapped_column(String(32))
    entity_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True))
    payload: Mapped[dict] = mapped_column(JSONB, nullable=False)
    leaf_hash: Mapped[str] = mapped_column(String(64), nullable=False)
    prev_hash: Mapped[str] = mapped_column(String(64), nullable=False)
    hash: Mapped[str] = mapped_column(String(64), nullable=False, unique=True)

    __table_args__ = (
        Index("ix_audit_entity", "entity_type", "entity_id"),
        Index("ix_audit_ts", "ts"),
    )


class SyncCursor(Base):
    __tablename__ = "sync_cursors"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=_uuid)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), nullable=False)
    device_id: Mapped[str] = mapped_column(String(64), nullable=False)
    last_rev: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    last_pull_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    client_version: Mapped[str | None] = mapped_column(String(24))

    __table_args__ = (UniqueConstraint("user_id", "device_id", name="uq_sync_user_device"),)


# Tables carrying a `rev` column, stamped by the trigger in migration 0003.
# Order matters for the sync pull response.
SYNCABLE_TABLES = [
    "works",
    "risk_assessments",
    "verification_sources",
    "field_verifications",
    "fund_releases",
    "evidence",
    "citizen_reports",
    "decisions",
    "users",
]

__all__ = [
    "AuditLog", "BenchmarkRate", "CitizenReport", "Decision", "District",
    "Evidence", "FieldVerification", "FundRelease", "OtpChallenge", "PushToken",
    "RiskAssessment", "RiskReason", "SatelliteObservation", "SyncCursor",
    "UploadSession", "User", "VerificationSource", "Work",
    "SYNCABLE_TABLES", "ROLES", "WORK_CATEGORIES", "WORK_STATUSES", "BANDS",
    "RECOMMENDED_ACTIONS", "REASON_CATEGORIES", "SEVERITIES", "SOURCES",
    "SOURCE_STATUSES", "RELEASE_STATUSES", "FV_STATUSES", "MEASURE_METHODS",
    "EVIDENCE_SOURCES",
]
