import logging
import os
import sys

_SERVICE_DIR = os.path.dirname(os.path.abspath(__file__))
if _SERVICE_DIR not in sys.path:
    sys.path.insert(0, _SERVICE_DIR)

import joblib
import pandas as pd
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics import classification_report
from sklearn.model_selection import GridSearchCV, train_test_split
from sklearn.svm import SVC

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger(__name__)

_DEFAULT_DATA = os.path.join(_SERVICE_DIR, "synthetic_categorization_data.csv")


def train_categorization_model(data_path: str = _DEFAULT_DATA):
    """
    Train a TF-IDF + SVC categorization model.
    Auto-generates training data if the CSV is absent.
    """
    if not os.path.isfile(data_path):
        logger.warning(
            "Categorization data CSV not found at %s — generating now.", data_path
        )
        from transaction_categorization_data_generator import generate_categorization_data

        df_gen = generate_categorization_data(num_transactions=50000)
        df_gen.to_csv(data_path, index=False)
        logger.info("Synthetic categorization data saved to %s", data_path)

    df = pd.read_csv(data_path)

    # Validate required columns exist
    required = {"merchant", "description", "category"}
    missing = required - set(df.columns)
    if missing:
        raise ValueError(f"Training data is missing columns: {missing}")

    df["text_features"] = df["merchant"].astype(str) + " " + df["description"].astype(str)
    X = df["text_features"]
    y = df["category"]

    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.3, random_state=42, stratify=y
    )

    vectorizer = TfidfVectorizer(max_features=2000, ngram_range=(1, 2))
    X_train_vec = vectorizer.fit_transform(X_train)
    X_test_vec = vectorizer.transform(X_test)

    joblib.dump(vectorizer, os.path.join(_SERVICE_DIR, "category_vectorizer.joblib"))

    param_grid = {
        "C": [0.1, 1, 10],
        "gamma": ["scale", "auto"],
        "kernel": ["rbf", "linear"],
    }
    grid_search = GridSearchCV(
        SVC(random_state=42, probability=True),
        param_grid,
        refit=True,
        verbose=2,
        cv=3,
        n_jobs=-1,
    )
    grid_search.fit(X_train_vec, y_train)
    best_model = grid_search.best_estimator_
    logger.info(f"Best SVC parameters: {grid_search.best_params_}")

    y_pred = best_model.predict(X_test_vec)
    logger.info("\nTransaction Categorization Model Report (SVC):")
    logger.info(classification_report(y_test, y_pred))

    model_path = os.path.join(_SERVICE_DIR, "category_model.joblib")
    joblib.dump(best_model, model_path)
    logger.info(f"Transaction categorization model (SVC) trained and saved to {model_path}")


if __name__ == "__main__":
    train_categorization_model()
