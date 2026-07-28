import logging
import os
import sys

_SERVICE_DIR = os.path.dirname(os.path.abspath(__file__))
if _SERVICE_DIR not in sys.path:
    sys.path.insert(0, _SERVICE_DIR)

from contextlib import asynccontextmanager

import joblib
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger(__name__)

category_model = None
category_vectorizer = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    global category_model, category_vectorizer
    try:
        category_model = joblib.load(os.path.join(_SERVICE_DIR, "category_model.joblib"))
        category_vectorizer = joblib.load(
            os.path.join(_SERVICE_DIR, "category_vectorizer.joblib")
        )
        logger.info("Categorization Model and Vectorizer loaded successfully.")
    except FileNotFoundError:
        logger.error(
            f"Categorization model or vectorizer file not found at {_SERVICE_DIR}. "
            "Please train the model first using transaction_categorization_model.py."
        )
    except Exception as e:
        logger.error(f"Error loading Categorization Model or Vectorizer: {e}")
    yield


app = FastAPI(
    title="Transaction Categorization API", version="1.0.0", lifespan=lifespan
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class TransactionCategorizationInput(BaseModel):
    merchant: str
    description: str


class CategorizationOutput(BaseModel):
    merchant: str
    description: str
    predicted_category: str
    prediction_probability: float


@app.get("/health")
async def health_check():
    return {"status": "ok", "model_loaded": category_model is not None}


@app.post("/categorize_transaction/", response_model=CategorizationOutput)
async def categorize_transaction(transaction: TransactionCategorizationInput):
    if category_model is None or category_vectorizer is None:
        raise HTTPException(
            status_code=503,
            detail="Categorization model not loaded. Please train the model.",
        )
    try:
        text_features = [f"{transaction.merchant} {transaction.description}"]
        text_features_vec = category_vectorizer.transform(text_features)
        prediction = category_model.predict(text_features_vec)[0]
        # max() gives the highest class probability (confidence of the chosen class)
        prediction_proba = float(category_model.predict_proba(text_features_vec).max())
        return CategorizationOutput(
            merchant=transaction.merchant,
            description=transaction.description,
            predicted_category=prediction,
            prediction_probability=round(prediction_proba, 4),
        )
    except Exception as e:
        logger.error(f"Error during categorization: {e}")
        raise HTTPException(status_code=500, detail=str(e))


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("categorization_api:app", host="0.0.0.0", port=9005, reload=False)
