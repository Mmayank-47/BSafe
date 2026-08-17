"""
api.py
------
Optional REST wrapper around the safety_scoring pipeline, for teams that
want to serve fresh scores to a frontend instead of shipping a static
JSON file. Drop this file (and the safety_scoring/ package) into your
existing FastAPI app, or run standalone:

    pip install fastapi uvicorn
    uvicorn api:app --reload

Endpoints
---------
GET  /api/safety-scores            -> full JSON contract (see run_pipeline.py)
GET  /api/safety-scores/{place}    -> single place record
POST /api/safety-scores/refresh    -> re-run the pipeline against the CSV on disk
"""

from pathlib import Path
from functools import lru_cache

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from safety_scoring import load_crime_csv, compute_place_scores, attach_coordinates
from safety_scoring.geocoding import get_coordinates

DATA_PATH = Path(__file__).parent / "data" / "nagpur_crime_dataset_synthetic_1000.csv"

app = FastAPI(title="Nagpur Safety Score API", version="1.0.0")

# Loosen for local dev; restrict allow_origins in production.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


def _build_payload():
    df = load_crime_csv(str(DATA_PATH))
    scores = compute_place_scores(df)
    scores = attach_coordinates(scores, get_coordinates)
    mappable = scores[scores["lat"].notna()]

    places = []
    for _, row in mappable.iterrows():
        places.append({
            "place": row["Place"],
            "lat": round(float(row["lat"]), 5),
            "lon": round(float(row["lon"]), 5),
            "safety_score": float(row["safety_score"]),
            "risk_tier": row["risk_tier"],
            "kmeans_tier": row["kmeans_tier"],
            "total_incidents": int(row["total_incidents"]),
            "high_severity_count": int(row["high_severity_count"]),
            "top_crime_types": row["top_crime_types"],
        })
    return {
        "city": "Nagpur",
        "score_meaning": "0 = least safe, 100 = safest",
        "place_count": len(places),
        "places": places,
    }


@lru_cache(maxsize=1)
def _cached_payload():
    return _build_payload()


@app.get("/api/safety-scores")
def get_safety_scores():
    return _cached_payload()


@app.get("/api/safety-scores/{place}")
def get_place_score(place: str):
    data = _cached_payload()
    for p in data["places"]:
        if p["place"].lower() == place.lower():
            return p
    raise HTTPException(status_code=404, detail=f"No score found for place '{place}'")


@app.post("/api/safety-scores/refresh")
def refresh_scores():
    _cached_payload.cache_clear()
    return _cached_payload()
