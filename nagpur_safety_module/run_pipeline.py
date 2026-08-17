"""
run_pipeline.py
----------------
End-to-end runner:
  CSV  ->  safety_scoring pipeline  ->  output/safety_scores.json
                                     ->  output/safety_scores.csv

The JSON produced here is the ONLY contract the frontend map (or any other
consumer: a React app, a FastAPI endpoint, a mobile app) needs. Re-run this
whenever the underlying crime data is refreshed.
"""

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from safety_scoring import load_crime_csv, compute_place_scores, attach_coordinates
from safety_scoring.geocoding import get_coordinates, coverage_report

DATA_PATH = Path(__file__).parent / "data" / "nagpur_crime_dataset_synthetic_1000.csv"
OUTPUT_DIR = Path(__file__).parent / "output"


def main():
    OUTPUT_DIR.mkdir(exist_ok=True)

    df = load_crime_csv(str(DATA_PATH))
    print(f"Loaded {len(df)} crime records across {df['Place'].nunique()} places.")

    matched, unmatched = coverage_report(df["Place"].unique())
    if unmatched:
        print(f"WARNING: {len(unmatched)} places have no coordinates and will be dropped from the map: {unmatched}")

    scores = compute_place_scores(df)
    scores = attach_coordinates(scores, get_coordinates)

    # Drop places we can't plot on the map, but keep them out of the JSON export
    mappable = scores[scores["lat"].notna()].copy()
    unmappable = scores[scores["lat"].isna()]["Place"].tolist()
    if unmappable:
        print(f"Excluding {len(unmappable)} unmapped place(s) from geo export: {unmappable}")

    # --- Full table (CSV, for analysts / debugging)
    csv_cols = [
        "Place", "total_incidents", "avg_incident_risk", "high_severity_count",
        "frequency_norm", "severity_norm", "composite_risk_index",
        "safety_score", "risk_tier", "kmeans_tier", "lat", "lon",
    ]
    scores[csv_cols].to_csv(OUTPUT_DIR / "safety_scores.csv", index=False)

    # --- Slim JSON contract for the map / API layer
    records = []
    for _, row in mappable.iterrows():
        records.append({
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

    payload = {
        "generated_from": DATA_PATH.name,
        "city": "Nagpur",
        "score_meaning": "0 = least safe, 100 = safest",
        "place_count": len(records),
        "places": records,
    }

    with open(OUTPUT_DIR / "safety_scores.json", "w") as f:
        json.dump(payload, f, indent=2)

    # --- Self-contained HTML output for direct browser viewing without a web server
    frontend_dir = Path(__file__).parent / "frontend"
    index_html_path = frontend_dir / "index.html"
    css_path = frontend_dir / "safety-map.css"
    js_path = frontend_dir / "safety-map.js"

    if index_html_path.exists() and css_path.exists() and js_path.exists():
        html_content = index_html_path.read_text(encoding="utf-8")
        css_content = css_path.read_text(encoding="utf-8")
        js_content = js_path.read_text(encoding="utf-8")

        # Inline CSS and JS
        html_content = html_content.replace('<link rel="stylesheet" href="safety-map.css" />', f'<style>\n{css_content}\n</style>')
        html_content = html_content.replace('<script src="safety-map.js"></script>', f'<script>\n{js_content}\n</script>')

        # Inline JSON payload
        json_js = f"const __SAFETY_DATA_PLACEHOLDER__ = {json.dumps(payload, indent=2)};"
        html_content = html_content.replace("let SAFETY_DATA = null;", f"let SAFETY_DATA = null;\n  {json_js}")

        (OUTPUT_DIR / "nagpur_safety_map.html").write_text(html_content, encoding="utf-8")
        print(f"Wrote {OUTPUT_DIR / 'nagpur_safety_map.html'}")

    print(f"\nWrote {OUTPUT_DIR / 'safety_scores.json'}")
    print(f"Wrote {OUTPUT_DIR / 'safety_scores.csv'}")
    print("\nTop 5 safest:")
    print(scores[["Place", "safety_score", "risk_tier"]].head(5).to_string(index=False))
    print("\nTop 5 least safe:")
    print(scores[["Place", "safety_score", "risk_tier"]].tail(5).to_string(index=False))


if __name__ == "__main__":
    main()
