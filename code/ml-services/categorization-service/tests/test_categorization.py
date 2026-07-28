"""Tests for transaction categorization - pure unittest."""

import os
import sys
import unittest

import pandas as pd

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from transaction_categorization_data_generator import generate_categorization_data


class TestGenerateCategorizationData(unittest.TestCase):
    def test_returns_dataframe(self):
        df = generate_categorization_data(100)
        self.assertIsInstance(df, pd.DataFrame)

    def test_correct_number_of_rows(self):
        df = generate_categorization_data(250)
        self.assertEqual(len(df), 250)

    def test_required_columns(self):
        df = generate_categorization_data(100)
        required = {
            "user_id",
            "transaction_amount",
            "transaction_time",
            "merchant",
            "description",
            "category",
        }
        self.assertTrue(required.issubset(set(df.columns)))

    def test_amount_positive(self):
        df = generate_categorization_data(200)
        self.assertTrue((df["transaction_amount"] > 0).all())

    def test_category_values_valid(self):
        df = generate_categorization_data(500)
        valid = {
            "Groceries",
            "Utilities",
            "Transport",
            "Entertainment",
            "Shopping",
            "Healthcare",
            "Rent/Mortgage",
            "Salary",
            "Transfer",
            "Other",
        }
        self.assertTrue(set(df["category"].unique()).issubset(valid))

    def test_merchant_not_empty(self):
        df = generate_categorization_data(100)
        self.assertTrue(df["merchant"].notna().all())
        self.assertTrue((df["merchant"] != "").all())

    def test_multiple_categories_present(self):
        df = generate_categorization_data(1000)
        self.assertGreaterEqual(df["category"].nunique(), 5)

    def test_text_features_usable(self):
        df = generate_categorization_data(200)
        df["text_features"] = df["merchant"] + " " + df["description"]
        self.assertTrue(df["text_features"].notna().all())


class TestCategorizationModelDir(unittest.TestCase):
    def test_model_dir_is_service_dir(self):
        import inspect

        import transaction_categorization_model as tcm

        src = inspect.getsource(tcm.train_categorization_model)
        self.assertNotIn(
            'model_dir = os.path.join(os.path.dirname(__file__), "..")', src
        )

    def test_vectorizer_fit_works(self):
        from sklearn.feature_extraction.text import TfidfVectorizer

        df = generate_categorization_data(300)
        df["text_features"] = df["merchant"] + " " + df["description"]
        vec = TfidfVectorizer(max_features=100, ngram_range=(1, 2))
        X = vec.fit_transform(df["text_features"])
        self.assertEqual(X.shape[0], len(df))


if __name__ == "__main__":
    unittest.main()
