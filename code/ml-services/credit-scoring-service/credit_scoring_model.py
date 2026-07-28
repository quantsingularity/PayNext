import logging
import os
import sys

_SERVICE_DIR = os.path.dirname(os.path.abspath(__file__))
_ML_COMMON = os.path.join(_SERVICE_DIR, "..", "ml-common", "synthetic_transactions.csv")

import joblib
import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import classification_report, roc_auc_score
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger(__name__)


def train_credit_scoring_model(data_path: str = _ML_COMMON):
    """
    Train a RandomForestClassifier for credit scoring based on user transaction history.
    """
    if not os.path.isfile(data_path):
        raise FileNotFoundError(
            f"Transaction data not found at {data_path}. "
            "Run ml-common/data_generator.py first."
        )

    df = pd.read_csv(data_path)
    df["transaction_time"] = pd.to_datetime(df["transaction_time"])
    df = df.sort_values(by=["user_id", "transaction_time"])

    user_features = (
        df.groupby("user_id")
        .agg(
            total_transaction_amount=("transaction_amount", "sum"),
            avg_transaction_amount=("transaction_amount", "mean"),
            num_transactions=("transaction_amount", "count"),
            max_transaction_amount=("transaction_amount", "max"),
            min_transaction_amount=("transaction_amount", "min"),
            unique_merchants=("merchant", lambda x: x.nunique()),
            avg_daily_transactions=(
                "transaction_time",
                lambda x: x.dt.date.nunique() / ((x.max() - x.min()).days or 1),
            ),
            risk_score=("is_fraud", "sum"),
        )
        .reset_index()
    )

    user_features["credit_risk"] = (user_features["risk_score"] > 0).astype(int)

    feature_cols = [
        "total_transaction_amount",
        "avg_transaction_amount",
        "num_transactions",
        "max_transaction_amount",
        "min_transaction_amount",
        "unique_merchants",
        "avg_daily_transactions",
    ]

    X = user_features[feature_cols]
    y = user_features["credit_risk"]

    # Guard: stratify requires 2 classes
    stratify_arg = y if y.nunique() >= 2 else None

    scaler = StandardScaler()
    X_scaled = scaler.fit_transform(X)
    joblib.dump(scaler, os.path.join(_SERVICE_DIR, "credit_scoring_scaler.joblib"))

    X_scaled_df = pd.DataFrame(X_scaled, columns=feature_cols)
    X_train, X_test, y_train, y_test = train_test_split(
        X_scaled_df, y, test_size=0.3, random_state=42, stratify=stratify_arg
    )

    model = RandomForestClassifier(
        n_estimators=100, random_state=42, class_weight="balanced"
    )
    model.fit(X_train, y_train)

    y_pred = model.predict(X_test)
    y_proba = model.predict_proba(X_test)[:, 1]
    logger.info(
        "Credit Scoring Model Report:\n" + classification_report(y_test, y_pred)
    )
    logger.info(f"ROC AUC Score: {roc_auc_score(y_test, y_proba):.4f}")

    joblib.dump(model, os.path.join(_SERVICE_DIR, "credit_scoring_model.joblib"))
    joblib.dump(feature_cols, os.path.join(_SERVICE_DIR, "credit_scoring_features.joblib"))
    logger.info("Credit scoring model, scaler, and features saved successfully.")


if __name__ == "__main__":
    train_credit_scoring_model()
