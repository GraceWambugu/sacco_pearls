from datetime import datetime, timezone
from typing import Optional

from sqlalchemy import (
    Boolean, CheckConstraint, DateTime, Float, ForeignKey, Index, Integer, JSON,
    String, UniqueConstraint, func,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .database import Base


class TimestampMixin:
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc),
        server_default=func.now(), nullable=False,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc), server_default=func.now(), nullable=False,
    )


class User(TimestampMixin, Base):
    __tablename__ = "users"
    __table_args__ = (CheckConstraint("role IN ('member','admin')", name="ck_users_role"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String(255))  # Argon2id hash, never the password
    full_name: Mapped[str] = mapped_column(String(120))
    role: Mapped[str] = mapped_column(String(20), default="member")
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    watchlists: Mapped[list["Watchlist"]] = relationship(
        back_populates="user", cascade="all, delete-orphan")
    reset_tokens: Mapped[list["PasswordResetToken"]] = relationship(
        back_populates="user", cascade="all, delete-orphan")


class PasswordResetToken(TimestampMixin, Base):
    __tablename__ = "password_reset_tokens"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    token_hash: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    consumed_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    user: Mapped["User"] = relationship(back_populates="reset_tokens")


class Sacco(TimestampMixin, Base):
    __tablename__ = "saccos"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(200), unique=True, index=True)
    county: Mapped[Optional[str]] = mapped_column(String(80), nullable=True, index=True)
    is_archived: Mapped[bool] = mapped_column(Boolean, default=False, server_default="false")

    aliases: Mapped[list["SaccoAlias"]] = relationship(
        back_populates="sacco", cascade="all, delete-orphan")
    metrics: Mapped[list["FinancialMetric"]] = relationship(
        back_populates="sacco", cascade="all, delete-orphan")
    scores: Mapped[list["PearlsScore"]] = relationship(
        back_populates="sacco", cascade="all, delete-orphan")


class SaccoAlias(TimestampMixin, Base):
    """Matching keys so one SACCO is recognised across differently-spelled reports."""
    __tablename__ = "sacco_aliases"

    id: Mapped[int] = mapped_column(primary_key=True)
    sacco_id: Mapped[int] = mapped_column(ForeignKey("saccos.id", ondelete="CASCADE"), index=True)
    alias: Mapped[str] = mapped_column(String(200), unique=True)

    sacco: Mapped["Sacco"] = relationship(back_populates="aliases")


class Report(TimestampMixin, Base):
    """Which SASRA annual report a number came from (provenance)."""
    __tablename__ = "reports"

    id: Mapped[int] = mapped_column(primary_key=True)
    report_year: Mapped[int] = mapped_column(Integer, unique=True)
    source_file: Mapped[Optional[str]] = mapped_column(String(200))
    units: Mapped[str] = mapped_column(String(40), default="Kshs billions")
    metrics: Mapped[list["FinancialMetric"]] = relationship(back_populates="report")


class FinancialMetric(TimestampMixin, Base):
    __tablename__ = "financial_metrics"
    __table_args__ = (
        UniqueConstraint("sacco_id", "data_year", name="uq_metric_sacco_year"),
        CheckConstraint("data_year BETWEEN 2000 AND 2100", name="ck_metric_year"),
        CheckConstraint("npl_ratio IS NULL OR npl_ratio >= 0", name="ck_metric_npl"),
        Index("ix_metrics_year", "data_year"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    sacco_id: Mapped[int] = mapped_column(ForeignKey("saccos.id", ondelete="CASCADE"))
    data_year: Mapped[int] = mapped_column(Integer)

    # growth appendix (Kshs billions)
    total_assets: Mapped[Optional[float]] = mapped_column(Float)
    total_deposits: Mapped[Optional[float]] = mapped_column(Float)
    gross_loans: Mapped[Optional[float]] = mapped_column(Float)
    total_income: Mapped[Optional[float]] = mapped_column(Float)

    # stability appendix (percent; negatives allowed for CCA/CCD/ICA)
    cca: Mapped[Optional[float]] = mapped_column(Float)
    ccd: Mapped[Optional[float]] = mapped_column(Float)
    ica: Mapped[Optional[float]] = mapped_column(Float)
    ext_borrowing: Mapped[Optional[float]] = mapped_column(Float)
    npl_ratio: Mapped[Optional[float]] = mapped_column(Float)
    liquidity_ratio: Mapped[Optional[float]] = mapped_column(Float)  # only in some reports

    data_stale: Mapped[bool] = mapped_column(Boolean, default=False)  # asterisked in SASRA table
    report_id: Mapped[Optional[int]] = mapped_column(
        ForeignKey("reports.id", ondelete="SET NULL"), nullable=True)
    source_page: Mapped[Optional[int]] = mapped_column(Integer)

    sacco: Mapped["Sacco"] = relationship(back_populates="metrics")
    report: Mapped[Optional["Report"]] = relationship(back_populates="metrics")


class PearlsScore(TimestampMixin, Base):
    """Filled in Phase 3 by the scoring engine."""
    __tablename__ = "pearls_scores"
    __table_args__ = (
        UniqueConstraint("sacco_id", "data_year", name="uq_score_sacco_year"),
        CheckConstraint("rating IS NULL OR rating IN ('Green','Amber','Red')", name="ck_score_rating"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    sacco_id: Mapped[int] = mapped_column(ForeignKey("saccos.id", ondelete="CASCADE"))
    data_year: Mapped[int] = mapped_column(Integer)
    p_score: Mapped[Optional[float]] = mapped_column(Float)
    e_score: Mapped[Optional[float]] = mapped_column(Float)
    a_score: Mapped[Optional[float]] = mapped_column(Float)
    r_score: Mapped[Optional[float]] = mapped_column(Float)
    l_score: Mapped[Optional[float]] = mapped_column(Float)
    s_score: Mapped[Optional[float]] = mapped_column(Float)
    composite_score: Mapped[Optional[float]] = mapped_column(Float)
    rating: Mapped[Optional[str]] = mapped_column(String(10))

    sacco: Mapped["Sacco"] = relationship(back_populates="scores")


class Watchlist(TimestampMixin, Base):
    __tablename__ = "watchlists"
    __table_args__ = (UniqueConstraint("user_id", "name", name="uq_watchlist_user_name"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    name: Mapped[str] = mapped_column(String(100))
    user: Mapped["User"] = relationship(back_populates="watchlists")
    items: Mapped[list["WatchlistItem"]] = relationship(
        back_populates="watchlist", cascade="all, delete-orphan")


class WatchlistItem(TimestampMixin, Base):
    __tablename__ = "watchlist_items"

    watchlist_id: Mapped[int] = mapped_column(
        ForeignKey("watchlists.id", ondelete="CASCADE"), primary_key=True)
    sacco_id: Mapped[int] = mapped_column(
        ForeignKey("saccos.id", ondelete="CASCADE"), primary_key=True)

    watchlist: Mapped["Watchlist"] = relationship(back_populates="items")
    sacco: Mapped["Sacco"] = relationship()


class AuditLog(TimestampMixin, Base):
    __tablename__ = "audit_logs"

    id: Mapped[int] = mapped_column(primary_key=True)
    entity_type: Mapped[str] = mapped_column(String(100), index=True)
    entity_key: Mapped[dict] = mapped_column(JSON)
    action: Mapped[str] = mapped_column(String(16), index=True)
    actor_user_id: Mapped[Optional[int]] = mapped_column(Integer, nullable=True, index=True)
    actor_email: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    before_data: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)
    after_data: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)


from . import audit as _audit
