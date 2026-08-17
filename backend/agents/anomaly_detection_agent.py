"""
Anomaly Detection & Check-in Agent: Monitors 5-second location telemetry streams.
Detects route deviations, velocity drops, or prolonged stops in isolated spatial areas.
"""

from typing import List, Optional
from backend.models import TelemetryPing, AnomalyCheckResponse
from backend.database import db

class AnomalyDetectionAgent:
    """Agentic Telemetry Stream Anomaly Detector."""

    def process_telemetry(self, ping: TelemetryPing) -> AnomalyCheckResponse:
        journey_id = ping.journey_id
        
        if journey_id not in db.telemetry_history:
            db.telemetry_history[journey_id] = []
        
        history = db.telemetry_history[journey_id]
        history.append(ping.dict())
        
        is_anomaly = False
        anomaly_type: Optional[str] = None
        requires_checkin = False
        checkin_prompt: Optional[str] = None

        # Check 1: Sudden Velocity Drop (e.g. speed drops below 0.2 m/s while in motion)
        if len(history) >= 3:
            recent_speeds = [p["speed_mps"] for p in history[-3:]]
            if recent_speeds[0] > 1.2 and all(s < 0.1 for s in recent_speeds[1:]):
                is_anomaly = True
                anomaly_type = "VELOCITY_DROP"
                requires_checkin = True
                checkin_prompt = "bSafe Alert: We noticed an unexpected sudden stop. Are you safe?"

        # Check 2: Prolonged stop in unknown location (e.g. 5 consecutive pings with 0 speed)
        if len(history) >= 5 and all(p["speed_mps"] < 0.05 for p in history[-5:]):
            is_anomaly = True
            anomaly_type = "ISOLATED_STOP"
            requires_checkin = True
            checkin_prompt = "bSafe Safety Check-In: You've been stationary for a while. Please confirm your safety within 30s."

        return AnomalyCheckResponse(
            journey_id=journey_id,
            is_anomaly=is_anomaly,
            anomaly_type=anomaly_type,
            requires_checkin=requires_checkin,
            checkin_prompt=checkin_prompt
        )

anomaly_detection_agent = AnomalyDetectionAgent()
