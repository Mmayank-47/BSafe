"""
Decoupled GamificationEngine service.
Listens to audit events, evaluates point rules, updates append-only points ledger,
calculates levels and badges, enforces anti-abuse policies, and recomputes
recency-weighted safety scores for locations.
"""

import math
from typing import Dict, List, Tuple, Optional
from datetime import datetime, timedelta
from backend.models import (
    AuditCreateRequest,
    CrowdDensity,
    SecurityPresence,
    TimeOfDay,
)

# Level definition table
LEVELS = [
    (1, "Explorer", 0),
    (2, "Scout", 150),
    (3, "Pathfinder", 400),
    (4, "Guardian", 900),
    (5, "Sentinel", 1800),
    (6, "Champion", 3500),
    (7, "Safety Hero", 6000),
]

# Badge definitions table
BADGES = {
    "NIGHT_OWL": {
        "id": "NIGHT_OWL",
        "name": "Night Owl",
        "description": "Completed 10 night-time safety audits",
        "icon": "🌙",
        "rule": lambda profile, audits: sum(1 for a in audits if a.get("time_of_day") == TimeOfDay.NIGHT or a.get("time_of_day") == "NIGHT") >= 10,
    },
    "NEIGHBORHOOD_MAPPER": {
        "id": "NEIGHBORHOOD_MAPPER",
        "name": "Neighborhood Mapper",
        "description": "Submitted 20 safety audits across the city",
        "icon": "📍",
        "rule": lambda profile, audits: len(audits) >= 20,
    },
    "FIRST_RESPONDER": {
        "id": "FIRST_RESPONDER",
        "name": "First Responder",
        "description": "First person to audit a new unmapped location",
        "icon": "⚡",
        "rule": lambda profile, audits: any(a.get("is_first_location_audit", False) for a in audits),
    },
    "CONSISTENCY_QUEEN": {
        "id": "CONSISTENCY_QUEEN",
        "name": "Consistency Queen",
        "description": "Maintained a 7-day consecutive daily audit streak",
        "icon": "🔥",
        "rule": lambda profile, audits: profile.get("streak_count", 0) >= 7,
    },
    "DETAIL_ORIENTED": {
        "id": "DETAIL_ORIENTED",
        "name": "Detail Oriented",
        "description": "Submitted 5 audits containing both photo evidence and detailed comments",
        "icon": "🔍",
        "rule": lambda profile, audits: sum(1 for a in audits if a.get("photo_url") and a.get("comment")) >= 5,
    },
}

class GamificationEngine:
    @staticmethod
    def compute_level(total_points: int) -> Tuple[int, str, int]:
        """
        Returns (level, title, points_needed_for_next_level).
        """
        current_level = 1
        current_title = "Explorer"
        next_points = 150

        for i, (lvl, title, pts_req) in enumerate(LEVELS):
            if total_points >= pts_req:
                current_level = lvl
                current_title = title
                if i + 1 < len(LEVELS):
                    next_points = LEVELS[i + 1][2] - total_points
                else:
                    next_points = 0
            else:
                break

        return current_level, current_title, max(0, next_points)

    @staticmethod
    def calculate_audit_points(
        request: AuditCreateRequest,
        is_first_audit: bool,
        daily_points_so_far: int,
    ) -> Tuple[int, List[Tuple[str, int]]]:
        """
        Calculates audit points break-down according to rules.
        Enforces 200 pts/day cap.
        """
        breakdown = []
        
        # 1. Base audit points (9 parameters filled = full audit)
        breakdown.append(("Full Audit Completed", 50))
        
        # 2. Photo bonus
        if request.photo_url:
            breakdown.append(("Photo Evidence Added", 10))
            
        # 3. Comment bonus
        if request.comment and len(request.comment.strip()) > 0:
            breakdown.append(("Detailed Comment Added", 5))
            
        # 4. First audit of unmapped location bonus
        if is_first_audit:
            breakdown.append(("First Location Audit Bonus", 25))
            
        raw_sum = sum(pts for _, pts in breakdown)
        
        # Enforce 200 pts/day anti-abuse cap
        remaining_daily_allowance = max(0, 200 - daily_points_so_far)
        final_points = min(raw_sum, remaining_daily_allowance)
        
        return final_points, breakdown

    @staticmethod
    def calculate_recency_weighted_score(audits: List[dict]) -> float:
        """
        Calculates recency-weighted safety score (1.0 to 5.0).
        Audits decay exponentially with age: weight = exp(-0.05 * age_days).
        """
        if not audits:
            return 3.0

        total_weight = 0.0
        weighted_score_sum = 0.0
        now = datetime.utcnow()

        for audit in audits:
            # Convert created_at
            created_at = audit.get("created_at")
            if isinstance(created_at, str):
                try:
                    created_at = datetime.fromisoformat(created_at)
                except Exception:
                    created_at = now
            elif not isinstance(created_at, datetime):
                created_at = now

            age_days = max(0.0, (now - created_at).total_seconds() / 86400.0)
            recency_weight = math.exp(-0.05 * age_days)
            quality_multiplier = 1.0 + (0.15 if audit.get("photo_url") else 0.0) + (0.10 if audit.get("comment") else 0.0)
            weight = recency_weight * quality_multiplier

            # Map parameters to numerical 1-5 values
            crowd_score = {"NONE": 1.0, "FEW": 2.0, "MODERATE": 4.0, "CROWDED": 5.0}.get(
                str(audit.get("crowd")), 3.0
            )
            security_score = {"YES_FREQUENT": 5.0, "YES_OCCASIONAL": 3.5, "NO": 1.0}.get(
                str(audit.get("security")), 2.5
            )

            param_avg = (
                float(audit.get("lighting", 3))
                + float(audit.get("openness", 3))
                + float(audit.get("visibility", 3))
                + crowd_score
                + security_score
                + float(audit.get("walk_path", 3))
                + float(audit.get("public_transport", 3))
                + float(audit.get("gender_diversity", 3))
                + float(audit.get("feeling", 3))
            ) / 9.0

            weighted_score_sum += param_avg * weight
            total_weight += weight

        if total_weight == 0.0:
            return 3.0

        final_score = weighted_score_sum / total_weight
        return round(max(1.0, min(5.0, final_score)), 1)

    @staticmethod
    def get_score_color(score: float) -> str:
        if score >= 4.0:
            return "GREEN"
        elif score >= 3.0:
            return "AMBER"
        else:
            return "RED"
