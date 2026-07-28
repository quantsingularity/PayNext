"""
Fraud Detection ML Model Trainer
=================================
Trains three complementary models on historical transaction data:
  1. RandomForestClassifier  - supervised classification
  2. IsolationForest         - unsupervised anomaly detection
  3. AutoEncoder (Keras)     - reconstruction-error anomaly detection
"""

import argparse
import logging
import os
import sys
from typing import Any, List

_SERVICE_DIR = os.path.dirname(os.path.abspath(__file__))
_ML_COMMON = os.path.join(_SERVICE_DIR, "..", "ml-common", "synthetic_transactions.csv")

import joblib
import numpy as np
import pandas as pd
from sklearn.ensemble import IsolationForest, RandomForestClassifier
from sklearn.metrics import classification_report, confusion_matrix, roc_auc_score
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder, StandardScaler
from tensorflow.keras.layers import Dense, Input
from tensorflow.keras.models import Model
from tensorflow.keras.optimizers import Adam

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger(__name__)

MODEL_DIR = os.path.join(_SERVICE_DIR, "models")

CATEGORICAL_COLS: List[str] = ["location", "merchant", "transaction_type", "user_id"]

FEATURES: List[str] = [
    "transaction_amount",
    "hour",
    "day_of_week",
    "month",
    "day_of_month",
    "location",
    "merchant",
    "transaction_type",
    "user_id",
    "time_since_last_txn",
    "user_avg_txn_amount_24h",
    "user_txn_count_24h",
    "user_avg_txn_amount_7d",
    "user_txn_count_7d",
]


def _build_features(df: pd.DataFrame) -> pd.DataFrame:
    """Feature engineering: temporal + rolling-window user aggregations."""
    df = df.copy()
    df["transaction_time"] = pd.to_datetime(df["transaction_time"])
    df = df.sort_values(by=["user_id", "transaction_time"]).reset_index(drop=True)

    df["hour"] = df["transaction_time"].dt.hour
    df["day_of_week"] = df["transaction_time"].dt.dayofweek
    df["month"] = df["transaction_time"].dt.month
    df["day_of_month"] = df["transaction_time"].dt.day

    df["time_since_last_txn"] = (
        df.groupby("user_id")["transaction_time"]
        .diff()
        .dt.total_seconds()
        .fillna(0)
    )

    # Rolling window features: use groupby + rolling with on= parameter.
    # Must set transaction_time as index within each group for time-based rolling.
    def _rolling_mean(group, col, window):
        return (
            group.set_index("transaction_time")[col]
            .rolling(window, min_periods=1)
            .mean()
            .values
        )

    def _rolling_count(group, col, window):
        return (
            group.set_index("transaction_time")[col]
            .rolling(window, min_periods=1)
            .count()
            .values
        )

    df["user_avg_txn_amount_24h"] = (
        df.groupby("user_id", group_keys=False)
        .apply(lambda g: pd.Series(_rolling_mean(g, "transaction_amount", "24h"), index=g.index))
    )
    df["user_txn_count_24h"] = (
        df.groupby("user_id", group_keys=False)
        .apply(lambda g: pd.Series(_rolling_count(g, "transaction_amount", "24h"), index=g.index))
    )
    df["user_avg_txn_amount_7d"] = (
        df.groupby("user_id", group_keys=False)
        .apply(lambda g: pd.Series(_rolling_mean(g, "transaction_amount", "7D"), index=g.index))
    )
    df["user_txn_count_7d"] = (
        df.groupby("user_id", group_keys=False)
        .apply(lambda g: pd.Series(_rolling_count(g, "transaction_amount", "7D"), index=g.index))
    )

    df.fillna(0, inplace=True)
    return df


def train_fraud_model(data_path: Any = None) -> None:
    """Full training pipeline. Saves all artefacts to MODEL_DIR."""
    os.makedirs(MODEL_DIR, exist_ok=True)

    if data_path is None:
        data_path = _ML_COMMON

    if not os.path.isfile(data_path):
        raise FileNotFoundError(
            f"Transaction data not found at {data_path}. "
            "Run ml-common/data_generator.py first."
        )

    logger.info("Loading data from %s", data_path)
    df = pd.read_csv(data_path)
    df = _build_features(df)

    for col in CATEGORICAL_COLS:
        if col in df.columns:
            le = LabelEncoder()
            df[col] = le.fit_transform(np.array(df[col]).astype(str))
            joblib.dump(le, os.path.join(MODEL_DIR, f"{col}_encoder.joblib"))
            logger.info("Saved encoder: %s_encoder.joblib", col)

    X = df[FEATURES]
    y = df["is_fraud"]

    scaler = StandardScaler()
    X_scaled = scaler.fit_transform(X)
    joblib.dump(scaler, os.path.join(MODEL_DIR, "fraud_scaler.joblib"))
    joblib.dump(FEATURES, os.path.join(MODEL_DIR, "fraud_model_features.joblib"))

    X_scaled_df = pd.DataFrame(X_scaled, columns=FEATURES)
    X_train, X_test, y_train, y_test = train_test_split(
        X_scaled_df, y, test_size=0.3, random_state=42, stratify=y
    )

    # 1. Random Forest
    logger.info("Training RandomForestClassifier ...")
    model_rf = RandomForestClassifier(
        n_estimators=200,
        random_state=42,
        class_weight="balanced",
        max_depth=10,
        min_samples_leaf=5,
    )
    model_rf.fit(X_train, y_train)
    y_pred_rf = model_rf.predict(X_test)
    y_proba_rf = model_rf.predict_proba(X_test)[:, 1]
    logger.info("RF Report:\n%s", classification_report(y_test, y_pred_rf))
    logger.info("RF ROC AUC: %.4f", roc_auc_score(y_test, y_proba_rf))
    joblib.dump(model_rf, os.path.join(MODEL_DIR, "fraud_model.joblib"))

    # 2. Isolation Forest
    logger.info("Training IsolationForest ...")
    contamination = float(y_train.sum()) / len(y_train)
    contamination = max(0.001, min(contamination, 0.5))  # guard clamp
    model_if = IsolationForest(random_state=42, contamination=contamination)
    model_if.fit(X_train)
    y_pred_if = np.where(model_if.predict(X_test) == -1, 1, 0)
    y_proba_if = -model_if.decision_function(X_test)
    logger.info("IF Report:\n%s", classification_report(y_test, y_pred_if))
    logger.info("IF ROC AUC: %.4f", roc_auc_score(y_test, y_proba_if))
    joblib.dump(model_if, os.path.join(MODEL_DIR, "fraud_isolation_forest_model.joblib"))

    # 3. AutoEncoder
    logger.info("Training AutoEncoder ...")
    input_dim = X_train.shape[1]
    encoding_dim = max(1, input_dim // 2)
    inp = Input(shape=(input_dim,))
    encoded = Dense(encoding_dim, activation="relu")(inp)
    decoded = Dense(input_dim, activation="sigmoid")(encoded)
    autoencoder = Model(inputs=inp, outputs=decoded)
    autoencoder.compile(optimizer=Adam(learning_rate=0.001), loss="mean_squared_error")
    autoencoder.fit(
        X_train,
        X_train,
        epochs=50,
        batch_size=32,
        shuffle=True,
        validation_split=0.1,
        verbose=0,
    )
    ae_path = os.path.join(MODEL_DIR, "fraud_autoencoder_model.keras")
    autoencoder.save(ae_path)
    logger.info("All models saved to %s", MODEL_DIR)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--data", default=None)
    args = parser.parse_args()
    train_fraud_model(data_path=args.data)
