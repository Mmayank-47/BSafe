"""
Pydantic data models for bSafe agentic backend ecosystem.
"""

from enum import Enum
from typing import List, Optional, Dict, Any
from pydantic import BaseModel, Field, EmailStr
from datetime import datetime

class ContactTier(str, Enum):
    PRIMARY = "PRIMARY"
    SECONDARY = "SECONDARY"
    TERTIARY = "TERTIARY"

class EmergencyContact(BaseModel):
    name: str
    phone_number: str
    tier: ContactTier = ContactTier.PRIMARY
    is_verified: bool = False
    otp_code: Optional[str] = None

class UserRegisterRequest(BaseModel):
    user_id: str
    name: str
    phone_number: str
    email: Optional[str] = None
    emergency_contacts: List[EmergencyContact] = Field(..., min_items=1, max_items=5)

class UserRegisterResponse(BaseModel):
    user_id: str
    status: str
    secure_token: str
    verified_contacts_count: int
    message: str

class JourneyStartRequest(BaseModel):
    user_id: str
    origin: List[float] = Field(..., description="[Latitude, Longitude]")
    destination: List[float] = Field(..., description="[Latitude, Longitude]")
    mode: str = Field(default="WALKING", description="WALKING, DRIVING, TRANSIT")

class RouteSafetyScore(BaseModel):
    overall_score: float = Field(..., ge=0.0, le=10.0)
    crime_risk_index: float
    lighting_density_score: float
    footfall_density_score: float
    recommended_safe_waypoints: List[List[float]]
    risk_level: str  # LOW, MODERATE, HIGH, SEVERE

class JourneyStartResponse(BaseModel):
    journey_id: str
    status: str
    route_safety: RouteSafetyScore
    monitoring_interval_seconds: int = 5

class TelemetryPing(BaseModel):
    journey_id: str
    user_id: str
    latitude: float
    longitude: float
    speed_mps: float
    heading_degrees: float
    timestamp: datetime = Field(default_factory=datetime.utcnow)

class AnomalyCheckResponse(BaseModel):
    journey_id: str
    is_anomaly: bool
    anomaly_type: Optional[str] = None  # ROUTE_DEVIATION, VELOCITY_DROP, ISOLATED_STOP
    requires_checkin: bool = False
    checkin_prompt: Optional[str] = None

class SOSTriggerType(str, Enum):
    ACOUSTIC_HOTWORD = "ACOUSTIC_HOTWORD"
    DECIBEL_SPIKE = "DECIBEL_SPIKE"
    HARDWARE_KEY_SEQUENCE = "HARDWARE_KEY_SEQUENCE"
    DURESS_PIN = "DURESS_PIN"
    MANUAL_BUTTON = "MANUAL_BUTTON"
    ANOMALY_TIMEOUT = "ANOMALY_TIMEOUT"
    BLE_MESH_RELAY = "BLE_MESH_RELAY"

class SOSTriggerRequest(BaseModel):
    user_id: str
    trigger_type: SOSTriggerType
    latitude: float
    longitude: float
    decibel_level: float = 0.0
    hotword_detected: Optional[str] = None
    recent_call_vector: Optional[str] = None  # Number extracted from recent call log
    audio_snippet_base64: Optional[str] = None
    duress_pin_used: bool = False
    timestamp: datetime = Field(default_factory=datetime.utcnow)

class IncidentTier(str, Enum):
    TIER_1 = "TIER_1"  # Moderate distress (<85 dB, local contact + mesh alert)
    TIER_2 = "TIER_2"  # Extreme distress (>85 dB scream, 112 IVR bridge, full dispatch)

class IncidentStatus(str, Enum):
    OPEN = "OPEN"
    DISPATCHED = "DISPATCHED"
    ACKNOWLEDGED = "ACKNOWLEDGED"
    RESOLVED = "RESOLVED"
    ESCALATED = "ESCALATED"

class ResponderInfo(BaseModel):
    responder_id: str
    name: str
    role: str  # POLICE, CAMPUS_SECURITY, NGO_VOLUNTEER, AMBULANCE
    distance_meters: float
    phone_number: str

class SOSTriggerResponse(BaseModel):
    incident_id: str
    status: IncidentStatus
    tier: IncidentTier
    triage_summary: str
    assigned_responders: List[ResponderInfo]
    escalation_sla_seconds: int = 45
    ivr_bridge_initiated: bool = False

class IncidentAcknowledgeRequest(BaseModel):
    incident_id: str
    responder_id: str
    notes: Optional[str] = None

class IncidentAcknowledgeResponse(BaseModel):
    incident_id: str
    status: IncidentStatus
    acknowledged_by: str
    acknowledged_at: datetime = Field(default_factory=datetime.utcnow)

class MeshRelayRequest(BaseModel):
    relay_node_id: str
    hop_count: int = Field(..., ge=1, le=7)
    origin_user_id: str
    encrypted_payload_base64: str
    latitude: float
    longitude: float
    trigger_type: SOSTriggerType
    nostr_event_id: str
    timestamp: datetime = Field(default_factory=datetime.utcnow)

class MeshRelayResponse(BaseModel):
    relay_status: str
    hops_remaining: int
    ingested_incident_id: Optional[str] = None
    nostr_broadcast_confirmed: bool = True
