"""
Multi-Modal SOS Trigger Ingestion Router:
POST /api/v1/sos/trigger
"""

from fastapi import APIRouter, status
from backend.models import SOSTriggerRequest, SOSTriggerResponse, IncidentTier
from backend.agents.sos_triage_agent import sos_triage_agent
from backend.agents.geospatial_dispatcher_agent import geospatial_dispatcher_agent
from backend.services.telephony_service import telephony_service
from backend.database import db

router = APIRouter(prefix="/api/v1/sos", tags=["Multi-Modal SOS Ingestion"])

@router.post("/trigger", response_model=SOSTriggerResponse, status_code=status.HTTP_201_CREATED)
def trigger_sos(request: SOSTriggerRequest):
    # Step 1: Agentic Triage (Classify into Tier 1 or Tier 2)
    tier, summary = sos_triage_agent.triage_payload(request)

    # Step 2: Geospatial Dispatch & Responder Index Query
    responders, ivr_bridge_initiated = geospatial_dispatcher_agent.dispatch_incident(
        request.latitude, request.longitude, tier
    )

    # Step 3: Trigger IVR Telephony Bridge to 112 if Tier 2 distress
    if ivr_bridge_initiated:
        telephony_service.initiate_ivr_112_bridge(
            incident_id="TEMP",
            lat=request.latitude,
            lon=request.longitude,
            recent_call_vector=request.recent_call_vector
        )

    # Step 4: Persist Incident in closed-loop state machine
    incident = db.create_incident(request, tier, summary, responders)

    return SOSTriggerResponse(
        incident_id=incident["incident_id"],
        status=incident["status"],
        tier=incident["tier"],
        triage_summary=incident["triage_summary"],
        assigned_responders=responders,
        escalation_sla_seconds=45,
        ivr_bridge_initiated=ivr_bridge_initiated
    )
