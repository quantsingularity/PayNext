"""
Fraud Detection Service - Core Business Logic
===============================================
Unified service combining:
  - ML inference (Random Forest + Isolation Forest + AutoEncoder) from the
    original Python ml_services/fraud service
  - Velocity, behavioural, geolocation, device, amount, and time-of-day
    rule-based scoring
  - MySQL persistence via SQLAlchemy (TransactionAnalysis, UserBehaviorProfile)
  - Redis caching for user behaviour profiles
  - Kafka event publishing on every analysis result
"""

import logging
import os
import time
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, List, Optional

import cache
import joblib
import kafka_producer
import numpy as np
import pandas as pd
from models import FraudStatus, RiskLevel, TransactionAnalysis, UserBehaviorProfile
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Score weighting constants
# ---------------------------------------------------------------------------
_VELOCITY_W = 0.15
_BEHAVIORAL_W = 0.15
_GEO_W = 0.10
_DEVICE_W = 0.10
_AMOUNT_W = 0.10
_TIME_W = 0.05
_ML_W = 1.0 - (_VELOCITY_W + _BEHAVIORAL_W + _GEO_W + _DEVICE_W + _AMOUNT_W + _TIME_W)

_THRESHOLD_HIGH = float(os.getenv("FRAUD_THRESHOLD_HIGH", "0.6"))
_THRESHOLD_CRITICAL = float(os.getenv("FRAUD_THRESHOLD_CRITICAL", "0.8"))

_HIGH_RISK_COUNTRIES = set(os.getenv("HIGH_RISK_COUNTRIES", "XX,YY,ZZ").split(","))

MODEL_DIR = os.path.join(os.path.dirname(__file__), "models")

# ---------------------------------------------------------------------------
# Global model state
# ---------------------------------------------------------------------------
_fraud_model_rf = None
_fraud_model_if = None
_fraud_model_ae = None
_fraud_scaler = None
_fraud_features = None
_location_encoder = None
_merchant_encoder = None
_txn_type_encoder = None
_user_id_encoder = None
_models_loaded = False


def load_models() -> bool:
    """Load all ML artefacts from MODEL_DIR. Returns True on success."""
    global _fraud_model_rf, _fraud_model_if, _fraud_model_ae
    global _fraud_scaler, _fraud_features
    global _location_encoder, _merchant_encoder, _txn_type_encoder, _user_id_encoder
    global _models_loaded

    try:
        # Lazy-import tensorflow only when models are available to avoid startup crash
        import tensorflow as tf

        _fraud_model_rf = joblib.load(os.path.join(MODEL_DIR, "fraud_model.joblib"))
        _fraud_model_if = joblib.load(
            os.path.join(MODEL_DIR, "fraud_isolation_forest_model.joblib")
        )
        _fraud_model_ae = tf.keras.models.load_model(
            os.path.join(MODEL_DIR, "fraud_autoencoder_model.keras")
        )
        _fraud_scaler = joblib.load(os.path.join(MODEL_DIR, "fraud_scaler.joblib"))
        _fraud_features = joblib.load(
            os.path.join(MODEL_DIR, "fraud_model_features.joblib")
        )
        _location_encoder = joblib.load(
            os.path.join(MODEL_DIR, "location_encoder.joblib")
        )
        _merchant_encoder = joblib.load(
            os.path.join(MODEL_DIR, "merchant_encoder.joblib")
        )
        _txn_type_encoder = joblib.load(
            os.path.join(MODEL_DIR, "transaction_type_encoder.joblib")
        )
        _user_id_encoder = joblib.load(
            os.path.join(MODEL_DIR, "user_id_encoder.joblib")
        )
        _models_loaded = True
        logger.info("All fraud detection ML models loaded from %s", MODEL_DIR)
        return True
    except FileNotFoundError as exc:
        logger.warning(
            "ML models not found (%s). Service will use rule-based scoring only.", exc
        )
        _models_loaded = False
        return False
    except Exception as exc:
        logger.error("Error loading ML models: %s", exc)
        _models_loaded = False
        return False


# ---------------------------------------------------------------------------
# ML inference
# ---------------------------------------------------------------------------


def _encode(encoder, value: Any) -> Any:
    try:
        return encoder.transform([str(value)])[0]
    except (ValueError, AttributeError):
        return -1


