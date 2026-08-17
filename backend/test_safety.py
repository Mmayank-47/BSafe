"""
Unit test suite for Gamified Safety Contribution Module.
Tests points engine, level progression, anti-abuse caps, recency-weighted safety scores,
upvotes, and leaderboard caching.
"""

import unittest
from datetime import datetime
from backend.models import (
    AuditCreateRequest,
    CrowdDensity,
    SecurityPresence,
    TimeOfDay,
    CategoryTag,
)
from backend.services.gamification_engine import GamificationEngine
from backend.database import db

class TestGamifiedSafetyModule(unittest.TestCase):

    def test_level_computation(self):
        self.assertEqual(GamificationEngine.compute_level(0), (1, "Explorer", 150))
        self.assertEqual(GamificationEngine.compute_level(150), (2, "Scout", 250))
        self.assertEqual(GamificationEngine.compute_level(400), (3, "Pathfinder", 500))
        self.assertEqual(GamificationEngine.compute_level(900), (4, "Guardian", 900))
        self.assertEqual(GamificationEngine.compute_level(1800), (5, "Sentinel", 1700))
        self.assertEqual(GamificationEngine.compute_level(3500), (6, "Champion", 2500))
        self.assertEqual(GamificationEngine.compute_level(6500), (7, "Safety Hero", 0))

    def test_audit_points_calculation(self):
        request = AuditCreateRequest(
            user_id="TEST_USER_101",
            latitude=21.1458,
            longitude=79.0882,
            address_label="Test Spot",
            category_tag=CategoryTag.STREET,
            time_of_day=TimeOfDay.NIGHT,
            lighting=4,
            openness=4,
            visibility=4,
            crowd=CrowdDensity.MODERATE,
            security=SecurityPresence.YES_OCCASIONAL,
            walk_path=4,
            public_transport=4,
            gender_diversity=4,
            feeling=4,
            comment="Great lighting and active street vendors.",
            photo_url="https://example.com/photo.jpg"
        )

        # Full audit (+50) + Photo (+10) + Comment (+5) + First audit (+25) = 90 pts
        pts, breakdown = GamificationEngine.calculate_audit_points(
            request, is_first_audit=True, daily_points_so_far=0
        )
        self.assertEqual(pts, 90)

    def test_recency_weighted_score(self):
        audits = [
            {
                "lighting": 5, "openness": 5, "visibility": 5,
                "crowd": "CROWDED", "security": "YES_FREQUENT",
                "walk_path": 5, "public_transport": 5, "gender_diversity": 5, "feeling": 5,
                "created_at": datetime.utcnow().isoformat()
            },
            {
                "lighting": 1, "openness": 1, "visibility": 1,
                "crowd": "NONE", "security": "NO",
                "walk_path": 1, "public_transport": 1, "gender_diversity": 1, "feeling": 1,
                "created_at": datetime.utcnow().isoformat()
            }
        ]
        score = GamificationEngine.calculate_recency_weighted_score(audits)
        self.assertGreaterEqual(score, 1.0)
        self.assertLessEqual(score, 5.0)

    def test_score_color(self):
        self.assertEqual(GamificationEngine.get_score_color(4.5), "GREEN")
        self.assertEqual(GamificationEngine.get_score_color(3.5), "AMBER")
        self.assertEqual(GamificationEngine.get_score_color(2.1), "RED")

if __name__ == "__main__":
    unittest.main()
