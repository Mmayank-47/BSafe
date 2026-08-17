"""
Closed-Loop SLA Agent: Tracks incident state machine (OPEN -> DISPATCHED -> ACKNOWLEDGED -> RESOLVED).
If an assigned responder fails to acknowledge within 45s, dynamically expands spatial search radius
and escalates incident priority.
"""

from typing import Dict, List, Optional
from datetime import datetime
from backend.database import db
from backend.models import IncidentStatus

class ClosedLoopSLAAgent:
    """Agentic Incident SLA & Escalation Manager."""

    def evaluate_open_slas(self, sla_timeout_seconds: int = 45) -> List[dict]:
        escalated_incidents = []
        now = datetime.utcnow()

        for inc_id, inc in list(db.incidents.items()):
            if inc["status"] in [IncidentStatus.OPEN, IncidentStatus.DISPATCHED]:
                created_at = datetime.fromisoformat(inc["created_at"])
                elapsed = (now - created_at).total_seconds()

                if elapsed >= sla_timeout_seconds:
                    # Expand spatial search radius to 5000 meters for escalation
                    expanded_responders = db.find_nearby_responders(
                        inc["latitude"], inc["longitude"], radius_meters=5000.0
                    )
                    escalated = db.escalate_incident(inc_id, expanded_responders)
                    if escalated:
                        escalated_incidents.append(escalated)

        return escalated_incidents

closed_loop_sla_agent = ClosedLoopSLAAgent()
