"""
Multi-Hop Offline Mesh Network Ingestion Router:
POST /api/v1/mesh/relay
"""

from fastapi import APIRouter, status
from backend.models import MeshRelayRequest, MeshRelayResponse, SOSTriggerRequest
from backend.services.nostr_relay_service import nostr_relay_service
from backend.routes.sos import trigger_sos

router = APIRouter(prefix="/api/v1/mesh", tags=["Offline Mesh & Nostr Ingestion"])

@router.post("/relay", response_model=MeshRelayResponse, status_code=status.HTTP_202_ACCEPTED)
def ingest_mesh_relay(request: MeshRelayRequest):
    # Wrap payload in Noise encrypted Nostr envelope
    payload_dict = {
        "user_id": request.origin_user_id,
        "encrypted_data": request.encrypted_payload_base64,
        "lat": request.latitude,
        "lon": request.longitude
    }
    
    nostr_event = nostr_relay_service.wrap_noise_envelope(
        request.origin_user_id, payload_dict, request.hop_count
    )
    nostr_relay_service.broadcast_to_subscribers(nostr_event)

    # Ingest into core agentic triage pipeline
    sos_req = SOSTriggerRequest(
        user_id=request.origin_user_id,
        trigger_type=request.trigger_type,
        latitude=request.latitude,
        longitude=request.longitude
    )
    sos_res = trigger_sos(sos_req)

    return MeshRelayResponse(
        relay_status="INGESTED_AND_BROADCAST",
        hops_remaining=max(0, 7 - request.hop_count),
        ingested_incident_id=sos_res.incident_id,
        nostr_broadcast_confirmed=True
    )
