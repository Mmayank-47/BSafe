"""
End-to-End Program Simulation for bSafe Closed-Loop Agentic Platform.
Runs registration, journey monitoring, multi-modal SOS triage, SLA acknowledgment, and mesh relay.
"""

import json
import urllib.request

BASE_URL = "http://127.0.0.1:8000"

def make_post(endpoint: str, data: dict):
    url = f"{BASE_URL}{endpoint}"
    req = urllib.request.Request(
        url,
        data=json.dumps(data).encode("utf-8"),
        headers={"Content-Type": "application/json"}
    )
    res = urllib.request.urlopen(req)
    return json.loads(res.read().decode("utf-8"))

def make_get(endpoint: str):
    url = f"{BASE_URL}{endpoint}"
    res = urllib.request.urlopen(url)
    return json.loads(res.read().decode("utf-8"))

def main():
    print("=" * 60)
    print("   RUNNING bSAFE CLOSED-LOOP AGENTIC PROGRAM SIMULATION")
    print("=" * 60)
    
    # 1. Health Check
    health = make_get("/")
    print(f"\n[1/6] Server Health: {health['status']}")
    print(f"      Active Micro-Agents: {', '.join(health['active_agents'])}")
    
    # 2. Auth Registration with Tiered Contacts
    reg_data = {
        "user_id": "usr_demo_808",
        "name": "Sarah Connor",
        "phone_number": "+919876543210",
        "emergency_contacts": [
            {"name": "Guardian Contact 1", "phone_number": "+919876543211", "tier": "PRIMARY"},
            {"name": "Guardian Contact 2", "phone_number": "+919876543212", "tier": "SECONDARY"}
        ]
    }
    reg_res = make_post("/api/v1/auth/register", reg_data)
    print(f"\n[2/6] User Onboarding & Contact Provisioning:")
    print(f"      Status: {reg_res['status']} | Verified Contacts: {reg_res['verified_contacts_count']}")
    
    # 3. Journey Start & Route Safety Agent
    journey_data = {
        "user_id": "usr_demo_808",
        "origin": [28.6139, 77.2090],
        "destination": [28.6200, 77.2150],
        "mode": "WALKING"
    }
    journey_res = make_post("/api/v1/journey/start", journey_data)
    safety = journey_res["route_safety"]
    print(f"\n[3/6] Journey Started (ID: {journey_res['journey_id']}):")
    print(f"      Route Safety Agent Score: {safety['overall_score']}/10 ({safety['risk_level']} RISK)")
    print(f"      Lighting Score: {safety['lighting_density_score']} | Footfall Score: {safety['footfall_density_score']}")
    
    # 4. Multi-Modal Extreme Distress SOS Trigger (>85dB Scream + Hotword)
    sos_data = {
        "user_id": "usr_demo_808",
        "trigger_type": "DECIBEL_SPIKE",
        "latitude": 28.6139,
        "longitude": 77.2090,
        "decibel_level": 94.5,
        "hotword_detected": "Bachao",
        "recent_call_vector": "+919876543000"
    }
    sos_res = make_post("/api/v1/sos/trigger", sos_data)
    print(f"\n[4/6] Multi-Modal SOS Triggered (Incident ID: {sos_res['incident_id']}):")
    print(f"      Tier: {sos_res['tier']} | Status: {sos_res['status']}")
    print(f"      Triage Summary: {sos_res['triage_summary']}")
    print(f"      IVR 112 Bridge Initiated: {sos_res['ivr_bridge_initiated']}")
    print(f"      Assigned Spatial Responders ({len(sos_res['assigned_responders'])}):")
    for r in sos_res['assigned_responders']:
        print(f"      - {r['name']} ({r['role']}) - Distance: {r['distance_meters']}m")
        
    # 5. Closed-Loop SLA Incident Acknowledgment
    ack_data = {
        "incident_id": sos_res['incident_id'],
        "responder_id": "RESP_001",
        "notes": "Patrol unit deployed to location."
    }
    ack_res = make_post(f"/api/v1/incidents/{sos_res['incident_id']}/acknowledge", ack_data)
    print(f"\n[5/6] Incident SLA Acknowledgment:")
    print(f"      Status: {ack_res['status']} | Acknowledged By: {ack_res['acknowledged_by']}")

    # 6. Multi-Hop Offline Mesh Relay Ingestion
    mesh_data = {
        "relay_node_id": "GUARDIAN_NODE_88",
        "hop_count": 2,
        "origin_user_id": "usr_mesh_77",
        "encrypted_payload_base64": "SGVsbG8gYlNhZmUgT2ZmbGluZSBNZXNoIEJlYWNvbg==",
        "latitude": 28.6140,
        "longitude": 77.2095,
        "trigger_type": "BLE_MESH_RELAY",
        "nostr_event_id": "nostr_ev_1001"
    }
    mesh_res = make_post("/api/v1/mesh/relay", mesh_data)
    print(f"\n[6/6] Bitchat Offline Mesh Relay Ingested:")
    print(f"      Status: {mesh_res['relay_status']} | Hops Remaining: {mesh_res['hops_remaining']}")
    print(f"      Nostr Relay Broadcast Confirmed: {mesh_res['nostr_broadcast_confirmed']}")
    
    print("\n" + "=" * 60)
    print(" [OK] PROGRAM SIMULATION EXECUTED SUCCESSFULLY")
    print("=" * 60)

if __name__ == "__main__":
    main()
