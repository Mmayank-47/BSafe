"""
scoring_model.py
-----------------
The actual "ML" pipeline:

  1. Feature engineering  -> turns every raw FIR record into a single
                              Incident Risk Score (IRS) using the weighted
                              formula in config.py.
  2. Aggregation           -> rolls IRS up to two place-level, comparable
                              (0-1) components: FREQUENCY and SEVERITY.
  3. Composite Risk Index  -> weighted blend of the two components.
  4. Safety Score          -> CRI inverted onto a 0-100 scale (100 = safest).
  5. KMeans clustering     -> unsupervised cross-check that groups places
                              into data-driven risk tiers (independent of
                              the fixed thresholds in config.py), used to
                              validate / label the rule-based tiers.

This module has no knowledge of Nagpur or of maps -- it is generic and
only needs a DataFrame with the columns listed in `REQUIRED_COLUMNS`, plus
a `place -> (lat, lon)` lookup supplied by the caller. That's what makes it
drop-in reusable for another city/dataset.
"""

from __future__ import annotations

import numpy as np
import pandas as pd
from sklearn.cluster import KMeans
from sklearn.preprocessing import MinMaxScaler

from . import config

REQUIRED_COLUMNS = [
    "Place", "Crime_Type", "Severity", "Year",
    "Weapon_Used", "Case_Status", "Reported_Within_24h",
]


# ---------------------------------------------------------------------------
# Step 1: per-record Incident Risk Score
# ---------------------------------------------------------------------------
def _severity_weight(sev: str) -> float:
    return config.SEVERITY_WEIGHTS.get(sev, config.DEFAULT_SEVERITY_WEIGHT)


def _crime_type_weight(ctype: str) -> float:
    return config.CRIME_TYPE_WEIGHTS.get(ctype, config.DEFAULT_CRIME_TYPE_WEIGHT)


def _recency_weight(year: int) -> float:
    years_ago = max(config.CURRENT_YEAR - int(year), 0)
    return float(np.exp(-config.RECENCY_DECAY_RATE * years_ago))


def _weapon_multiplier(weapon: str) -> float:
    if isinstance(weapon, str) and weapon.strip().lower() not in ("none", "nan", ""):
        return config.WEAPON_INVOLVED_MULTIPLIER
    return config.NO_WEAPON_MULTIPLIER


def _case_status_multiplier(status: str) -> float:
    return config.CASE_STATUS_MULTIPLIERS.get(status, config.DEFAULT_CASE_STATUS_MULTIPLIER)


def _report_multiplier(reported_within_24h: str) -> float:
    if isinstance(reported_within_24h, str) and reported_within_24h.strip().lower() == "no":
        return config.LATE_REPORT_MULTIPLIER
    return config.ON_TIME_REPORT_MULTIPLIER


def add_incident_risk_score(df: pd.DataFrame) -> pd.DataFrame:
    """Attach an `Incident_Risk_Score` column to a copy of df."""
    missing = [c for c in REQUIRED_COLUMNS if c not in df.columns]
    if missing:
        raise ValueError(f"Input data is missing required columns: {missing}")

    out = df.copy()
    out["_severity_w"] = out["Severity"].map(_severity_weight)
    out["_crime_type_w"] = out["Crime_Type"].map(_crime_type_weight)
    out["_recency_w"] = out["Year"].map(_recency_weight)
    out["_weapon_m"] = out["Weapon_Used"].map(_weapon_multiplier)
    out["_case_status_m"] = out["Case_Status"].map(_case_status_multiplier)
    out["_report_m"] = out["Reported_Within_24h"].map(_report_multiplier)

    out["Incident_Risk_Score"] = (
        out["_severity_w"]
        * out["_crime_type_w"]
        * out["_recency_w"]
        * out["_weapon_m"]
        * out["_case_status_m"]
        * out["_report_m"]
    )
    return out


