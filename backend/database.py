"""
In-memory spatial index and state engine for bSafe backend.
Executes ST_DWithin spatial queries for responder matching and tracks active incident state machines.
"""

import math
from typing import Dict, List, Optional
from datetime import datetime
from backend.models import (
    UserRegisterRequest,
    ResponderInfo,
    IncidentStatus,
    IncidentTier,
    SOSTriggerRequest
)

def haversine_distance_meters(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Calculates distance between two lat/lon pairs in meters using Haversine formula."""
    R = 6371000.0  # Earth radius in meters
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    delta_phi = math.radians(lat2 - lat1)
    delta_lambda = math.radians(lon2 - lon1)

    a = (math.sin(delta_phi / 2.0) ** 2 +
         math.cos(phi1) * math.cos(phi2) * (math.sin(delta_lambda / 2.0) ** 2))
    c = 2.0 * math.atan2(math.sqrt(a), math.sqrt(1.0 - a))
    return R * c

class SystemDatabase:
    def __init__(self):
        self.users: Dict[str, UserRegisterRequest] = {}
        self.active_journeys: Dict[str, dict] = {}
        self.telemetry_history: Dict[str, List[dict]] = {}
        self.incidents: Dict[str, dict] = {}
        self.mesh_relays: List[dict] = []
        
        # Pre-seed verified spatial responders (Police, Security, Volunteers)
        self.seed_responders()

    def seed_responders(self):
        self.responders = [
            {"responder_id": "RESP_001", "name": "Campus Security Unit Alpha", "role": "CAMPUS_SECURITY", "lat": 28.6139, "lon": 77.2090, "phone": "+919876543210"},
            {"responder_id": "RESP_002", "name": "Central Police Beat Patrol", "role": "POLICE", "lat": 28.6145, "lon": 77.2080, "phone": "112"},
            {"responder_id": "RESP_003", "name": "Women Safety NGO Volunteer Squad", "role": "NGO_VOLUNTEER", "lat": 28.6150, "lon": 77.2100, "phone": "+919123456789"},
            {"responder_id": "RESP_004", "name": "Rapid Response Emergency Ambulance", "role": "AMBULANCE", "lat": 28.6120, "lon": 77.2050, "phone": "102"},
        ]

    def register_user(self, request: UserRegisterRequest) -> dict:
        self.users[request.user_id] = request
        return {
            "user_id": request.user_id,
            "status": "REGISTERED",
            "secure_token": f"sec_tok_{request.user_id}_x99",
            "verified_contacts_count": len(request.emergency_contacts),
            "message": "User and Emergency Contacts provisioned successfully."
        }

    def get_user(self, user_id: str) -> Optional[UserRegisterRequest]:
        return self.users.get(user_id)

    def find_nearby_responders(self, lat: float, lon: float, radius_meters: float = 2000.0) -> List[ResponderInfo]:
        """Spatial index search equivalent to PostGIS ST_DWithin(geom, ST_MakePoint(lon, lat), radius)."""
        results = []
        for resp in self.responders:
            dist = haversine_distance_meters(lat, lon, resp["lat"], resp["lon"])
            if dist <= radius_meters:
                results.append(
                    ResponderInfo(
                        responder_id=resp["responder_id"],
                        name=resp["name"],
                        role=resp["role"],
                        distance_meters=round(dist, 1),
                        phone_number=resp["phone"]
                    )
                )
        # Sort by distance
        results.sort(key=lambda r: r.distance_meters)
        return results

    def create_incident(self, request: SOSTriggerRequest, tier: IncidentTier, summary: str, responders: List[ResponderInfo]) -> dict:
        incident_id = f"INC_{int(datetime.utcnow().timestamp() * 1000)}"
        incident = {
            "incident_id": incident_id,
            "user_id": request.user_id,
            "trigger_type": request.trigger_type,
            "tier": tier,
            "status": IncidentStatus.DISPATCHED,
            "latitude": request.latitude,
            "longitude": request.longitude,
            "decibel_level": request.decibel_level,
            "hotword_detected": request.hotword_detected,
            "recent_call_vector": request.recent_call_vector,
            "triage_summary": summary,
            "assigned_responders": [r.dict() for r in responders],
            "created_at": datetime.utcnow().isoformat(),
            "updated_at": datetime.utcnow().isoformat(),
            "acknowledged_by": None,
            "escalation_level": 1
        }
        self.incidents[incident_id] = incident
        return incident

    def acknowledge_incident(self, incident_id: str, responder_id: str, notes: Optional[str] = None) -> Optional[dict]:
        if incident_id in self.incidents:
            inc = self.incidents[incident_id]
            inc["status"] = IncidentStatus.ACKNOWLEDGED
            inc["acknowledged_by"] = responder_id
            inc["updated_at"] = datetime.utcnow().isoformat()
            if notes:
                inc["notes"] = notes
            return inc
        return None

    def escalate_incident(self, incident_id: str, expanded_responders: List[ResponderInfo]) -> Optional[dict]:
        if incident_id in self.incidents:
            inc = self.incidents[incident_id]
            if inc["status"] == IncidentStatus.DISPATCHED:
                inc["status"] = IncidentStatus.ESCALATED
                inc["escalation_level"] += 1
                inc["assigned_responders"].extend([r.dict() for r in expanded_responders])
                inc["updated_at"] = datetime.utcnow().isoformat()
                return inc
        return None

db = SystemDatabase()
