# Nagpur Safety Score

A modular pipeline that converts raw crime/FIR records into a per-locality
**Safety Score (0–100, 100 = safest)** and renders it as a red→green shaded
map. Built to be dropped straight into an existing project — the scoring
engine, the data contract, and the map widget are three independent pieces.

```
nagpur_safety/
├── data/
│   └── nagpur_crime_dataset_synthetic_1000.csv
├── safety_scoring/                  # <- the model (pure Python, no map/UI code)
│   ├── config.py                    #    every tunable weight lives here
│   ├── data_loader.py                #    CSV -> cleaned DataFrame
│   ├── scoring_model.py              #    formula + KMeans + aggregation
│   └── geocoding.py                  #    place name -> (lat, lon)
├── run_pipeline.py                   # CLI: CSV -> output/safety_scores.json + .csv
├── api.py                            # optional FastAPI wrapper (REST)
├── frontend/
│   ├── safety-map.js                 # framework-agnostic Leaflet widget
│   ├── safety-map.css                # widget styling (popups/tooltips)
│   └── index.html                    # demo dashboard wiring it together
└── output/
    ├── safety_scores.json            # <- the data contract, consumed by the map
    ├── safety_scores.csv             #    same data, flat, for analysts
    └── nagpur_safety_map.html        #    fully self-contained rendered demo
```

## 1. The formula

Every crime record gets an **Incident Risk Score (IRS)**:

```
IRS = severity_weight × crime_type_weight × recency_weight × weapon_multiplier
      × case_status_multiplier × late_report_multiplier
```

| Factor | What it captures | Where it's tuned |
|---|---|---|
| `severity_weight` | The dataset's own Low/Medium/High label (1 / 2.5 / 5) | `config.SEVERITY_WEIGHTS` |
| `crime_type_weight` | Intrinsic danger of the offence type — Murder/Rape (5.0) vs. Theft (1.5) | `config.CRIME_TYPE_WEIGHTS` |
| `recency_weight` | Exponential decay so recent crime matters more: `exp(-0.15 × years_ago)` | `config.RECENCY_DECAY_RATE` |
| `weapon_multiplier` | +20% if a weapon was involved | `config.WEAPON_INVOLVED_MULTIPLIER` |
| `case_status_multiplier` | +5–15% if the case is still unresolved (weak proxy for enforcement) | `config.CASE_STATUS_MULTIPLIERS` |
| `late_report_multiplier` | +5% if not reported within 24h | `config.LATE_REPORT_MULTIPLIER` |

**Place-level aggregation** turns per-record IRS into two comparable (0–1,
min-max normalised across all places) components:

* **frequency_norm** — how *often* incidents happen at that place (volume)
* **severity_norm** — how *severe* incidents are on average at that place

```
Composite Risk Index (CRI) = 0.40 × frequency_norm + 0.60 × severity_norm
Safety Score = 100 × (1 − normalise(CRI))        # 0 = least safe, 100 = safest
```

Weights (`FREQUENCY_WEIGHT` / `SEVERITY_WEIGHT`) are config, not code — bump
`SEVERITY_WEIGHT` if you want a single grievous crime to dominate over many
minor ones, or vice versa.

**KMeans cross-check** — `scoring_model.py` also runs unsupervised KMeans
(k=5) on `[frequency_norm, severity_norm]` and labels clusters by their mean
score. This is independent of the fixed 0–100 thresholds and is included so
you can sanity-check ("does the rule-based tier agree with the data-driven
cluster?") rather than trusting a single hard-coded scale. Both `risk_tier`
(rule-based) and `kmeans_tier` (clustering-based) ship in the output.

> **Why not a "trained" ML model?** There's no ground-truth safety label to
> supervise against (no dataset actually says "this place has a true safety
> value of 62"). This is standard practice for this kind of index: engineer
> defensible features, combine them with domain-informed weights, and use
> unsupervised learning (KMeans here) to validate structure — the same
> approach used by real-world city safety indices. If you later get outcome
> data (e.g., resident survey scores, repeat-victimisation rates), swap the
> fixed weights for a regression fit against them — the formula's inputs
> (the six `_w`/`_m` columns in `scoring_model.py`) are already feature-ready.

## 2. Run it

```bash
pip install pandas numpy scikit-learn
python run_pipeline.py
```

This writes `output/safety_scores.json` — the **only file the map needs**.
Re-run it whenever the CSV is refreshed.

## 3. The map (framework-agnostic)

`frontend/safety-map.js` is a zero-dependency (besides Leaflet) ES-module /
UMD widget. It does not know about Nagpur, this dataset, or your app's
styling — it just renders whatever `places[]` array you give it.

**Plain HTML:**
```html
<div id="safety-map" style="height:600px"></div>
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/leaflet.min.css">
<script src="https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/leaflet.min.js"></script>
<link rel="stylesheet" href="safety-map.css">
<script src="safety-map.js"></script>
<script>
  const map = new SafetyMap('safety-map', { center: [21.1458, 79.0882], zoom: 12 });
  map.loadFromUrl('output/safety_scores.json');
</script>
```

**React/Vue/any bundler:** `import { SafetyMap } from './safety-map.js'`
(it's UMD, works as CommonJS/ESM import too) — see the header comment in
the file for the two-line Leaflet import wiring.

**`frontend/index.html`** is a full dashboard demo (title panel, tier
filter chips, safest/riskiest rankings, legend) — copy the parts you want,
discard the rest. `output/nagpur_safety_map.html` is the same demo with the
data/CSS/JS **inlined** into one file, so you can just open it in a browser
with no server.

## 4. Serving fresh scores instead of a static file

`api.py` wraps the same pipeline in three FastAPI endpoints
(`GET /api/safety-scores`, `GET /api/safety-scores/{place}`,
`POST /api/safety-scores/refresh`). Mount it into an existing FastAPI app,
or run standalone with `uvicorn api:app`. Point `SafetyMap.loadFromUrl()` at
that endpoint instead of the static JSON and you have live-refreshing
scores with no other code changes.

## 5. Known limitations (be upfront about these)

- **Coordinates are approximate**, hand-curated locality centroids
  (`safety_scoring/geocoding.py`), not parcel-level. Swap in a proper
  geocoder for production; `get_coordinates(place)` is the only function
  the rest of the pipeline depends on.
- **No population/footfall normalisation.** A place with more foot traffic
  will naturally log more incidents; the score currently reflects raw
  incident load; per-capita rates need population data.
- **Weights are domain-informed, not fitted.** See "Why not a trained
  model" above — treat `config.py` as a starting point to calibrate with
  a domain expert (e.g., local police data analyst), not gospel.
- The bundled CSV is **synthetic** (per its own `Data_Source` column) — for
  MVP / pipeline demonstration only, not real Nagpur incident data.
