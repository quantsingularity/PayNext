import logging
import os
import sys

_SERVICE_DIR = os.path.dirname(os.path.abspath(__file__))
_CHURN_DATA = os.path.join(_SERVICE_DIR, "synthetic_churn_data.csv")

import joblib
import lightgbm as lgb
import pandas as pd
from sklearn.metrics import classification_report, confusion_matrix, roc_auc_score
from sklearn.model_selection import GridSearchCV, train_test_split
from sklearn.preprocessing import StandardScaler

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger(__name__)


def train_churn_model(data_path: str = _CHURN_DATA):
    """
    Train a LightGBM model to predict user churn using synthetic churn dataset.
    Saves the trained model, scaler, and feature list for inference.

    If the data CSV does not exist it is generated on-the-fly.
    """
    if not os.path.isfile(data_path):
        logger.warning(
            "Churn data CSV not found at %s — generating synthetic data first.", data_path
        )
        from churn_prediction_data_generator import generate_churn_data

        df_gen = generate_churn_data(num_users=5000, num_months=12)
        df_gen.to_csv(data_path, index=False)
        logger.info("Synthetic churn data saved to %s", data_path)

    df = pd.read_csv(data_path)
    df["month_dt"] = pd.to_datetime(df["month"], format="%Y-%m")
    df = df.sort_values(by=["user_id", "month_dt"])

    # Rolling features — fillna AFTER computing to keep NaN sentinel rows
    df["rolling_avg_transactions_3m"] = (
        df.groupby("user_id")["transactions_per_month"]
        .rolling(3)
        .mean()
        .reset_index(level=0, drop=True)
    )
    df["rolling_std_transactions_3m"] = (
        df.groupby("user_id")["transactions_per_month"]
        .rolling(3)
        .std()
        .reset_index(level=0, drop=True)
    )
    df["rolling_avg_logins_3m"] = (
        df.groupby("user_id")["logins_per_month"]
        .rolling(3)
        .mean()
        .reset_index(level=0, drop=True)
    )
    df["rolling_std_logins_3m"] = (
        df.groupby("user_id")["logins_per_month"]
        .rolling(3)
        .std()
        .reset_index(level=0, drop=True)
    )

    # Lag features (shift before fillna to keep the sentinel)
    df["prev_transactions_per_month"] = (
        df.groupby("user_id")["transactions_per_month"].shift(1)
    )
    df["prev_logins_per_month"] = (
        df.groupby("user_id")["logins_per_month"].shift(1)
    )
    df["prev_feature_usage_score"] = (
        df.groupby("user_id")["feature_usage_score"].shift(1)
    )

    # Fill NaN introduced by rolling/shift BEFORE computing diffs
    df.fillna(0, inplace=True)

    df["transactions_diff"] = (
        df["transactions_per_month"] - df["prev_transactions_per_month"]
    )
    df["logins_diff"] = df["logins_per_month"] - df["prev_logins_per_month"]
    df["feature_usage_diff"] = (
        df["feature_usage_score"] - df["prev_feature_usage_score"]
    )

    user_agg = (
        df.groupby("user_id")
        .agg(
            avg_transactions_per_month=("transactions_per_month", "mean"),
            avg_logins_per_month=("logins_per_month", "mean"),
            avg_feature_usage_score=("feature_usage_score", "mean"),
            total_months_active=("month", "count"),
            tenure_months=(
                "month_dt",
                lambda x: (x.max() - x.min()).days / 30.0 if len(x) > 1 else 0,
            ),
            ever_churned=("is_churned", "max"),
            avg_transactions_diff=("transactions_diff", "mean"),
            avg_logins_diff=("logins_diff", "mean"),
            avg_feature_usage_diff=("feature_usage_diff", "mean"),
            max_transactions_per_month=("transactions_per_month", "max"),
            min_transactions_per_month=("transactions_per_month", "min"),
            avg_rolling_avg_transactions_3m=("rolling_avg_transactions_3m", "mean"),
            avg_rolling_std_transactions_3m=("rolling_std_transactions_3m", "mean"),
            avg_rolling_avg_logins_3m=("rolling_avg_logins_3m", "mean"),
            avg_rolling_std_logins_3m=("rolling_std_logins_3m", "mean"),
        )
        .reset_index()
    )

    feature_cols = [
        "avg_transactions_per_month",
        "avg_logins_per_month",
        "avg_feature_usage_score",
        "total_months_active",
        "tenure_months",
        "avg_transactions_diff",
        "avg_logins_diff",
        "avg_feature_usage_diff",
        "max_transactions_per_month",
        "min_transactions_per_month",
        "avg_rolling_avg_transactions_3m",
        "avg_rolling_std_transactions_3m",
        "avg_rolling_avg_logins_3m",
        "avg_rolling_std_logins_3m",
    ]

    X = user_agg[feature_cols]
    y = user_agg["ever_churned"]

    # Guard: stratify requires at least 2 classes
    if y.nunique() < 2:
        logger.warning("Only one churn class in data — skipping stratify.")
        stratify_arg = None
    else:
        stratify_arg = y

    scaler = StandardScaler()
    X_scaled = scaler.fit_transform(X)
    joblib.dump(scaler, os.path.join(_SERVICE_DIR, "churn_scaler.joblib"))

    X_train, X_test, y_train, y_test = train_test_split(
        X_scaled, y, test_size=0.3, random_state=42, stratify=stratify_arg
    )

    param_grid = {
        "n_estimators": [100, 200, 300],
        "learning_rate": [0.01, 0.05, 0.1],
        "num_leaves": [20, 31, 40],
        "max_depth": [-1, 10, 20],
    }
    lgbm = lgb.LGBMClassifier(random_state=42, class_weight="balanced", verbose=-1)
    grid_search = GridSearchCV(
        lgbm, param_grid, cv=3, scoring="roc_auc", verbose=1, n_jobs=-1
    )
    grid_search.fit(X_train, y_train)
    model_lgb = grid_search.best_estimator_
    logger.info(f"Best LightGBM parameters: {grid_search.best_params_}")

    y_pred = model_lgb.predict(X_test)
    y_proba = model_lgb.predict_proba(X_test)[:, 1]
    logger.info(
        "LightGBM Churn Prediction Model Report:\n"
        + classification_report(y_test, y_pred)
    )
    logger.info(f"Confusion Matrix:\n{confusion_matrix(y_test, y_pred)}")
    logger.info(f"ROC AUC Score: {roc_auc_score(y_test, y_proba):.4f}")

    joblib.dump(model_lgb, os.path.join(_SERVICE_DIR, "churn_model.joblib"))
    joblib.dump(feature_cols, os.path.join(_SERVICE_DIR, "churn_model_features.joblib"))
    logger.info("Churn model, scaler, and feature list saved.")


if __name__ == "__main__":
    train_churn_model()
