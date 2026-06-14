"""
train_all.py — Train all PayNext Python ML models in sequence.
Run this once before starting the stack for the first time.

Usage (from the ml-services/ root):
    python train_all.py
"""

import logging
import os
import subprocess
import sys

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(message)s")
logger = logging.getLogger(__name__)

BASE = os.path.dirname(os.path.abspath(__file__))

# (display_name, directory, training_script)
SERVICES = [
    ("fraud-detection-service", "fraud-detection-service", "fraud_detection_model.py"),
    (
        "anomaly-detection-service",
        "anomaly-detection-service",
        "anomaly_detection_model.py",
    ),
    (
        "churn-prediction-service",
        "churn-prediction-service",
        "churn_prediction_model.py",
    ),
    ("recommendation-service", "recommendation-service", "recommendation_model.py"),
    (
        "categorization-service",
        "categorization-service",
        "transaction_categorization_model.py",
    ),
    ("credit-scoring-service", "credit-scoring-service", "credit_scoring_model.py"),
]

errors = []
for name, directory, script in SERVICES:
    script_path = os.path.join(BASE, directory, script)
    if not os.path.isfile(script_path):
        logger.warning("Skipping %s — training script not found: %s", name, script_path)
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
        logger.info("Done: %s", name)

if errors:
    logger.error("Failed services: %s", ", ".join(errors))
    sys.exit(1)
else:
    logger.info("All ML models trained successfully.")
