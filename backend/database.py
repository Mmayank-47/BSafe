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
        
        # Gamified Safety Contribution Module tables
        self.safety_locations: Dict[str, dict] = {}
        self.safety_audits: Dict[str, dict] = {}
        self.safety_points_ledger: List[dict] = []
        self.safety_user_profiles: Dict[str, dict] = {}
        self.safety_user_badges: List[dict] = []
        self.safety_leaderboard_cache: List[dict] = []

        # Pre-seed verified spatial responders (Police, Security, Volunteers)
        self.seed_responders()
        self.seed_safety_locations()

    def seed_responders(self):
        self.responders = [
            {"responder_id": "RESP_001", "name": "Campus Security Unit Alpha", "role": "CAMPUS_SECURITY", "lat": 28.6139, "lon": 77.2090, "phone": "+919876543210"},
            {"responder_id": "RESP_002", "name": "Central Police Beat Patrol", "role": "POLICE", "lat": 28.6145, "lon": 77.2080, "phone": "112"},
            {"responder_id": "RESP_003", "name": "Women Safety NGO Volunteer Squad", "role": "NGO_VOLUNTEER", "lat": 28.6150, "lon": 77.2100, "phone": "+919123456789"},
            {"responder_id": "RESP_004", "name": "Rapid Response Emergency Ambulance", "role": "AMBULANCE", "lat": 28.6120, "lon": 77.2050, "phone": "102"},
        ]

    def seed_safety_locations(self):
        """Pre-seeds realistic safety audits and locations in Nagpur & Delhi."""
        now_iso = datetime.utcnow().isoformat()
        
        # Default user profile
        self.safety_user_profiles["USER_DEMO_001"] = {
            "user_id": "USER_DEMO_001",
            "display_alias": "SafetyHero_Ananya",
            "use_alias": True,
            "total_points": 450,
            "level": 3,
            "level_title": "Pathfinder",
            "streak_count": 5,
            "last_audit_date": datetime.utcnow().date().isoformat(),
            "weekly_audits_count": 4,
            "city": "Nagpur"
        }
        
        # Add pre-seeded user badges
        self.safety_user_badges.extend([
            {"user_id": "USER_DEMO_001", "badge_id": "NIGHT_OWL", "name": "Night Owl", "description": "Completed 10 night-time safety audits", "icon": "🌙", "earned_at": now_iso},
            {"user_id": "USER_DEMO_001", "badge_id": "FIRST_RESPONDER", "name": "First Responder", "description": "First person to audit a new unmapped location", "icon": "⚡", "earned_at": now_iso},
        ])

        # Pre-seeded locations
        seeds = [
            {
                "id": "LOC_NAGPUR_01",
                "lat": 21.1458,
                "lng": 79.0882,
                "address_label": "Sitabuldi Metro Station Entrance, Nagpur",
                "category_tag": "METRO_STATION",
                "safety_score": 4.6,
                "audit_count": 12,
                "created_at": now_iso
            },
            {
                "id": "LOC_NAGPUR_02",
                "lat": 21.1255,
                "lng": 79.0520,
                "address_label": "VNIT South Gate Walkway, Bajaj Nagar",
                "category_tag": "ISOLATED_STRETCH",
                "safety_score": 2.4,
                "audit_count": 8,
                "created_at": now_iso
            },
            {
                "id": "LOC_NAGPUR_03",
                "lat": 21.1500,
                "lng": 79.0800,
                "address_label": "Futala Lake Promenade, Nagpur",
                "category_tag": "PARK",
                "safety_score": 3.8,
                "audit_count": 15,
                "created_at": now_iso
            },
            {
                "id": "LOC_DELHI_01",
                "lat": 28.6139,
                "lng": 77.2090,
                "address_label": "Connaught Place Radial Road 2, New Delhi",
                "category_tag": "MARKET",
                "safety_score": 4.8,
                "audit_count": 25,
                "created_at": now_iso
            }
        ]

        for s in seeds:
            self.safety_locations[s["id"]] = s
            # Create a representative audit for each seed
            audit_id = f"AUD_{s['id']}"
            self.safety_audits[audit_id] = {
                "id": audit_id,
                "user_id": "USER_DEMO_001",
                "location_id": s["id"],
                "latitude": s["lat"],
                "longitude": s["lng"],
                "address_label": s["address_label"],
                "category_tag": s["category_tag"],
                "time_of_day": "EVENING",
                "lighting": 5 if s["safety_score"] > 4.0 else 2,
                "openness": 4,
                "visibility": 4,
                "crowd": "CROWDED" if s["safety_score"] > 4.0 else "FEW",
                "security": "YES_FREQUENT" if s["safety_score"] > 4.0 else "NO",
                "walk_path": 4,
                "public_transport": 5,
                "gender_diversity": 4,
                "feeling": 5 if s["safety_score"] > 4.0 else 2,
                "comment": f"Verified safety conditions at {s['address_label']}.",
                "photo_url": "https://images.unsplash.com/photo-1519501025264-65ba15a82390",
                "points_awarded": 65,
                "upvotes": 7,
                "status": "ACTIVE",
                "created_at": now_iso
            }

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