# ---------------------------------------------------------------------------
# Step 2 + 3 + 4: place-level aggregation -> CRI -> Safety Score
# ---------------------------------------------------------------------------
def compute_place_scores(df: pd.DataFrame) -> pd.DataFrame:
    """
    Returns one row per Place with:
      total_incidents, avg_incident_risk, frequency_norm, severity_norm,
      composite_risk_index (0-1), safety_score (0-100), risk_tier
    """
    scored = add_incident_risk_score(df)

    place_agg = scored.groupby("Place").agg(
        total_incidents=("Incident_Risk_Score", "size"),
        total_risk=("Incident_Risk_Score", "sum"),
        avg_incident_risk=("Incident_Risk_Score", "mean"),
        high_severity_count=("Severity", lambda s: (s == "High").sum()),
    ).reset_index()

    # crime-type breakdown per place, for map popups / API payloads
    top_crimes = (
        scored.groupby(["Place", "Crime_Type"]).size()
        .reset_index(name="count")
        .sort_values(["Place", "count"], ascending=[True, False])
    )
    top3 = (
        top_crimes.groupby("Place")
        .apply(lambda g: g.head(3)[["Crime_Type", "count"]].to_dict("records"), include_groups=False)
        .reset_index(name="top_crime_types")
    )
    place_agg = place_agg.merge(top3, on="Place", how="left")

    # --- Normalise the two components across all places (min-max -> 0..1)
    scaler = MinMaxScaler()
    norm = scaler.fit_transform(place_agg[["total_incidents", "avg_incident_risk"]])
    place_agg["frequency_norm"] = norm[:, 0]
    place_agg["severity_norm"] = norm[:, 1]

    # --- Composite Risk Index (higher = more dangerous)
    place_agg["composite_risk_index"] = (
        config.FREQUENCY_WEIGHT * place_agg["frequency_norm"]
        + config.SEVERITY_WEIGHT * place_agg["severity_norm"]
    )

    # --- Safety Score: invert CRI onto 0-100 (100 = safest)
    cri_min, cri_max = place_agg["composite_risk_index"].min(), place_agg["composite_risk_index"].max()
    cri_range = (cri_max - cri_min) or 1.0
    place_agg["safety_score"] = (
        100 * (1 - (place_agg["composite_risk_index"] - cri_min) / cri_range)
    ).round(1)

    # --- Rule-based risk tier (from config thresholds)
    place_agg["risk_tier"] = place_agg["safety_score"].apply(_tier_from_score)

    # --- KMeans cross-check: unsupervised clustering on the same two
    #     normalised features, independent of the fixed thresholds above.
    place_agg["kmeans_cluster"], place_agg["kmeans_tier"] = _kmeans_tiers(
        place_agg[["frequency_norm", "severity_norm"]].values,
        place_agg["safety_score"].values,
    )

    place_agg = place_agg.sort_values("safety_score", ascending=False).reset_index(drop=True)
    return place_agg


def _tier_from_score(score: float) -> str:
    for lo, hi, label in config.RISK_TIERS:
        if lo <= score <= hi:
            return label
    return "Unknown"


def _kmeans_tiers(features: np.ndarray, safety_scores: np.ndarray):
    n_clusters = min(config.KMEANS_N_CLUSTERS, len(features))
    km = KMeans(n_clusters=n_clusters, random_state=config.KMEANS_RANDOM_STATE, n_init=10)
    cluster_ids = km.fit_predict(features)

    # Order clusters by their mean safety_score so labels are meaningful
    order = (
        pd.DataFrame({"cluster": cluster_ids, "score": safety_scores})
        .groupby("cluster")["score"].mean()
        .sort_values(ascending=False)
        .index.tolist()
    )
    labels_by_rank = [t[2] for t in config.RISK_TIERS][: len(order)]
    rank_to_label = {cluster: labels_by_rank[i] for i, cluster in enumerate(order)}
    tiers = [rank_to_label[c] for c in cluster_ids]
    return cluster_ids, tiers


def attach_coordinates(place_scores: pd.DataFrame, coord_lookup_fn) -> pd.DataFrame:
    """coord_lookup_fn: Place(str) -> (lat, lon) | None"""
    coords = place_scores["Place"].map(coord_lookup_fn)
    place_scores = place_scores.copy()
    place_scores["lat"] = coords.map(lambda c: c[0] if c else None)
    place_scores["lon"] = coords.map(lambda c: c[1] if c else None)
    return place_scores
