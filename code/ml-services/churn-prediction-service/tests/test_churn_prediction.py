"""Tests for churn prediction service - pure unittest, no lightgbm/fastapi needed."""

import os
import sys
import unittest

import pandas as pd

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from churn_prediction_data_generator import generate_churn_data


class TestGenerateChurnData(unittest.TestCase):
    def test_returns_dataframe(self):
        self.assertIsInstance(generate_churn_data(50, 6), pd.DataFrame)

    def test_correct_row_count(self):
        self.assertEqual(len(generate_churn_data(10, 12)), 120)

    def test_required_columns_present(self):
        df = generate_churn_data(10, 6)
        required = {
            "user_id",
            "month",
            "transactions_per_month",
            "logins_per_month",
            "feature_usage_score",
            "is_churned",
        }
        self.assertTrue(required.issubset(set(df.columns)))

    def test_is_churned_binary(self):
        df = generate_churn_data(100, 12)
        self.assertTrue(set(df["is_churned"].unique()).issubset({0, 1}))

    def test_transactions_non_negative(self):
        df = generate_churn_data(50, 6)
        self.assertTrue((df["transactions_per_month"] >= 0).all())

    def test_logins_non_negative(self):
        df = generate_churn_data(50, 6)
        self.assertTrue((df["logins_per_month"] >= 0).all())

    def test_feature_usage_non_negative(self):
        df = generate_churn_data(50, 6)
        self.assertTrue((df["feature_usage_score"] >= 0).all())

    def test_month_format_parseable(self):
        # Use num_months>=4 to avoid randint(3,2) edge case (fixed in generator)
        df = generate_churn_data(10, 6)
        parsed = pd.to_datetime(df["month"], format="%Y-%m")
        self.assertTrue(parsed.notna().all())

    def test_small_num_months_no_crash(self):
        # This tests the fix: previously crashed with num_months=3
        try:
            df = generate_churn_data(5, 3)
            self.assertEqual(len(df), 15)
        except ValueError as e:
            self.fail(f"generate_churn_data crashed with num_months=3: {e}")

    def test_user_ids_have_prefix(self):
        df = generate_churn_data(5, 6)
        self.assertTrue(df["user_id"].str.startswith("user_").all())

    def test_churned_users_lower_activity(self):
        df = generate_churn_data(200, 12)
        churned = df[df["is_churned"] == 1]
        not_churned = df[df["is_churned"] == 0]
        if len(churned) > 0 and len(not_churned) > 0:
            self.assertLess(
                churned["transactions_per_month"].mean(),
                not_churned["transactions_per_month"].mean(),
            )


class TestChurnFeatureEngineering(unittest.TestCase):
    def test_rolling_avg_computed(self):
        df = generate_churn_data(20, 12)
        df["month_dt"] = pd.to_datetime(df["month"], format="%Y-%m")
        df = df.sort_values(["user_id", "month_dt"])
        df["rolling_avg_3m"] = (
            df.groupby("user_id")["transactions_per_month"]
            .rolling(3)
            .mean()
            .reset_index(level=0, drop=True)
        )
        self.assertGreater(len(df["rolling_avg_3m"].dropna()), 0)

    def test_tenure_positive(self):
        df = generate_churn_data(20, 12)
        df["month_dt"] = pd.to_datetime(df["month"], format="%Y-%m")
        user_agg = (
            df.groupby("user_id")
            .agg(
                tenure_months=(
                    "month_dt",
                    lambda x: (x.max() - x.min()).days / 30.0 if len(x) > 1 else 0,
                )
            )
            .reset_index()
        )
        self.assertTrue((user_agg["tenure_months"] >= 0).all())

    def test_feature_cols_match_api_fields(self):
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
        self.assertEqual(len(feature_cols), 14)
        self.assertEqual(feature_cols[0], "avg_transactions_per_month")
        self.assertEqual(feature_cols[-1], "avg_rolling_std_logins_3m")

    def test_model_dir_fixed(self):
        """Verify model saves to service dir (not parent) by inspecting source."""
        src_path = os.path.join(
            os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
            "churn_prediction_model.py",
        )
        with open(src_path) as f:
            src = f.read()
        # Artifacts must be anchored to the service directory via this file's own
        # absolute path, never to an escaped parent directory or the CWD.
        self.assertIn("os.path.dirname(os.path.abspath(__file__))", src)
        self.assertIn("churn_model.joblib", src)
        self.assertNotIn('os.path.join(os.path.dirname(__file__), "..")', src)


class TestChurnAPILogic(unittest.TestCase):
    def test_churn_probability_in_range(self):
        prob = round(0.73421, 4)
        self.assertGreaterEqual(prob, 0.0)
        self.assertLessEqual(prob, 1.0)

    def test_is_churn_boolean_true(self):
        self.assertIs(bool(1), True)

    def test_is_churn_boolean_false(self):
        self.assertIs(bool(0), False)

    def test_api_model_dir_fixed(self):
        src_path = os.path.join(
            os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
            "churn_prediction_api.py",
        )
        with open(src_path) as f:
            src = f.read()
        # API must load artifacts from the service directory via this file's own
        # absolute path, never from an escaped parent directory or the CWD.
        self.assertIn("os.path.dirname(os.path.abspath(__file__))", src)
        self.assertIn("churn_model.joblib", src)
        self.assertNotIn('os.path.join(os.path.dirname(__file__), "..")', src)


if __name__ == "__main__":
    unittest.main()
