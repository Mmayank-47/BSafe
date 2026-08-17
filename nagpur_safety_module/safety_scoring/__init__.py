"""
safety_scoring
===============
A modular, drop-in pipeline that turns raw crime-incident records into a
place-level Safety Score (0-100, 100 = safest) plus a red-green map layer.

Typical usage
-------------
    from safety_scoring import load_crime_csv, compute_place_scores
    from safety_scoring.geocoding import get_coordinates
    from safety_scoring import scoring_model

    df = load_crime_csv("nagpur_crime_dataset_synthetic_1000.csv")
    scores = compute_place_scores(df)
    scores = scoring_model.attach_coordinates(scores, get_coordinates)
    scores.to_json("safety_scores.json", orient="records")

See README.md for the full pipeline, the map generator, and the
formula's exact math.
"""

from .data_loader import load_crime_csv
from .scoring_model import (
    add_incident_risk_score,
    compute_place_scores,
    attach_coordinates,
)

__all__ = [
    "load_crime_csv",
    "add_incident_risk_score",
    "compute_place_scores",
    "attach_coordinates",
]
