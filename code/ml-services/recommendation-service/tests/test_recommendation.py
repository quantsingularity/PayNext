"""Tests for recommendation service - pure unittest, no fastapi needed."""

import os
import sys
import unittest
from datetime import datetime, timedelta

import numpy as np
import pandas as pd

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def _make_df(n=300, users=20):
    np.random.seed(42)
    user_ids = [f"user_{i:04d}" for i in range(users)]
    merchants = ["Starbucks", "Amazon", "Walmart", "Shell", "Netflix"]
    txn_types = ["purchase", "withdrawal", "transfer"]
    rows = []
    for i in range(n):
        rows.append(
            {
                "user_id": user_ids[i % users],
                "transaction_amount": round(np.random.uniform(5, 500), 2),
                "transaction_time": datetime(2024, 1, 1) + timedelta(hours=i),
                "merchant": merchants[i % len(merchants)],
                "transaction_type": txn_types[i % len(txn_types)],
            }
        )
    return pd.DataFrame(rows)


class TestRecommendationFeatureEngineering(unittest.TestCase):
    def test_user_spending_aggregation(self):
        df = _make_df()
        df["transaction_time"] = pd.to_datetime(df["transaction_time"])
        user_spending = (
            df.groupby("user_id")
            .agg(
                total_spent=("transaction_amount", "sum"),
                num_transactions=("user_id", "count"),
            )
            .reset_index()
        )
        self.assertIn("user_id", user_spending.columns)
        self.assertIn("total_spent", user_spending.columns)
        self.assertGreater(len(user_spending), 0)

    def test_spending_by_type_pivot_columns(self):
        df = _make_df()
        spending_by_type = (
            df.groupby(["user_id", "transaction_type"])["transaction_amount"]
            .sum()
            .unstack(fill_value=0)
        )
        spending_by_type.columns = [f"spent_on_{c}" for c in spending_by_type.columns]
        self.assertTrue(
            all(c.startswith("spent_on_") for c in spending_by_type.columns)
        )

    def test_features_exclude_user_id(self):
        df = _make_df()
        user_spending = (
            df.groupby("user_id")
            .agg(total_spent=("transaction_amount", "sum"))
            .reset_index()
        )
        features = [c for c in user_spending.columns if c != "user_id"]
        self.assertNotIn("user_id", features)
        self.assertIn("total_spent", features)

    def test_kmeans_clustering(self):
        from sklearn.cluster import KMeans
        from sklearn.preprocessing import StandardScaler

        df = _make_df(200, 20)
        df["transaction_time"] = pd.to_datetime(df["transaction_time"])
        user_spending = (
            df.groupby("user_id")
            .agg(
                total_spent=("transaction_amount", "sum"),
                num_transactions=("user_id", "count"),
            )
            .reset_index()
        )
        X = StandardScaler().fit_transform(
            user_spending[["total_spent", "num_transactions"]]
        )
        labels = KMeans(n_clusters=3, random_state=42, n_init=10).fit_predict(X)
        self.assertEqual(len(labels), len(user_spending))
        self.assertTrue(set(labels).issubset({0, 1, 2}))

    def test_all_users_assigned_cluster(self):
        from sklearn.cluster import KMeans
        from sklearn.preprocessing import StandardScaler

        df = _make_df(300, 15)
        user_spending = (
            df.groupby("user_id")
            .agg(
                total_spent=("transaction_amount", "sum"),
                num_transactions=("user_id", "count"),
            )
            .reset_index()
        )
        X = StandardScaler().fit_transform(
            user_spending[["total_spent", "num_transactions"]]
        )
        user_spending["cluster"] = KMeans(
            n_clusters=4, random_state=42, n_init=10
        ).fit_predict(X)
        self.assertFalse(user_spending["cluster"].isna().any())


class TestRecommendationLogic(unittest.TestCase):
    def test_high_spender_recommendation(self):
        user_total = 1500.0
        cluster_avg = 500.0
        recs = []
        if user_total > cluster_avg * 1.5:
            recs.append("spending is significantly higher")
        self.assertGreater(len(recs), 0)

    def test_low_transaction_user_recommendation(self):
        user_num = 3
        cluster_avg = 10
        recs = []
        if user_num < cluster_avg * 0.7:
            recs.append("fewer transactions")
        self.assertGreater(len(recs), 0)

    def test_top_category_identified(self):
        spending = {
            "spent_on_purchase": 500.0,
            "spent_on_transfer": 100.0,
            "spent_on_withdrawal": 50.0,
        }
        top = max(spending, key=lambda k: spending[k])
        self.assertEqual(top, "spent_on_purchase")


class TestRecommendationSourceFixes(unittest.TestCase):
    """Verify model path fixes by inspecting source files directly."""

    def test_model_dir_fixed_in_trainer(self):
        src_path = os.path.join(
            os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
            "recommendation_model.py",
        )
        with open(src_path) as f:
            src = f.read()
        # Artifacts must be anchored to the service directory via this file's own
        # absolute path, never to an escaped parent directory or the CWD.
        self.assertIn("os.path.dirname(os.path.abspath(__file__))", src)
        self.assertIn("recommendation_kmeans_model.joblib", src)
        self.assertNotIn('os.path.join(base_dir, "..")', src)

    def test_api_model_dir_fixed(self):
        src_path = os.path.join(
            os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
            "recommendation_api.py",
        )
        with open(src_path) as f:
            src = f.read()
        # API must load artifacts from the service directory via this file's own
        # absolute path, never from an escaped parent directory or the CWD.
        self.assertIn("os.path.dirname(os.path.abspath(__file__))", src)
        self.assertIn("recommendation_kmeans_model.joblib", src)
        self.assertNotIn('os.path.join(os.path.dirname(__file__), "..")', src)


if __name__ == "__main__":
    unittest.main()