def _compute_ml_score(req: Dict[str, Any]) -> Dict[str, float]:
    """
    Run the three ML models and return component scores plus the weighted
    ensemble combined_score. Returns zeros when models are not loaded.
    """
    if not _models_loaded:
        return {"rf": 0.0, "if": 0.0, "ae": 0.0, "combined": 0.0}

    try:
        txn_time = req["transaction_time"]
        if isinstance(txn_time, str):
            txn_time = datetime.fromisoformat(txn_time)

        row = {
            "transaction_amount": req["transaction_amount"],
            "hour": txn_time.hour,
            "day_of_week": txn_time.weekday(),
            "month": txn_time.month,
            "day_of_month": txn_time.day,
            "location": _encode(_location_encoder, req.get("location", "")),
            "merchant": _encode(_merchant_encoder, req.get("merchant", "")),
            "transaction_type": _encode(
                _txn_type_encoder, req.get("transaction_type", "")
            ),
            "user_id": _encode(_user_id_encoder, req.get("user_id", "")),
            "time_since_last_txn": req.get("time_since_last_txn", 0.0),
            "user_avg_txn_amount_24h": req.get("user_avg_txn_amount_24h", 0.0),
            "user_txn_count_24h": req.get("user_txn_count_24h", 0),
            "user_avg_txn_amount_7d": req.get("user_avg_txn_amount_7d", 0.0),
            "user_txn_count_7d": req.get("user_txn_count_7d", 0),
        }
        df = pd.DataFrame([row])[_fraud_features]
        scaled = _fraud_scaler.transform(df)
        scaled_df = pd.DataFrame(scaled, columns=_fraud_features)

        rf_prob = float(_fraud_model_rf.predict_proba(scaled_df)[:, 1][0])
        if_raw = float(-_fraud_model_if.decision_function(scaled_df)[0])
        recon = _fraud_model_ae.predict(scaled_df, verbose=0)
        ae_mse = float(np.mean(np.power(scaled_df.values - recon, 2), axis=1)[0])

        # Normalise IF and AE scores to [0, 1] via sigmoid
        if_norm = 1.0 / (1.0 + np.exp(-if_raw))
        ae_norm = 1.0 / (1.0 + np.exp(-ae_mse))

        combined = rf_prob * 0.50 + if_norm * 0.25 + ae_norm * 0.25
        return {
            "rf": round(rf_prob, 4),
            "if": round(float(if_raw), 4),
            "ae": round(float(ae_mse), 4),
            "combined": round(float(combined), 4),
        }

    except Exception as exc:
        logger.error("ML inference error: %s", exc, exc_info=True)
        return {"rf": 0.0, "if": 0.0, "ae": 0.0, "combined": 0.0}


# ---------------------------------------------------------------------------
# Rule-based scoring
# ---------------------------------------------------------------------------


def _get_profile_dict(user_id: str, db: Session) -> Optional[Dict]:
    """Return cached profile dict or query DB then cache it."""
    key = cache.user_profile_key(user_id)
    cached = cache.get(key)
    if cached:
        return cached

    record = db.query(UserBehaviorProfile).filter_by(user_id=user_id).first()
    if record is None:
        return None

    profile = {
        "avg_transaction_amount": record.avg_transaction_amount,
        "max_transaction_amount": record.max_transaction_amount,
        "daily_transaction_count": record.daily_transaction_count,
        "typical_start_time": (
            str(record.typical_start_time) if record.typical_start_time else None
        ),
        "typical_end_time": (
            str(record.typical_end_time) if record.typical_end_time else None
        ),
        "frequent_countries": record.frequent_countries or [],
        "frequent_cities": record.frequent_cities or [],
        "known_devices": record.known_devices or [],
        "known_ip_addresses": record.known_ip_addresses or [],
        "frequent_categories": record.frequent_categories or [],
        "preferred_payment_methods": record.preferred_payment_methods or [],
    }
    cache.set(key, profile)
    return profile


def _velocity_score(user_id: str, req: Dict, db: Session) -> float:
    try:
        now = datetime.now(timezone.utc).replace(tzinfo=None)
        one_hour_ago = now - timedelta(hours=1)
        one_day_ago = now - timedelta(days=1)

        count_1h = (
            db.query(TransactionAnalysis)
            .filter(
                TransactionAnalysis.user_id == user_id,
                TransactionAnalysis.created_at >= one_hour_ago,
            )
            .count()
        )
        count_24h = (
            db.query(TransactionAnalysis)
            .filter(
                TransactionAnalysis.user_id == user_id,
                TransactionAnalysis.created_at >= one_day_ago,
            )
            .count()
        )

        profile = _get_profile_dict(user_id, db)
        score = 0.0

        if profile and profile.get("daily_transaction_count"):
            daily_norm = profile["daily_transaction_count"]
            hourly_norm = daily_norm / 24.0
            if count_1h > hourly_norm * 3:
                score += 0.40
            elif count_1h > hourly_norm * 2:
                score += 0.20
            if count_24h > daily_norm * 2:
                score += 0.30
        else:
            if count_1h > 5:
                score += 0.40
            if count_24h > 20:
                score += 0.30

        return min(score, 1.0)
    except Exception as exc:
        logger.debug("velocity_score error: %s", exc)
        return 0.0


