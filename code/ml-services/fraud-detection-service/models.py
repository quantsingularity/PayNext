"""
SQLAlchemy ORM models for the PayNext Fraud Detection Service.
Mirrors the original Java JPA entities (TransactionAnalysis, UserBehaviorProfile)
so the Python service owns the same schema that was previously managed by Spring.
"""

import enum
from datetime import datetime, timezone

from sqlalchemy import (
    JSON,
    BigInteger,
    Column,
    DateTime,
    Enum,
    Float,
    Integer,
    String,
    Text,
)
from sqlalchemy.orm import DeclarativeBase


class Base(DeclarativeBase):
    pass


class RiskLevel(str, enum.Enum):
    LOW = "LOW"
    MEDIUM = "MEDIUM"
    HIGH = "HIGH"
    CRITICAL = "CRITICAL"


class FraudStatus(str, enum.Enum):
    PENDING = "PENDING"
    APPROVED = "APPROVED"
    DECLINED = "DECLINED"
    UNDER_REVIEW = "UNDER_REVIEW"
    FALSE_POSITIVE = "FALSE_POSITIVE"


class TransactionAnalysis(Base):
    """
    Persisted result of every fraud analysis run.
    Stores both ML-derived and rule-based component scores alongside
    the final risk decision so analysts can audit every scoring dimension.
    """

    __tablename__ = "transaction_analyses"

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    transaction_id = Column(String(255), nullable=False, unique=True, index=True)
    user_id = Column(String(255), nullable=False, index=True)

    # Transaction core fields
    amount = Column(Float, nullable=False)
    currency = Column(String(10), nullable=False, default="USD")
    merchant_id = Column(String(255))
    merchant_category = Column(String(255))
    transaction_type = Column(String(100), nullable=False)
    payment_method = Column(String(100), nullable=False)

    # Context fields
    ip_address = Column(String(64))
    device_fingerprint = Column(String(512))
    location_country = Column(String(100))
    location_city = Column(String(100))
    location = Column(String(255))
    merchant = Column(String(255))

    # Final risk
    risk_score = Column(Float, nullable=False)
    risk_level = Column(Enum(RiskLevel), nullable=False)
    fraud_status = Column(
        Enum(FraudStatus), nullable=False, default=FraudStatus.PENDING
    )

    # ML component scores (Random Forest / Isolation Forest / AutoEncoder)
    ml_score_rf = Column(Float)  # Random Forest fraud probability
    ml_score_if = Column(Float)  # Isolation Forest anomaly score
    ml_score_ae = Column(Float)  # AutoEncoder reconstruction error
    ml_combined_score = Column(Float)  # Weighted ML ensemble output

    # Rule-based component scores (ported from Java)
    velocity_score = Column(Float)
    behavioral_score = Column(Float)
    geolocation_score = Column(Float)
    device_score = Column(Float)
    amount_score = Column(Float)
    time_of_day_score = Column(Float)
    merchant_score = Column(Float)

    # Fraud indicator tags (JSON dict: name → description)
    fraud_indicators = Column(JSON, default=dict)

    # Metadata
    ml_model_version = Column(String(50), default="v2.0-unified")
    analysis_duration_ms = Column(BigInteger)

    # Analyst review fields
    reviewed_by = Column(String(255))
    reviewed_at = Column(DateTime)
    review_notes = Column(Text)

    # Timestamps
    created_at = Column(
        DateTime,
        nullable=False,
        default=lambda: datetime.now(timezone.utc).replace(tzinfo=None),
    )
    updated_at = Column(
        DateTime,
        nullable=False,
        default=lambda: datetime.now(timezone.utc).replace(tzinfo=None),
        onupdate=lambda: datetime.now(timezone.utc).replace(tzinfo=None),
    )


class UserBehaviorProfile(Base):
    """
    Historical behavioural profile per user, built as transactions are
    processed.  Used by the rule-based scoring engine for anomaly detection.
    Mirrors the Java UserBehaviorProfile JPA entity.
    """

    __tablename__ = "user_behavior_profiles"

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    user_id = Column(String(255), nullable=False, unique=True, index=True)

    # Amount statistics
    avg_transaction_amount = Column(Float)
    max_transaction_amount = Column(Float)
    min_transaction_amount = Column(Float)

    # Frequency statistics
    daily_transaction_count = Column(Integer)
    weekly_transaction_count = Column(Integer)
    monthly_transaction_count = Column(Integer)
    total_transactions = Column(BigInteger, default=0)

    # Time-of-day patterns (stored as "HH:MM" strings for portability)
    typical_start_time = Column(String(8))
    typical_end_time = Column(String(8))
    active_days_of_week = Column(JSON, default=list)  # list[int] 0=Mon … 6=Sun

    # Location patterns
    frequent_countries = Column(JSON, default=list)  # list[str] of ISO country codes
    frequent_cities = Column(JSON, default=list)

    # Device patterns
    known_devices = Column(JSON, default=list)  # device fingerprints
    known_ip_addresses = Column(JSON, default=list)

    # Merchant/category patterns
    frequent_merchants = Column(JSON, default=list)
    frequent_categories = Column(JSON, default=list)
    preferred_payment_methods = Column(JSON, default=list)

    # Aggregate risk indicators
    base_risk_score = Column(Float, default=0.0)
    velocity_risk_score = Column(Float, default=0.0)
    behavioral_risk_score = Column(Float, default=0.0)

    # Feedback counters
    fraud_incidents = Column(Integer, default=0)
    false_positives = Column(Integer, default=0)

    # Timestamps
    first_transaction_date = Column(DateTime)
    last_transaction_date = Column(DateTime)
    last_analysis_date = Column(DateTime)
    profile_created_at = Column(
        DateTime,
        nullable=False,
        default=lambda: datetime.now(timezone.utc).replace(tzinfo=None),
    )
    profile_updated_at = Column(
        DateTime,
        nullable=False,
        default=lambda: datetime.now(timezone.utc).replace(tzinfo=None),
        onupdate=lambda: datetime.now(timezone.utc).replace(tzinfo=None),
    )
