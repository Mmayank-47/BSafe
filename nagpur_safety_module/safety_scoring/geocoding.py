"""
geocoding.py
------------
Place-name -> (lat, lon) lookup for Nagpur localities.

NOTE: The dataset has no coordinates, so this module ships an approximate,
hand-curated lookup table good enough for city-level visualisation/MVP use.
For production, replace `NAGPUR_PLACE_COORDS` with output from a proper
geocoder (Nominatim/Google Geocoding/your own GIS layer) run once and
cached -- the rest of the pipeline only depends on the `get_coordinates()`
function below, so swapping the data source requires no other code changes.
"""

from typing import Optional, Tuple

# Approximate locality centroids (WGS84 lat/lon), Nagpur, Maharashtra.
NAGPUR_PLACE_COORDS = {
    "Ajni": (21.1265, 79.0870),
    "Ashok Nagar": (21.1350, 79.0950),
    "Bajaj Nagar": (21.1225, 79.0570),
    "Bajeria": (21.1590, 79.1170),
    "Beltarodi": (21.0870, 79.0530),
    "Besa": (21.0980, 79.0850),
    "Bhandewadi": (21.1250, 79.1350),
    "Byramji Town": (21.1650, 79.0700),
    "Chaoni": (21.1670, 79.0780),
    "Civil Lines": (21.1550, 79.0820),
    "Dharampeth": (21.1420, 79.0680),
    "Friends Colony": (21.1050, 79.0650),
    "Gaddi Godam": (21.1580, 79.1050),
    "Gandhibagh": (21.1550, 79.1150),
    "Gandhinagar": (21.1100, 79.0700),
    "Ganeshpeth": (21.1480, 79.0850),
    "Giripeth": (21.1350, 79.0720),
    "Gitti Khadan": (21.1750, 79.0850),
    "Godhni": (21.0500, 79.0450),
    "Gokulpeth": (21.1430, 79.0730),
    "Hawrapeth": (21.1520, 79.1020),
    "Hingna": (21.1150, 79.0100),
    "Hudkeshwar": (21.0950, 79.0350),
    "Imambada": (21.1600, 79.1100),
    "Indora": (21.1700, 79.0950),
    "Itwari": (21.1580, 79.1080),
    "Jaitala": (21.1600, 79.0250),
    "Jaripatka": (21.1800, 79.1000),
    "Kalmeshwar": (21.2300, 78.9200),
    "Kalyan Nagar": (21.1600, 79.1250),
    "Kapil Nagar": (21.1200, 79.1400),
    "Khaparkheda": (21.2800, 79.0000),
    "Khapri": (21.0600, 79.0500),
    "Kotwali": (21.1520, 79.1080),
    "Lakadganj": (21.1650, 79.1150),
    "MIDC": (21.1100, 79.0650),
    "Mahal": (21.1560, 79.1150),
    "Mangalwari": (21.1500, 79.0980),
    "Manish Nagar": (21.1150, 79.0480),
    "Mankapur": (21.1850, 79.0700),
    "Mominpura": (21.1600, 79.1050),
    "Nandanvan": (21.1200, 79.1150),
    "Pachpaoli": (21.1650, 79.1080),
    "Pardi": (21.1750, 79.0600),
    "Pipla": (21.0700, 79.1100),
    "Pratap Nagar": (21.1300, 79.0600),
    "Rajendra Nagar": (21.1450, 79.0600),
    "Ramdaspeth": (21.1420, 79.0780),
    "Ravi Nagar": (21.1300, 79.0680),
    "Sadar": (21.1580, 79.0780),
    "Sakkardara": (21.1200, 79.1200),
    "Seminary Hills": (21.1700, 79.0620),
    "Shraddhanand Peth": (21.1500, 79.0980),
    "Sitabuldi": (21.1480, 79.0810),
    "Sonegaon": (21.1050, 79.0480),
    "Subhash Nagar": (21.1350, 79.1000),
    "Suyog Nagar": (21.1400, 79.1200),
    "Tehsil": (21.1500, 79.1080),
    "Trimurti Nagar": (21.1350, 79.0500),
    "Vayusena Nagar": (21.1000, 79.0500),
    "Wadi": (21.1650, 79.0300),
    "Wardhaman Nagar": (21.1650, 79.1200),
    "Yashodhara Nagar": (21.1350, 79.1250),
}

NAGPUR_CITY_CENTER = (21.1458, 79.0882)


def get_coordinates(place: str) -> Optional[Tuple[float, float]]:
    """Return (lat, lon) for a known place name, else None."""
    return NAGPUR_PLACE_COORDS.get(place.strip())


def coverage_report(places) -> Tuple[list, list]:
    """Given an iterable of place names, return (matched, unmatched)."""
    matched, unmatched = [], []
    for p in places:
        (matched if p.strip() in NAGPUR_PLACE_COORDS else unmatched).append(p)
    return matched, unmatched