def _behavioral_score(user_id: str, req: Dict, db: Session) -> float:
    try:
        profile = _get_profile_dict(user_id, db)
        if not profile:
            return 0.3

        score = 0.0
        amount = req["transaction_amount"]

        avg = profile.get("avg_transaction_amount")
        if avg and avg > 0:
            ratio = amount / avg
            if ratio > 10:
                score += 0.40
            elif ratio > 5:
                score += 0.20

        cats = profile.get("frequent_categories") or []
        if cats and req.get("merchant_category") and req["merchant_category"] not in cats:
            score += 0.20

        methods = profile.get("preferred_payment_methods") or []
        if methods and req.get("payment_method") and req["payment_method"] not in methods:
            score += 0.15

        start_t = profile.get("typical_start_time")
        end_t = profile.get("typical_end_time")
        if start_t and end_t and req.get("transaction_time"):
            txn_time = req["transaction_time"]
            if isinstance(txn_time, str):
                txn_time = datetime.fromisoformat(txn_time)
            cur_time = txn_time.time()
            from datetime import time as dtime

            def _parse_time(s):
                parts = str(s).split(":")
                return dtime(int(parts[0]), int(parts[1]))

            if cur_time < _parse_time(start_t) or cur_time > _parse_time(end_t):
                score += 0.25

        return min(score, 1.0)
    except Exception as exc:
        logger.debug("behavioral_score error: %s", exc)
        return 0.0


def _geolocation_score(user_id: str, req: Dict, db: Session) -> float:
    try:
        profile = _get_profile_dict(user_id, db)
        score = 0.0
        country = req.get("location_country") or req.get("location", "")

        if country in _HIGH_RISK_COUNTRIES:
            score += 0.40

        if profile:
            countries = profile.get("frequent_countries") or []
            if countries and country and country not in countries:
                score += 0.30
            cities = profile.get("frequent_cities") or []
            city = req.get("location_city", "")
            if cities and city and city not in cities:
                score += 0.20

        return min(score, 1.0)
    except Exception as exc:
        logger.debug("geolocation_score error: %s", exc)
        return 0.0


def _device_score(user_id: str, req: Dict, db: Session) -> float:
    try:
        profile = _get_profile_dict(user_id, db)
        if not profile:
            return 0.2

        score = 0.0
        devices = profile.get("known_devices") or []
        fp = req.get("device_fingerprint")
        if devices and fp and fp not in devices:
            score += 0.40

        ips = profile.get("known_ip_addresses") or []
        ip = req.get("ip_address")
        if ips and ip and ip not in ips:
            score += 0.30

        return min(score, 1.0)
    except Exception as exc:
        logger.debug("device_score error: %s", exc)
        return 0.0


def _amount_score(user_id: str, req: Dict, db: Session) -> float:
    try:
        amount = req["transaction_amount"]
        profile = _get_profile_dict(user_id, db)

        if not profile:
            if amount > 10000:
                return 0.8
            if amount > 5000:
                return 0.5
            if amount > 1000:
                return 0.2
            return 0.0

        max_amt = profile.get("max_transaction_amount")
        avg_amt = profile.get("avg_transaction_amount")

        if max_amt and amount > max_amt * 2:
            return 0.8
        if max_amt and amount > max_amt:
            return 0.5
        if avg_amt and avg_amt > 0 and amount > avg_amt * 5:
            return 0.4
        return 0.0
    except Exception as exc:
        logger.debug("amount_score error: %s", exc)
        return 0.0


def _time_of_day_score(req: Dict) -> float:
    try:
        txn_time = req.get("transaction_time")
        if not txn_time:
            return 0.0
        if isinstance(txn_time, str):
            txn_time = datetime.fromisoformat(txn_time)
        hour = txn_time.hour
        if hour >= 23 or hour < 6:
            return 0.30
        return 0.0
    except Exception:
        return 0.0


# ---------------------------------------------------------------------------
# Risk classification
# ---------------------------------------------------------------------------


def _determine_risk_level(score: float) -> RiskLevel:
    if score >= _THRESHOLD_CRITICAL:
        return RiskLevel.CRITICAL
    if score >= _THRESHOLD_HIGH:
        return RiskLevel.HIGH
    if score >= 0.3:
        return RiskLevel.MEDIUM
    return RiskLevel.LOW


