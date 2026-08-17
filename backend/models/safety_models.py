"""
Pydantic data models for the Gamified Safety Contribution Module.
Contains SafetiPin 9-parameter audit schemas, Gamification Profile,
Points Ledger, Badges, and Leaderboard schemas.
"""

from enum import Enum
from typing import List, Optional, Dict, Any
from pydantic import BaseModel, Field
from datetime import datetime

class CrowdDensity(str, Enum):
    NONE = "NONE"
    FEW = "FEW"
    MODERATE = "MODERATE"
    CROWDED = "CROWDED"

class SecurityPresence(str, Enum):
    YES_FREQUENT = "YES_FREQUENT"
    YES_OCCASIONAL = "YES_OCCASIONAL"
    NO = "NO"

class TimeOfDay(str, Enum):
    DAY = "DAY"
    EVENING = "EVENING"
    NIGHT = "NIGHT"

class CategoryTag(str, Enum):
    STREET = "STREET"
    PARK = "PARK"
    BUS_STOP = "BUS_STOP"
    MARKET = "MARKET"
    PARKING_LOT = "PARKING_LOT"
    METRO_STATION = "METRO_STATION"
    ISOLATED_STRETCH = "ISOLATED_STRETCH"

class AuditCreateRequest(BaseModel):
    user_id: str
    latitude: float = Field(..., ge=-90.0, le=90.0)
    longitude: float = Field(..., ge=-180.0, le=180.0)
    address_label: Optional[str] = "Unknown Location"
    category_tag: CategoryTag = CategoryTag.STREET
    time_of_day: TimeOfDay = TimeOfDay.DAY
    
    # 9 SafetiPin Core Parameters (1-5 scale or enum)
    lighting: int = Field(..., ge=1, le=5)
    openness: int = Field(..., ge=1, le=5)
    visibility: int = Field(..., ge=1, le=5)
    crowd: CrowdDensity = CrowdDensity.MODERATE
    security: SecurityPresence = SecurityPresence.YES_OCCASIONAL
    walk_path: int = Field(..., ge=1, le=5)
    public_transport: int = Field(..., ge=1, le=5)
    gender_diversity: int = Field(..., ge=1, le=5)
    feeling: int = Field(..., ge=1, le=5, description="1=Very Unsafe, 5=Very Safe")
    
    comment: Optional[str] = Field(None, max_length=280)
    photo_url: Optional[str] = None
    is_first_location_audit: bool = False

class AuditResponse(BaseModel):
    id: str
    user_id: str
    location_id: str
    latitude: float
    longitude: float
    address_label: str
    category_tag: str
    time_of_day: str
    lighting: int
    openness: int
    visibility: int
    crowd: str
    security: str
    walk_path: int
    public_transport: int
    gender_diversity: int
    feeling: int
    comment: Optional[str]
    photo_url: Optional[str]
    points_awarded: int
    upvotes: int
    status: str
    created_at: datetime

class SafetyParameterBreakdown(BaseModel):
    lighting_avg: float
    openness_avg: float
    visibility_avg: float
    crowd_avg_score: float
    security_avg_score: float
    walk_path_avg: float
    public_transport_avg: float
    gender_diversity_avg: float
    feeling_avg: float

class LocationDetailResponse(BaseModel):
    id: str
    latitude: float
    longitude: float
    address_label: str
    category_tag: str
    safety_score: float = Field(..., ge=1.0, le=5.0)
    score_color: str  # GREEN, AMBER, RED
    audit_count: int
    created_at: datetime
    breakdown: SafetyParameterBreakdown
    recent_audits: List[AuditResponse]

class UserBadgeResponse(BaseModel):
    badge_id: str
    name: str
    description: str
    icon: str
    earned_at: datetime

class PointsLedgerEntry(BaseModel):
    id: str
    user_id: str
    audit_id: Optional[str]
    action_type: str
    points: int
    created_at: datetime

class UserGamificationProfileResponse(BaseModel):
    user_id: str
    display_alias: str
    use_alias: bool
    total_points: int
    level: int
    level_title: str
    points_to_next_level: int
    streak_count: int
    last_audit_date: Optional[str]
    weekly_audits_count: int
    badges: List[UserBadgeResponse]
    recent_ledger: List[PointsLedgerEntry]

class LeaderboardEntryResponse(BaseModel):
    rank: int
    user_id: str
    display_name: str
    points: int
    level: int
    level_title: str
    badges_count: int
    streak_count: int
    city: str
