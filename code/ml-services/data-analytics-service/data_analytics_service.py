import logging
import os
import sys
from typing import Any

_SERVICE_DIR = os.path.dirname(os.path.abspath(__file__))

import joblib
import pandas as pd
from sklearn.cluster import KMeans
from sklearn.preprocessing import StandardScaler

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger(__name__)

# pandas >= 2.2 uses 'ME' for month-end; older versions use 'M'
import pandas as _pd_version_check
_PANDAS_MAJOR = int(_pd_version_check.__version__.split(".")[0])
_PANDAS_MINOR = int(_pd_version_check.__version__.split(".")[1])
_MONTH_END_ALIAS = "ME" if (_PANDAS_MAJOR, _PANDAS_MINOR) >= (2, 2) else "M"


class DataAnalyticsService:

    def __init__(self) -> None:
        self.user_scaler = None
        self.kmeans_model = None
        self.segment_features = [
            "total_amount",
            "transaction_count",
            "avg_transaction_amount",
            "unique_merchants",
            "unique_transaction_types",
        ]

    def preprocess_transactions_for_segmentation(self, df: Any) -> Any:
        user_data = (
            df.groupby("user_id")
            .agg(
                total_amount=("amount", "sum"),
                transaction_count=("amount", "count"),
                avg_transaction_amount=("amount", "mean"),
                unique_merchants=("merchant", lambda x: x.nunique()),
                unique_transaction_types=("transaction_type", lambda x: x.nunique()),
            )
            .reset_index()
        )
        user_data = user_data.fillna(0)
        if self.user_scaler is None:
            self.user_scaler = StandardScaler()
            scaled_features = self.user_scaler.fit_transform(
                user_data[self.segment_features]
            )
        else:
            scaled_features = self.user_scaler.transform(
                user_data[self.segment_features]
            )
        scaled_df = pd.DataFrame(
            scaled_features, columns=self.segment_features, index=user_data.index
        )
        return (scaled_df, user_data[["user_id"]])

    def train_user_segmentation_model(
        self, df: Any, n_clusters: Any = 5, random_state: Any = 42
    ) -> Any:
        X_scaled, user_ids_df = self.preprocess_transactions_for_segmentation(df)
        self.kmeans_model = KMeans(
            n_clusters=n_clusters, random_state=random_state, n_init=10
        )
        self.kmeans_model.fit(X_scaled)
        user_segments = user_ids_df.copy()
        user_segments["segment"] = self.kmeans_model.labels_
        return user_segments

    def predict_user_segment(self, df: Any) -> Any:
        if self.kmeans_model is None or self.user_scaler is None:
            raise ValueError(
                "Model not trained. Please train the user segmentation model first."
            )
        X_scaled, user_ids_df = self.preprocess_transactions_for_segmentation(df)
        user_segments = user_ids_df.copy()
        user_segments["segment"] = self.kmeans_model.predict(X_scaled)
        return user_segments

    def analyze_transaction_trends(
        self, df: Any, time_granularity: Any = "daily"
    ) -> Any:
        df_copy = df.copy()
        df_copy["timestamp"] = pd.to_datetime(df_copy["timestamp"])
        df_copy = df_copy.set_index("timestamp")

        granularity_map = {
            "daily": "D",
            "weekly": "W",
            "monthly": _MONTH_END_ALIAS,
        }
        if time_granularity not in granularity_map:
            raise ValueError("time_granularity must be 'daily', 'weekly', or 'monthly'")

        resampled_df = df_copy.resample(granularity_map[time_granularity])
        trends = resampled_df.agg(
            total_transactions=("amount", "count"),
            total_amount_spent=("amount", "sum"),
            average_transaction_amount=("amount", "mean"),
        ).fillna(0)
        return trends

    def analyze_geospatial_patterns(self, df: Any) -> Any:
        location_summary = (
            df.groupby("location")
            .agg(
                total_transactions=("amount", "count"),
                total_amount_spent=("amount", "sum"),
                average_transaction_amount=("amount", "mean"),
            )
            .reset_index()
        )
        return location_summary.sort_values(by="total_amount_spent", ascending=False)

    def save_models(self, path: Any) -> Any:
        joblib.dump(
            {
                "user_scaler": self.user_scaler,
                "kmeans_model": self.kmeans_model,
                "segment_features": self.segment_features,
            },
            path,
        )

    @classmethod
    def load_models(cls: Any, path: Any) -> Any:
        data = joblib.load(path)
        service = cls()
        service.user_scaler = data["user_scaler"]
        service.kmeans_model = data["kmeans_model"]
        service.segment_features = data["segment_features"]
        return service


if __name__ == "__main__":
    # Add anomaly-detection-service to path for data generator
    _anomaly_dir = os.path.join(_SERVICE_DIR, "..", "anomaly-detection-service")
    if _anomaly_dir not in sys.path:
        sys.path.insert(0, _anomaly_dir)

    from anomaly_data_generator import generate_synthetic_transaction_data

    logger.info("Generating synthetic transaction data for analytics...")
    synthetic_transactions_df = generate_synthetic_transaction_data(
        num_transactions=100000, num_users=500, anomaly_ratio=0.0
    )
    logger.info("Synthetic data generated.")

    analytics_service = DataAnalyticsService()
    logger.info("\nTraining User Segmentation model...")
    user_segments_df = analytics_service.train_user_segmentation_model(
        synthetic_transactions_df, n_clusters=4
    )
    logger.info(f"Segment distribution:\n{user_segments_df['segment'].value_counts()}")

    model_out = os.path.join(_SERVICE_DIR, "analytics_models.joblib")
    analytics_service.save_models(model_out)
    logger.info(f"Analytics models saved to {model_out}")
