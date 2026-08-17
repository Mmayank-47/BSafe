"""
Geospatial Dispatcher Agent: Queries spatial indexes to locate verified responders
(campus security, police, NGO volunteers) within 500m-2km radius and orchestrates
automated emergency bridges.
"""

from typing import List, Tuple
from backend.models import ResponderInfo, IncidentTier
from backend.database import db

class GeospatialDispatcherAgent:
    """Agentic Spatial Dispatch & IVR Coordinator."""

    def dispatch_incident(self, lat: float, lon: float, tier: IncidentTier) -> Tuple[List[ResponderInfo], bool]:
        # Search radius: 1000m for Tier 1, 2500m for Tier 2
        radius = 2500.0 if tier == IncidentTier.TIER_2 else 1000.0
        
        responders = db.find_nearby_responders(lat, lon, radius_meters=radius)

        # Automated IVR bridge trigger for Tier 2 extreme distress
        ivr_bridge_initiated = (tier == IncidentTier.TIER_2)

        return responders, ivr_bridge_initiated

geospatial_dispatcher_agent = GeospatialDispatcherAgent()
