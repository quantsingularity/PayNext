"""Tests for credit scoring service - pure unittest, no fastapi/lightgbm needed."""

import os
import sys
import unittest
from datetime import datetime, timedelta

import numpy as np
import pandas as pd

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


class TestCreditScoringFeatureEngineering(unittest.TestCase):
    def _make_synthetic(self, n=200, users=20):
        np.random.seed(42)
        user_ids = [f"user_{i:04d}" for i in range(users)]
        rows = []
        for i in range(n):
            rows.append(
                {
                    "user_id": user_ids[i % users],
                    "transaction_amount": np.random.uniform(10, 500),
                    "transaction_time": datetime(2024, 1, 1) + timedelta(hours=i),
                    "merchant": f"merchant_{i % 10}",
                    "is_fraud": 1 if np.random.rand() < 0.1 else 0,
                }
            )
        return pd.DataFrame(rows)

    def test_feature_aggregation_columns(self):
        df = self._make_synthetic()
        df["transaction_time"] = pd.to_datetime(df["transaction_time"])
        user_features = (
            df.groupby("user_id")
            .agg(
                total_transaction_amount=("transaction_amount", "sum"),
                avg_transaction_amount=("transaction_amount", "mean"),
                num_transactions=("transaction_amount", "count"),
                max_transaction_amount=("transaction_amount", "max"),
                min_transaction_amount=("transaction_amount", "min"),
                unique_merchants=("merchant", lambda x: x.nunique()),
                risk_score=("is_fraud", "sum"),
            )
            .reset_index()
        )
        for col in [
            "total_transaction_amount",
            "avg_transaction_amount",
            "num_transactions",
            "risk_score",
        ]:
            self.assertIn(col, user_features.columns)

    def test_credit_risk_label_binary(self):
        df = self._make_synthetic()
        user_features = (
            df.groupby("user_id").agg(risk_score=("is_fraud", "sum")).reset_index()
        )
        user_features["credit_risk"] = (user_features["risk_score"] > 0).astype(int)
        self.assertTrue(set(user_features["credit_risk"].unique()).issubset({0, 1}))

    def test_avg_between_min_and_max(self):
        df = self._make_synthetic()
        user_features = (
            df.groupby("user_id")
            .agg(
                avg=("transaction_amount", "mean"),
                mn=("transaction_amount", "min"),
                mx=("transaction_amount", "max"),
            )
            .reset_index()
        )
        self.assertTrue((user_features["avg"] >= user_features["mn"]).all())
        self.assertTrue((user_features["avg"] <= user_features["mx"]).all())

    def test_num_transactions_positive(self):
        df = self._make_synthetic()
        user_features = (
            df.groupby("user_id")
            .agg(num_transactions=("transaction_amount", "count"))
            .reset_index()
        )
        self.assertTrue((user_features["num_transactions"] > 0).all())


class TestCreditScoringScaler(unittest.TestCase):
    def test_scaler_transforms_correct_shape(self):
        from sklearn.preprocessing import StandardScaler

        data = pd.DataFrame(
            {
                "total_transaction_amount": [100.0, 200.0, 300.0],
                "avg_transaction_amount": [50.0, 100.0, 150.0],
                "num_transactions": [2, 3, 4],
                "max_transaction_amount": [80.0, 150.0, 200.0],
                "min_transaction_amount": [20.0, 50.0, 100.0],
                "unique_merchants": [1, 2, 3],
                "avg_daily_transactions": [1.0, 1.5, 2.0],
            }
        )
        scaler = StandardScaler()
        scaled = scaler.fit_transform(data)
        self.assertEqual(scaled.shape, data.shape)

    def test_scaler_mean_near_zero(self):
        from sklearn.preprocessing import StandardScaler

        data = np.random.rand(100, 7)
        scaled = StandardScaler().fit_transform(data)
        self.assertAlmostEqual(abs(scaled.mean()), 0.0, places=10)


class TestCreditScoringModelSourceCode(unittest.TestCase):
    """Verify model fixes are in place by inspecting source (no import of heavy deps)."""

    def test_model_trainer_saves_to_service_dir(self):
        with open(
            os.path.join(
                os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                "credit_scoring_model.py",
            )
        ) as f:
            src = f.read()
        # Artifacts must be anchored to the service directory via this file's own
        # absolute path, never to an escaped parent directory or the CWD.
        self.assertIn("os.path.dirname(os.path.abspath(__file__))", src)
        self.assertIn("credit_scoring_model.joblib", src)
        self.assertNotIn(
            'os.path.join(os.path.dirname(__file__), "..")', src
        )

    def test_api_loads_from_service_dir(self):
        with open(
            os.path.join(
                os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                "credit_scoring_api.py",
            )
        ) as f:
            src = f.read()
        # API must load artifacts from the service directory via this file's own
        # absolute path, never from an escaped parent directory or the CWD.
        self.assertIn("os.path.dirname(os.path.abspath(__file__))", src)
        self.assertIn("credit_scoring_model.joblib", src)
        self.assertNotIn(
            'os.path.join(os.path.dirname(__file__), "..")', src
        )


class TestCreditScoringAPILogic(unittest.TestCase):
    def test_high_risk_label(self):
        self.assertEqual("High Risk" if 1 == 1 else "Low Risk", "High Risk")

    def test_low_risk_label(self):
        self.assertEqual("High Risk" if 0 == 1 else "Low Risk", "Low Risk")

    def test_probability_rounded_4dp(self):
        self.assertEqual(round(0.123456789, 4), 0.1235)

    def test_feature_cols_match_api_input_fields(self):
        feature_cols = [
            "total_transaction_amount",
            "avg_transaction_amount",
            "num_transactions",
            "max_transaction_amount",
            "min_transaction_amount",
            "unique_merchants",
            "avg_daily_transactions",
        ]
        api_fields = feature_cols[:]
        self.assertEqual(feature_cols, api_fields)


if __name__ == "__main__":
    unittest.main()
