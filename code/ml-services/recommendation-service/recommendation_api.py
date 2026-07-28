import logging
import os
import sys
from contextlib import asynccontextmanager
from typing import Any, Dict

_SERVICE_DIR = os.path.dirname(os.path.abspath(__file__))
if _SERVICE_DIR not in sys.path:
    sys.path.insert(0, _SERVICE_DIR)

import joblib
import pandas as pd
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger(__name__)

kmeans_model = None
scaler = None
user_spending_clusters = None
recommendation_features = None
cluster_characteristics: Dict = {}


def get_cluster_characteristics(df: Any) -> Any:
    if df is None:
        return {}
    cluster_cols = [col for col in df.columns if col not in ["user_id", "cluster"]]
    return df.groupby("cluster")[cluster_cols].mean().to_dict("index")


@asynccontextmanager
async def lifespan(app: FastAPI):
    global kmeans_model, scaler, user_spending_clusters, recommendation_features, cluster_characteristics
    try:
        kmeans_model = joblib.load(
            os.path.join(_SERVICE_DIR, "recommendation_kmeans_model.joblib")
        )
        scaler = joblib.load(os.path.join(_SERVICE_DIR, "recommendation_scaler.joblib"))
        user_spending_clusters = pd.read_csv(
            os.path.join(_SERVICE_DIR, "user_spending_clusters.csv")
        )
        recommendation_features = joblib.load(
            os.path.join(_SERVICE_DIR, "recommendation_features.joblib")
        )
        cluster_characteristics = get_cluster_characteristics(user_spending_clusters)
        logger.info("Recommendation Model, Scaler, and Data loaded successfully.")
    except FileNotFoundError as e:
        logger.error(
            f"Recommendation model or data file not found: {e}. "
            "Please train the model first using recommendation_model.py."
        )
    except Exception as e:
        logger.error(f"Error loading Recommendation Model components: {e}")
    yield


app = FastAPI(title="Recommendation API", version="1.0.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class UserRecommendationInput(BaseModel):
    user_id: str


class RecommendationOutput(BaseModel):
    user_id: str
    cluster: int
    recommendations: list


@app.get("/health")
async def health_check():
    return {"status": "ok", "model_loaded": kmeans_model is not None}


@app.post("/get_recommendations/", response_model=RecommendationOutput)
async def get_recommendations(user_input: UserRecommendationInput):
    if (
        kmeans_model is None
        or not cluster_characteristics
        or user_spending_clusters is None
    ):
        raise HTTPException(
            status_code=503,
            detail="Recommendation model or data not loaded. Please train the model.",
        )
    user_id = user_input.user_id
    user_data = user_spending_clusters[user_spending_clusters["user_id"] == user_id]
    if user_data.empty:
        raise HTTPException(
            status_code=404,
            detail="User not found or no spending data available for recommendations.",
        )
    user_cluster = int(user_data["cluster"].iloc[0])
    user_metrics = user_data.iloc[0]
    recommendations = []
    cluster_avg = cluster_characteristics.get(user_cluster, {})

    user_total_spent = user_metrics.get("total_spent", 0)
    cluster_avg_total_spent = cluster_avg.get("total_spent", 0)
    if cluster_avg_total_spent > 0 and user_total_spent > cluster_avg_total_spent * 1.5:
        recommendations.append(
            "Your spending is significantly higher than others in your segment. Consider reviewing your budget."
        )

    spending_cols = [col for col in user_metrics.index if "spent_on_" in col]
    if spending_cols:
        top_category = max(spending_cols, key=lambda col: user_metrics.get(col, 0))
        recommendations.append(
            f"Your highest spending is in '{top_category.replace('spent_on_', '')}'. "
            "Look for deals or cashback offers in this category."
        )

    user_num_transactions = user_metrics.get("num_transactions", 0)
    cluster_avg_num_transactions = cluster_avg.get("num_transactions", 0)
    if cluster_avg_num_transactions > 0 and user_num_transactions < cluster_avg_num_transactions * 0.7:
        recommendations.append(
            "You make fewer transactions than your peers. Are you taking full advantage of our payment features?"
        )

    if not recommendations:
        if user_cluster == 0:
            recommendations.append(
                "As a low-frequency user, explore our features for bill payments and subscriptions."
            )
        elif user_cluster in [1, 4]:
            recommendations.append(
                "You are a power user! Check out our premium features for even more benefits."
            )
        elif user_cluster == 2:
            recommendations.append(
                "You seem to be a frequent traveler. Look into our travel insurance and FX rate offers."
            )
        else:
            recommendations.append(
                "Review your monthly statements to find opportunities for savings."
            )

    return RecommendationOutput(
        user_id=user_id,
        cluster=user_cluster,
        recommendations=recommendations,
    )


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("recommendation_api:app", host="0.0.0.0", port=9004, reload=False)
