"""
SOS Triage Agent: Classifies multi-modal payloads into Tier 1 (Moderate distress)
or Tier 2 (Extreme distress) and builds contextual distress intelligence.
"""

from typing import Tuple
from backend.models import SOSTriggerRequest, SOSTriggerType, IncidentTier

class SOSTriageAgent:
    """Agentic SOS Triage Engine."""

    def triage_payload(self, request: SOSTriggerRequest) -> Tuple[IncidentTier, str]:
        reasons = []

        # Acoustic dB evaluation: >85 dB is extreme distress (Tier 2)
        if request.decibel_level >= 85.0:
            reasons.append(f"High decibel scream detected ({request.decibel_level:.1f} dB >= 85 dB threshold)")

        # Acoustic Hotword evaluation
        if request.hotword_detected:
            reasons.append(f"Acoustic distress hotword detected: '{request.hotword_detected}'")

        # Hardware Sequence / Duress PIN
        if request.trigger_type == SOSTriggerType.DURESS_PIN or request.duress_pin_used:
            reasons.append("Visual disguise neutralized via secondary Duress PIN (Silent Tier 2 Escalation)")

        if request.trigger_type == SOSTriggerType.HARDWARE_KEY_SEQUENCE:
            reasons.append("Stealth lock-screen physical key sequence triggered (VolUp->VolDown->VolUp)")

        # Recent Call Log Vector Resolution
        if request.recent_call_vector:
            reasons.append(f"Contextual Recent Call Log vector resolved: {request.recent_call_vector}")

        # Tier Decision Logic:
        # Tier 2 triggers: Decibel >= 85 dB, Duress PIN, or Acoustic Hotword
        if (request.decibel_level >= 85.0 or 
            request.trigger_type == SOSTriggerType.DURESS_PIN or 
            request.duress_pin_used or 
            request.hotword_detected in ["Help", "Bachao", "Save Me"]):
            tier = IncidentTier.TIER_2
        else:
            tier = IncidentTier.TIER_1

        summary = (
            f"[{tier.value}] Distress Payload Triage: {'; '.join(reasons) if reasons else request.trigger_type.value}. "
            f"Location: ({request.latitude:.4f}, {request.longitude:.4f})"
        )

        return tier, summary

sos_triage_agent = SOSTriageAgent()