def _generate_indicators(req: Dict, scores: Dict[str, float]) -> Dict[str, str]:
    indicators: Dict[str, str] = {}
    if scores.get("velocity", 0) > 0.5:
        indicators["HIGH_VELOCITY"] = "Transaction velocity exceeds normal patterns"
    if scores.get("behavioral", 0) > 0.5:
        indicators["BEHAVIORAL_ANOMALY"] = (
            "Transaction behaviour deviates from user patterns"
        )
    if scores.get("geolocation", 0) > 0.5:
        indicators["GEOLOCATION_RISK"] = (
            "Transaction from unusual or high-risk location"
        )
    if scores.get("device", 0) > 0.5:
        indicators["DEVICE_RISK"] = "Transaction from unknown device or IP address"
    if scores.get("amount", 0) > 0.5:
        indicators["AMOUNT_ANOMALY"] = "Transaction amount is unusually high"
    if scores.get("time_of_day", 0) > 0.2:
        indicators["TIME_RISK"] = "Transaction outside typical hours (23:00 – 06:00)"
    if scores.get("ml_combined", 0) > 0.5:
        indicators["ML_ANOMALY"] = "ML ensemble flagged this transaction"
    return indicators


# ---------------------------------------------------------------------------
# Public API (called by FastAPI routes)
# ---------------------------------------------------------------------------


def analyze_transaction(req: Dict[str, Any], db: Session) -> TransactionAnalysis:
    start_ms = int(time.time() * 1000)
    user_id = str(req["user_id"])

    ml = _compute_ml_score(req)
    vel = _velocity_score(user_id, req, db)
    beh = _behavioral_score(user_id, req, db)
    geo = _geolocation_score(user_id, req, db)
    dev = _device_score(user_id, req, db)
    amt = _amount_score(user_id, req, db)
    tod = _time_of_day_score(req)

    risk_score = (
        ml["combined"] * _ML_W
        + vel * _VELOCITY_W
        + beh * _BEHAVIORAL_W
        + geo * _GEO_W
        + dev * _DEVICE_W
        + amt * _AMOUNT_W
        + tod * _TIME_W
    )
    risk_level = _determine_risk_level(risk_score)

    component_scores = {
        "velocity": vel,
        "behavioral": beh,
        "geolocation": geo,
        "device": dev,
        "amount": amt,
        "time_of_day": tod,
        "ml_combined": ml["combined"],
    }
    indicators = _generate_indicators(req, component_scores)

    if risk_level == RiskLevel.CRITICAL:
        status = FraudStatus.DECLINED
    elif risk_level == RiskLevel.HIGH:
        status = FraudStatus.UNDER_REVIEW
    else:
        status = FraudStatus.APPROVED

    analysis = TransactionAnalysis(
        transaction_id=req["transaction_id"],
        user_id=user_id,
        amount=req["transaction_amount"],
        currency=req.get("currency", "USD"),
        merchant_id=req.get("merchant_id"),
        merchant_category=req.get("merchant_category"),
        transaction_type=req.get("transaction_type", ""),
        payment_method=req.get("payment_method", ""),
        ip_address=req.get("ip_address"),
        device_fingerprint=req.get("device_fingerprint"),
        location_country=req.get("location_country") or req.get("location"),
        location_city=req.get("location_city"),
        location=req.get("location"),
        merchant=req.get("merchant"),
        risk_score=round(risk_score, 4),
        risk_level=risk_level,
        fraud_status=status,
        ml_score_rf=ml["rf"],
        ml_score_if=ml["if"],
        ml_score_ae=ml["ae"],
        ml_combined_score=ml["combined"],
        velocity_score=vel,
        behavioral_score=beh,
        geolocation_score=geo,
        device_score=dev,
        amount_score=amt,
        time_of_day_score=tod,
        fraud_indicators=indicators,
        ml_model_version="v2.0-unified",
        analysis_duration_ms=int(time.time() * 1000) - start_ms,
    )

    db.add(analysis)
    db.commit()
    db.refresh(analysis)

    cache.delete(cache.user_profile_key(user_id))

    kafka_producer.publish_analysis(
        {
            "transaction_id": analysis.transaction_id,
            "user_id": analysis.user_id,
            "risk_score": analysis.risk_score,
            "risk_level": analysis.risk_level.value,
            "fraud_status": analysis.fraud_status.value,
            "fraud_indicators": analysis.fraud_indicators,
            "analysis_duration_ms": analysis.analysis_duration_ms,
            "timestamp": datetime.now(timezone.utc).replace(tzinfo=None).isoformat(),
        }
    )

    logger.info(
        "Fraud analysis completed | txn=%s user=%s score=%.4f level=%s status=%s duration_ms=%d",
        analysis.transaction_id,
        user_id,
        risk_score,
        risk_level.value,
        status.value,
        analysis.analysis_duration_ms,
    )
    return analysis


