"""
config.py
---------
Central, tunable configuration for the Nagpur Safety Score model.
Every weight used by the scoring formula lives here so the model can be
re-tuned (or swapped for learned weights later) without touching the
scoring logic itself.
"""

# ---------------------------------------------------------------------------
# 1. Severity of the individual FIR / case record (as labelled in the data)
# ---------------------------------------------------------------------------
SEVERITY_WEIGHTS = {
    "Low": 1.0,
    "Medium": 2.5,
    "High": 5.0,
}
DEFAULT_SEVERITY_WEIGHT = 2.0  # fallback if an unseen label appears

# ---------------------------------------------------------------------------
# 2. Intrinsic danger of the crime *type* itself (1 = least dangerous,
#    5 = most dangerous to personal safety). This is what lets a single
#    "Murder" outweigh many "Theft" records.
# ---------------------------------------------------------------------------
CRIME_TYPE_WEIGHTS = {
    "Murder": 5.0,
    "Rape": 5.0,
    "Attempted Murder": 4.8,
    "Human Trafficking": 4.6,
    "Kidnapping": 4.5,
    "Robbery": 4.0,
    "Grievous Hurt": 4.0,
    "Molestation": 4.0,
    "Rioting": 3.6,
    "Extortion": 3.5,
    "Domestic Violence / Cruelty by Relatives": 3.5,
    "Illegal Weapons Possession": 3.5,
    "Drug Trafficking": 3.5,
    "Assault": 3.3,
    "Fatal Road Accident (Rash Driving)": 3.2,
    "NDPS (Narcotics)": 3.0,
    "Chain Snatching": 3.0,
    "Eve Teasing / Harassment": 2.7,
    "House Break-in": 2.5,
    "Burglary": 2.5,
    "Cybercrime (OTP/Loan App Fraud)": 2.2,
    "Cyber Fraud": 2.2,
    "Fraud": 2.0,
    "Mobile Phone Snatching": 2.0,
    "Motor Vehicle Theft": 2.0,
    "Counterfeit Currency": 1.6,
    "Illegal Liquor Trade": 1.5,
    "Cattle Theft": 1.5,
    "Theft": 1.5,
    "Gambling": 1.0,
}
DEFAULT_CRIME_TYPE_WEIGHT = 2.0  # fallback if an unseen crime type appears

# ---------------------------------------------------------------------------
# 3. Recency decay -- a crime last month should matter more to a *current*
#    safety score than one from three years ago. Exponential decay per year.
# ---------------------------------------------------------------------------
RECENCY_DECAY_RATE = 0.15   # weight = exp(-RATE * years_ago)
CURRENT_YEAR = 2026

# ---------------------------------------------------------------------------
# 4. Secondary risk multipliers
# ---------------------------------------------------------------------------
WEAPON_INVOLVED_MULTIPLIER = 1.2      # any weapon other than "None"
NO_WEAPON_MULTIPLIER = 1.0

# Case outcome as a weak proxy for enforcement / deterrence effectiveness.
# Unresolved / still-active cases nudge the risk of a record up slightly;
# resolved-and-convicted cases are left at baseline.
CASE_STATUS_MULTIPLIERS = {
    "Case Closed - Convicted": 1.0,
    "Case Closed - Acquitted": 1.05,
    "Chargesheet Filed": 1.05,
    "Under Trial": 1.05,
    "FIR Registered - Under Investigation": 1.1,
    "Case Pending": 1.1,
    "Absconding Accused": 1.15,
}
DEFAULT_CASE_STATUS_MULTIPLIER = 1.0

# Late reporting (>24h) can indicate under-policing / fear of reporting in
# an area -- small additional nudge.
LATE_REPORT_MULTIPLIER = 1.05
ON_TIME_REPORT_MULTIPLIER = 1.0

# ---------------------------------------------------------------------------
# 5. How the two place-level components are combined into one Composite
#    Risk Index (CRI) before being converted into the 0-100 Safety Score.
#    - frequency component  = how OFTEN incidents happen at a place
#    - severity component   = how SEVERE/dangerous incidents are on average
# ---------------------------------------------------------------------------
FREQUENCY_WEIGHT = 0.40
SEVERITY_WEIGHT = 0.60

# ---------------------------------------------------------------------------
# 6. Risk-tier thresholds applied to the final 0-100 Safety Score
#    (used for map colouring buckets / labels; KMeans clustering in the
#    model provides a data-driven cross-check of these bands).
# ---------------------------------------------------------------------------
RISK_TIERS = [
    (80, 100, "Very Safe"),
    (65, 80, "Safe"),
    (50, 65, "Moderate"),
    (35, 50, "Risky"),
    (0, 35, "High Risk"),
]

KMEANS_N_CLUSTERS = 5
KMEANS_RANDOM_STATE = 42
