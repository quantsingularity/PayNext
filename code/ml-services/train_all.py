"""
train_all.py — Train all PayNext Python ML models in sequence.

By default each model is skipped when its artifact already exists, so this is safe and
fast to run on every startup. Pass --force (or set FORCE_TRAIN=1) to retrain everything.

Usage (from the ml-services/ root):
    python train_all.py            # train only models that are missing
    python train_all.py --force    # retrain all models
"""

import argparse
import logging
import os
import subprocess
import sys

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(message)s")
logger = logging.getLogger(__name__)

BASE = os.path.dirname(os.path.abspath(__file__))

# (display_name, directory, training_script, marker_artifact)
# marker_artifact is relative to the service directory. If it exists, the model is
# considered already trained and the service is skipped unless --force is given.
SERVICES = [
    (
        "fraud-detection-service",
        "fraud-detection-service",
        "fraud_detection_model.py",
        os.path.join("models", "fraud_model.joblib"),
    ),
    (
        "anomaly-detection-service",
        "anomaly-detection-service",
        "anomaly_detection_model.py",
        "anomaly_detector_model.joblib",
    ),
    (
        "churn-prediction-service",
        "churn-prediction-service",
        "churn_prediction_model.py",
        "churn_model.joblib",
    ),
    (
        "recommendation-service",
        "recommendation-service",
        "recommendation_model.py",
        "recommendation_kmeans_model.joblib",
    ),
    (
        "categorization-service",
        "categorization-service",
        "transaction_categorization_model.py",
        "category_model.joblib",
    ),
    (
        "credit-scoring-service",
        "credit-scoring-service",
        "credit_scoring_model.py",
        "credit_scoring_model.joblib",
    ),
]


def _force_default() -> bool:
    return os.environ.get("FORCE_TRAIN", "") not in ("", "0", "false", "False")


def main() -> int:
    parser = argparse.ArgumentParser(description="Train PayNext ML models.")
    parser.add_argument(
        "--force",
        action="store_true",
        default=_force_default(),
        help="Retrain even when a model artifact already exists.",
    )
    args = parser.parse_args()

    errors = []
    trained = 0
    skipped = 0
    for name, directory, script, marker in SERVICES:
        script_path = os.path.join(BASE, directory, script)
        if not os.path.isfile(script_path):
            logger.warning("Skipping %s — training script not found: %s", name, script_path)
            continue

        marker_path = os.path.join(BASE, directory, marker)
        if not args.force and os.path.isfile(marker_path):
            logger.info("Skipping %s — model already present (%s)", name, marker)
            skipped += 1
            continue

        logger.info("Training %s …", name)
        result = subprocess.run(
            [sys.executable, script_path],
            cwd=os.path.join(BASE, directory),
        )
        if result.returncode != 0:
            logger.error("FAILED: %s (exit %d)", name, result.returncode)
            errors.append(name)
        else:
            trained += 1
            logger.info("Done: %s", name)

    logger.info(
        "ML training summary: %d trained, %d skipped, %d failed",
        trained,
        skipped,
        len(errors),
    )
    if errors:
        logger.error("Failed services: %s", ", ".join(errors))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