def get_realtime_score(req: Dict[str, Any], db: Session) -> Dict[str, Any]:
    """Lightweight score without persisting — for pre-authorisation checks."""
    user_id = str(req["user_id"])
    ml = _compute_ml_score(req)
    vel = _velocity_score(user_id, req, db)
    beh = _behavioral_score(user_id, req, db)
    geo = _geolocation_score(user_id, req, db)
    dev = _device_score(user_id, req, db)
    amt = _amount_score(user_id, req, db)
    tod = _time_of_day_score(req)

    score = (
        ml["combined"] * _ML_W
        + vel * _VELOCITY_W
        + beh * _BEHAVIORAL_W
        + geo * _GEO_W
        + dev * _DEVICE_W
        + amt * _AMOUNT_W
        + tod * _TIME_W
    )
    level = _determine_risk_level(score)
    return {
        "transaction_id": req.get("transaction_id"),
        "fraud_score": round(score, 4),
        "risk_level": level.value,
        "ml_score": ml["combined"],
        "timestamp": datetime.now(timezone.utc).replace(tzinfo=None).isoformat(),
    }


def get_user_behavior_profile(
    user_id: str, db: Session
) -> Optional[UserBehaviorProfile]:
    return db.query(UserBehaviorProfile).filter_by(user_id=user_id).first()


def get_fraud_stats(db: Session) -> Dict[str, Any]:
    cutoff = datetime.now(timezone.utc).replace(tzinfo=None) - timedelta(days=1)
    total = (
        db.query(TransactionAnalysis)
        .filter(TransactionAnalysis.created_at >= cutoff)
        .count()
    )
    fraud = (
        db.query(TransactionAnalysis)
        .filter(
            TransactionAnalysis.created_at >= cutoff,
            TransactionAnalysis.fraud_status == FraudStatus.DECLINED,
        )
        .count()
    )
    review = (
        db.query(TransactionAnalysis)
        .filter(
            TransactionAnalysis.created_at >= cutoff,
            TransactionAnalysis.fraud_status == FraudStatus.UNDER_REVIEW,
        )
        .count()
    )
    return {
        "total_transactions_24h": total,
        "fraud_transactions_24h": fraud,
        "under_review_transactions_24h": review,
        "fraud_rate_24h": round((fraud / total) * 100, 2) if total else 0.0,
        "models_loaded": _models_loaded,
        "ml_model_version": "v2.0-unified",
    }


def get_high_risk_transactions(limit: int, db: Session) -> List[TransactionAnalysis]:
    return (
        db.query(TransactionAnalysis)
        .filter(
            TransactionAnalysis.risk_level.in_([RiskLevel.HIGH, RiskLevel.CRITICAL])
        )
        .order_by(TransactionAnalysis.created_at.desc())
        .limit(limit)
        .all()
    )


def mark_transaction_fraud(
    transaction_id: str,
    is_fraud: bool,
    reviewed_by: str,
    notes: Optional[str],
    db: Session,
) -> Optional[TransactionAnalysis]:
    analysis = (
        db.query(TransactionAnalysis).filter_by(transaction_id=transaction_id).first()
    )
    if not analysis:
        return None
    analysis.fraud_status = (
        FraudStatus.DECLINED if is_fraud else FraudStatus.FALSE_POSITIVE
    )
    analysis.reviewed_by = reviewed_by
    analysis.reviewed_at = datetime.now(timezone.utc).replace(tzinfo=None)
    analysis.review_notes = notes
    db.commit()
    db.refresh(analysis)
    logger.info(
        "Transaction %s marked as %s by %s",
        transaction_id,
        "FRAUD" if is_fraud else "LEGITIMATE",
        reviewed_by,
    )
    return analysis


def retrain_model() -> None:
    """Trigger asynchronous model retraining (stub — wire to a task queue in production)."""
    logger.info("Model retrain requested — submitting background job")
    import threading

    from fraud_detection_model import train_fraud_model

    def _job():
        try:
            train_fraud_model()
            load_models()
            logger.info("Model retrain completed and models reloaded")
        except Exception as exc:
            logger.error("Model retrain failed: %s", exc)

    threading.Thread(target=_job, daemon=True).start()
