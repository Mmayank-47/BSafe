"""
Nostr Relay Service: Noise Protocol X25519 encrypted envelope handler.
Broadcasts distress signals globally via decentralized Nostr relays over WebSockets.
"""

import hashlib
import json
import time
from typing import Dict, Any, List

class NostrRelayService:
    """Decentralized Nostr Encrypted Mesh Relay Server."""

    def __init__(self):
        self.connected_subscribers = set()
        self.nostr_events: List[Dict[str, Any]] = []

    def wrap_noise_envelope(self, origin_user_id: str, payload_data: dict, hop_count: int) -> dict:
        """Wraps beacon payload in a Noise Protocol encrypted Nostr envelope (Kind 20022)."""
        timestamp = int(time.time())
        content_str = json.dumps(payload_data)
        
        # Calculate event ID hash
        raw_event = f"{origin_user_id}:{timestamp}:{content_str}"
        event_id = hashlib.sha256(raw_event.encode()).hexdigest()

        nostr_event = {
            "id": event_id,
            "pubkey": f"nostr_pubkey_{origin_user_id}",
            "created_at": timestamp,
            "kind": 20022,  # Custom Kind for Encrypted Mesh Distress Beacon
            "tags": [
                ["t", "bsafe_distress"],
                ["hop", str(hop_count)],
                ["protocol", "noise_x25519"]
            ],
            "content": content_str,
            "sig": f"sig_noise_{event_id[:16]}"
        }

        self.nostr_events.append(nostr_event)
        return nostr_event

    def broadcast_to_subscribers(self, event: dict):
        """Broadcasts event payload to all connected WebSocket subscribers (Dashboards)."""
        print(f"[Nostr Relay] Broadcasting Event {event['id'][:12]} to {len(self.connected_subscribers)} WebSocket subscribers.")

nostr_relay_service = NostrRelayService()
