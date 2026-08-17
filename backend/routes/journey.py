"""
Journey Tracking & Anomaly Monitoring Router:
POST /api/v1/journey/start
POST /api/v1/journey/telemetry
"""

from fastapi import APIRouter, HTTPException
from datetime import datetime
from backend.models import (
    JourneyStartRequest,
    JourneyStartResponse,
    TelemetryPing,
    AnomalyCheckResponse
)
from backend.agents.route_safety_agent import route_safety_agent
from backend.agents.anomaly_detection_agent import anomaly_detection_agent
from backend.database import db

router = APIRouter(prefix="/api/v1/journey", tags=["Journey & Telemetry"])

@router.post("/start", response_model=JourneyStartResponse)
def start_journey(request: JourneyStartRequest):
    journey_id = f"JRN_{int(datetime.utcnow().timestamp() * 1000)}"
    
    # Evaluate dynamic route safety score via Route Safety Agent
    safety_score = route_safety_agent.evaluate_route(request)

    db.active_journeys[journey_id] = {
        "journey_id": journey_id,
        "user_id": request.user_id,
        "origin": request.origin,
        "destination": request.destination,
        "mode": request.mode,
        "created_at": datetime.utcnow().isoformat()
    }

    return JourneyStartResponse(
        journey_id=journey_id,
        status="ACTIVE_MONITORING",
        route_safety=safety_score,
        monitoring_interval_seconds=5
    )

@router.post("/telemetry", response_model=AnomalyCheckResponse)
def stream_telemetry(ping: TelemetryPing):
    if ping.journey_id not in db.active_journeys:
        raise HTTPException(status_code=404, detail="Journey session not found or expired.")

    # Process telemetry stream via Anomaly Detection Agent
    anomaly_result = anomaly_detection_agent.process_telemetry(ping)
    return anomaly_result
