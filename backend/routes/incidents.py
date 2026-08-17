"""
Incident SLA Interceptor Router:
POST /api/v1/incidents/{incident_id}/acknowledge
"""

from fastapi import APIRouter, HTTPException
from backend.models import IncidentAcknowledgeRequest, IncidentAcknowledgeResponse
from backend.database import db

router = APIRouter(prefix="/api/v1/incidents", tags=["Incident SLA Interceptor"])

@router.post("/{incident_id}/acknowledge", response_model=IncidentAcknowledgeResponse)
def acknowledge_incident(incident_id: str, request: IncidentAcknowledgeRequest):
    updated = db.acknowledge_incident(incident_id, request.responder_id, request.notes)
    if not updated:
        raise HTTPException(status_code=404, detail=f"Incident ID {incident_id} not found.")

    return IncidentAcknowledgeResponse(
        incident_id=updated["incident_id"],
        status=updated["status"],
        acknowledged_by=updated["acknowledged_by"],
        acknowledged_at=updated["updated_at"]
    )
