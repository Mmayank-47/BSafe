"""
WebSocket Nostr Relay Subscription Router:
WSS /nostr/relay/subscribe
Streams decentralized mesh distress envelopes and incident events in real-time to Police & NGO dashboards.
"""

from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from backend.services.nostr_relay_service import nostr_relay_service

router = APIRouter(tags=["WebSocket Nostr Relay Stream"])

@router.websocket("/nostr/relay/subscribe")
async def nostr_relay_subscribe(websocket: WebSocket):
    await websocket.accept()
    nostr_relay_service.connected_subscribers.add(websocket)
    try:
        # Send initial confirmation message
        await websocket.send_json({
            "type": "CONNECTION_ESTABLISHED",
            "message": "Subscribed to bSafe Decentralized Nostr Mesh Relay Stream",
            "active_relays_count": 5
        })
        
        while True:
            # Maintain active connection stream
            data = await websocket.receive_text()
            # Echo heartbeat or client ping
            await websocket.send_json({"type": "PONG", "received": data})
    except WebSocketDisconnect:
        nostr_relay_service.connected_subscribers.remove(websocket)
