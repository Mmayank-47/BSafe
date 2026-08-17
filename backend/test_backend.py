"""
Comprehensive test suite for bSafe Agentic Real-Time Safety Gateway & Micro-Agents.
"""

import unittest
from fastapi.testclient import TestClient
from backend.main import app
from backend.database import db
from backend.models import IncidentStatus, IncidentTier

class TestBSafeBackend(unittest.TestCase):

    def setUp(self):
        self.client = TestClient(app)

    def test_health_check(self):
        response = self.client.get("/")
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(data["status"], "HEALTHY_OPERATIONAL")
        self.assertIn("RouteSafetyAgent", data["active_agents"])

    def test_01_auth_register_mandatory_contacts(self):
        payload = {
            "user_id": "usr_test_1001",
            "name": "Jane Doe",
            "phone_number": "+919876543210",
            "email": "jane@example.com",
            "emergency_contacts": [
                {
                    "name": "Mom",
                    "phone_number": "+919876543211",
                    "tier": "PRIMARY"
                },
                {
                    "name": "Sister",
                    "phone_number": "+919876543212",
                    "tier": "SECONDARY"
                }
            ]
        }
        response = self.client.post("/api/v1/auth/register", json=payload)
        self.assertEqual(response.status_code, 201)
        data = response.json()
        self.assertEqual(data["user_id"], "usr_test_1001")
        self.assertEqual(data["verified_contacts_count"], 2)

    def test_02_journey_start_risk_assessment(self):
        payload = {
            "user_id": "usr_test_1001",
            "origin": [28.6139, 77.2090],
            "destination": [28.6200, 77.2150],
            "mode": "WALKING"
        }
        response = self.client.post("/api/v1/journey/start", json=payload)
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertIn("journey_id", data)
        self.assertGreaterEqual(data["route_safety"]["overall_score"], 0.0)
        self.assertLessEqual(data["route_safety"]["overall_score"], 10.0)

    def test_03_sos_trigger_multi_modal_tier1(self):
        payload = {
            "user_id": "usr_test_1001",
            "trigger_type": "MANUAL_BUTTON",
            "latitude": 28.6139,
            "longitude": 77.2090,
            "decibel_level": 72.0,
            "recent_call_vector": "+919876543000"
        }
        response = self.client.post("/api/v1/sos/trigger", json=payload)
        self.assertEqual(response.status_code, 201)
        data = response.json()
        self.assertIn("incident_id", data)
        self.assertEqual(data["tier"], IncidentTier.TIER_1.value)
        self.assertGreater(len(data["assigned_responders"]), 0)

    def test_04_sos_trigger_multi_modal_tier2_scream(self):
        payload = {
            "user_id": "usr_test_1001",
            "trigger_type": "DECIBEL_SPIKE",
            "latitude": 28.6139,
            "longitude": 77.2090,
            "decibel_level": 92.5,  # >85 dB scream trigger
            "hotword_detected": "Bachao",
            "recent_call_vector": "+919876543000"
        }
        response = self.client.post("/api/v1/sos/trigger", json=payload)
        self.assertEqual(response.status_code, 201)
        data = response.json()
        self.assertEqual(data["tier"], IncidentTier.TIER_2.value)
        self.assertTrue(data["ivr_bridge_initiated"])

    def test_05_incident_acknowledge_sla(self):
        # Trigger an incident first
        payload = {
            "user_id": "usr_test_1001",
            "trigger_type": "MANUAL_BUTTON",
            "latitude": 28.6139,
            "longitude": 77.2090
        }
        trig_res = self.client.post("/api/v1/sos/trigger", json=payload).json()
        inc_id = trig_res["incident_id"]

        # Acknowledge incident via responder
        ack_payload = {
            "incident_id": inc_id,
            "responder_id": "RESP_001",
            "notes": "Units dispatched on scene"
        }
        ack_res = self.client.post(f"/api/v1/incidents/{inc_id}/acknowledge", json=ack_payload)
        self.assertEqual(ack_res.status_code, 200)
        self.assertEqual(ack_res.json()["status"], IncidentStatus.ACKNOWLEDGED.value)

    def test_06_offline_mesh_relay_ingestion(self):
        mesh_payload = {
            "relay_node_id": "GUARDIAN_NODE_77",
            "hop_count": 3,
            "origin_user_id": "usr_offline_99",
            "encrypted_payload_base64": "SGVsbG8gYlNhZmUgT2ZmbGluZSBNZXNoIEJlYWNvbg==",
            "latitude": 28.6140,
            "longitude": 77.2095,
            "trigger_type": "BLE_MESH_RELAY",
            "nostr_event_id": "nostr_ev_99901"
        }
        response = self.client.post("/api/v1/mesh/relay", json=mesh_payload)
        self.assertEqual(response.status_code, 202)
        data = response.json()
        self.assertEqual(data["relay_status"], "INGESTED_AND_BROADCAST")
        self.assertEqual(data["hops_remaining"], 4)

if __name__ == "__main__":
    unittest.main()
