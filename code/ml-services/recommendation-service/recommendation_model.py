import logging
import os
import sys
from typing import Any

_SERVICE_DIR = os.path.dirname(os.path.abspath(__file__))
_ML_COMMON = os.path.join(_SERVICE_DIR, "..", "ml-common", "synthetic_transactions.csv")

import joblib
import pandas as pd
from sklearn.cluster import KMeans
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.preprocessing import StandardScaler

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger(__name__)

NUM_CLUSTERS = 7


def train_recommendation_model() -> Any:
    data_path = _ML_COMMON
    if not os.path.isfile(data_path):
        raise FileNotFoundError(
            f"Transaction data not found at {data_path}. "
            "Run ml-common/data_generator.py first."
        )

    df_transactions = pd.read_csv(data_path)
    if "transaction_time" in df_transactions.columns:
        df_transactions["transaction_time"] = pd.to_datetime(
            df_transactions["transaction_time"]
        )

    user_spending = (
        df_transactions.groupby("user_id")
        .agg(
            total_spent=("transaction_amount", "sum"),
            avg_transaction_amount=("transaction_amount", "mean"),
            num_transactions=("user_id", "count"),
            max_transaction_amount=("transaction_amount", "max"),
            min_transaction_amount=("transaction_amount", "min"),
            unique_merchants=("merchant", lambda x: x.nunique()),
            avg_daily_transactions=(
                "transaction_time",
                lambda x: (
                    x.dt.date.nunique() / max((x.max() - x.min()).days, 1)
                    if len(x) > 0
                    else 0
                ),
            ),
        )
        .reset_index()
    )

    spending_by_type = (
        df_transactions.groupby(["user_id", "transaction_type"])["transaction_amount"]
        .sum()
        .unstack(fill_value=0)
    )
    spending_by_type.columns = [f"spent_on_{col}" for col in spending_by_type.columns]
    user_spending = user_spending.merge(spending_by_type, on="user_id", how="left")
    user_spending.fillna(0, inplace=True)

    features = [col for col in user_spending.columns if col != "user_id"]
    X = user_spending[features]

    scaler = StandardScaler()
    X_scaled = scaler.fit_transform(X)
    joblib.dump(scaler, os.path.join(_SERVICE_DIR, "recommendation_scaler.joblib"))

    kmeans = KMeans(n_clusters=NUM_CLUSTERS, random_state=42, n_init=10)
    user_spending["cluster"] = kmeans.fit_predict(X_scaled)
    joblib.dump(kmeans, os.path.join(_SERVICE_DIR, "recommendation_kmeans_model.joblib"))
    logger.info(f"KMeans model trained with {NUM_CLUSTERS} clusters and saved.")

    user_spending.to_csv(
        os.path.join(_SERVICE_DIR, "user_spending_clusters.csv"), index=False
    )
    joblib.dump(features, os.path.join(_SERVICE_DIR, "recommendation_features.joblib"))

    df_transactions["item_description"] = (
        df_transactions["transaction_type"] + " " + df_transactions["merchant"]
    )
    tfidf_vectorizer = TfidfVectorizer(stop_words="english")
    tfidf_vectorizer.fit(df_transactions["item_description"])
    joblib.dump(
        tfidf_vectorizer,
        os.path.join(_SERVICE_DIR, "recommendation_tfidf_vectorizer.joblib"),
    )

    if "transaction_id" not in df_transactions.columns:
        df_transactions["transaction_id"] = range(len(df_transactions))
    df_transactions[
        ["transaction_id", "item_description", "transaction_type", "merchant"]
    ].to_csv(os.path.join(_SERVICE_DIR, "recommendation_items.csv"), index=False)
    logger.info("Recommendation model and all artefacts saved.")


if __name__ == "__main__":
    train_recommendation_model()
