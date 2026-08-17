"""
data_loader.py
---------------
Loads and lightly cleans the raw crime CSV before it reaches the model.
"""

import pandas as pd


def load_crime_csv(path: str) -> pd.DataFrame:
    df = pd.read_csv(path)

    # Trim whitespace on key categorical/text fields
    text_cols = [
        "Place", "Zone", "Police_Station", "Crime_Type", "Severity",
        "Weapon_Used", "Case_Status", "Reported_Within_24h",
    ]
    for col in text_cols:
        if col in df.columns:
            df[col] = df[col].astype(str).str.strip()

    # Drop rows with no usable place name
    df = df[df["Place"].notna() & (df["Place"] != "") & (df["Place"] != "nan")]

    # Ensure Year is numeric
    df["Year"] = pd.to_numeric(df["Year"], errors="coerce")
    df = df[df["Year"].notna()]
    df["Year"] = df["Year"].astype(int)

    return df.reset_index(drop=True)
