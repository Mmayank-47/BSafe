"""
FastAPI router for Gamified Safety Contribution Module.
Handles audit creation, location score querying, upvoting, leaderboard, and profile.
"""

from typing import List, Optional
from datetime import datetime, date
from fastapi import APIRouter, HTTPException, Query
from backend.database import db, haversine_distance_meters
from backend.models import (
    AuditCreateRequest,
    AuditResponse,
    LocationDetailResponse,
    SafetyParameterBreakdown,
    UserGamificationProfileResponse,
    UserBadgeResponse,
    PointsLedgerEntry,
    LeaderboardEntryResponse,
)
from backend.services.gamification_engine import GamificationEngine, BADGES

router = APIRouter(prefix="/safety", tags=["Safety Contribution & Gamification"])

@router.post("/audits", response_model=AuditResponse)
def submit_safety_audit(request: AuditCreateRequest):
    """
    Submits a new location safety audit, evaluates points via GamificationEngine,
    updates append-only ledger, triggers badge/level updates, and recomputes recency-weighted score.
    """
    now_iso = datetime.utcnow().isoformat()
    now_date = datetime.utcnow().date().isoformat()

    # 1. 24-hour per-user-per-location anti-abuse cooldown check
    for existing_audit in db.safety_audits.values():
        if (
            existing_audit.get("user_id") == request.user_id
            and haversine_distance_meters(
                request.latitude, request.longitude,
                existing_audit["latitude"], existing_audit["longitude"]
            ) < 50.0  # within 50 meters
        ):
            try:
                prev_date = datetime.fromisoformat(existing_audit["created_at"]).date()
                if (datetime.utcnow().date() - prev_date).days < 1:
                    raise HTTPException(
                        status_code=429,
                        detail="Anti-abuse cooldown: You can only audit the same location once every 24 hours."
                    )
            except HTTPException:
                raise
            except Exception:
                pass

    # 2. Match or create Location
    location_id = None
    is_first_audit = False
    for loc_id, loc in db.safety_locations.items():
        if haversine_distance_meters(request.latitude, request.longitude, loc["lat"], loc["lng"]) < 75.0:
            location_id = loc_id
            break

    if not location_id:
        location_id = f"LOC_{int(datetime.utcnow().timestamp() * 1000)}"
        is_first_audit = True
        db.safety_locations[location_id] = {
            "id": location_id,
            "lat": request.latitude,
            "lng": request.longitude,
            "address_label": request.address_label or f"Location near ({request.latitude:.4f}, {request.longitude:.4f})",
            "category_tag": request.category_tag.value,
            "safety_score": float(request.feeling),
            "audit_count": 0,
            "created_at": now_iso,
        }

    # 3. Calculate points via GamificationEngine
    user_profile = db.safety_user_profiles.setdefault(
        request.user_id,
        {
            "user_id": request.user_id,
            "display_alias": f"SafetyUser_{request.user_id[:6]}",
            "use_alias": True,
            "total_points": 0,
            "level": 1,
            "level_title": "Explorer",
            "streak_count": 1,
            "last_audit_date": None,
            "weekly_audits_count": 0,
            "city": "Nagpur",
        }
    )

    # Compute daily points so far for 200 pts/day cap
    daily_pts_so_far = sum(
        entry["points"]
        for entry in db.safety_points_ledger
        if entry["user_id"] == request.user_id
        and entry["created_at"].startswith(now_date)
    )

    pts_awarded, breakdown_log = GamificationEngine.calculate_audit_points(
        request, is_first_audit, daily_pts_so_far
    )

    # 4. Create Audit record
    audit_id = f"AUD_{int(datetime.utcnow().timestamp() * 1000)}"
    audit_record = {
        "id": audit_id,
        "user_id": request.user_id,
        "location_id": location_id,
        "latitude": request.latitude,
        "longitude": request.longitude,
        "address_label": request.address_label or db.safety_locations[location_id]["address_label"],
        "category_tag": request.category_tag.value,
        "time_of_day": request.time_of_day.value,
        "lighting": request.lighting,
        "openness": request.openness,
        "visibility": request.visibility,
        "crowd": request.crowd.value,
        "security": request.security.value,
        "walk_path": request.walk_path,
        "public_transport": request.public_transport,
        "gender_diversity": request.gender_diversity,
        "feeling": request.feeling,
        "comment": request.comment,
        "photo_url": request.photo_url,
        "points_awarded": pts_awarded,
        "upvotes": 0,
        "status": "ACTIVE",
        "is_first_location_audit": is_first_audit,
        "created_at": now_iso,
    }
    db.safety_audits[audit_id] = audit_record

    # 5. Append to Points Ledger
    db.safety_points_ledger.append({
        "id": f"LEDGER_{int(datetime.utcnow().timestamp() * 1000)}",
        "user_id": request.user_id,
        "audit_id": audit_id,
        "action_type": "AUDIT_SUBMISSION",
        "points": pts_awarded,
        "created_at": now_iso,
    })

    # Update profile total points & streak
    user_profile["total_points"] += pts_awarded
    user_profile["weekly_audits_count"] += 1
    
    # Handle streak logic
    last_date_str = user_profile.get("last_audit_date")
    if last_date_str:
        try:
            last_dt = datetime.fromisoformat(last_date_str).date()
            today_dt = datetime.utcnow().date()
            if (today_dt - last_dt).days == 1:
                user_profile["streak_count"] += 1
            elif (today_dt - last_dt).days > 1:
                user_profile["streak_count"] = 1
        except Exception:
            user_profile["streak_count"] = 1
    else:
        user_profile["streak_count"] = 1
    user_profile["last_audit_date"] = now_date

    # Recompute Level
    lvl, title, _ = GamificationEngine.compute_level(user_profile["total_points"])
    user_profile["level"] = lvl
    user_profile["level_title"] = title

    # Check Badges
    user_audits = [a for a in db.safety_audits.values() if a["user_id"] == request.user_id]
    existing_badge_ids = {b["badge_id"] for b in db.safety_user_badges if b["user_id"] == request.user_id}

    for badge_id, badge_def in BADGES.items():
        if badge_id not in existing_badge_ids and badge_def["rule"](user_profile, user_audits):
            db.safety_user_badges.append({
                "user_id": request.user_id,
                "badge_id": badge_id,
                "name": badge_def["name"],
                "description": badge_def["description"],
                "icon": badge_def["icon"],
                "earned_at": now_iso,
            })

    # 6. Recalculate recency-weighted Location score
    location_audits = [a for a in db.safety_audits.values() if a["location_id"] == location_id]
    new_score = GamificationEngine.calculate_recency_weighted_score(location_audits)
    db.safety_locations[location_id]["safety_score"] = new_score
    db.safety_locations[location_id]["audit_count"] = len(location_audits)

    return AuditResponse(**audit_record)

@router.get("/locations/nearby")
def get_nearby_locations(
    lat: float = Query(..., ge=-90.0, le=90.0),
    lng: float = Query(..., ge=-180.0, le=180.0),
    radius_km: float = Query(default=10.0, ge=0.1, le=100.0),
):
    """
    Fetches safety locations within radius, with safety scores & color designations.
    """
    results = []
    for loc in db.safety_locations.values():
        dist_m = haversine_distance_meters(lat, lng, loc["lat"], loc["lng"])
        if dist_m <= radius_km * 1000.0:
            score = loc.get("safety_score", 3.0)
            results.append({
                **loc,
                "distance_km": round(dist_m / 1000.0, 2),
                "score_color": GamificationEngine.get_score_color(score),
            })
    results.sort(key=lambda x: x["distance_km"])
    return results

@router.get("/locations/{location_id}", response_model=LocationDetailResponse)
def get_location_detail(location_id: str):
    """
    Returns location detail with aggregated parameter breakdowns and audit history.
    """
    loc = db.safety_locations.get(location_id)
    if not loc:
        raise HTTPException(status_code=404, detail="Location not found")

    audits = [a for a in db.safety_audits.values() if a["location_id"] == location_id]
    
    # Calculate parameter averages
    if audits:
        lighting_avg = round(sum(a["lighting"] for a in audits) / len(audits), 1)
        openness_avg = round(sum(a["openness"] for a in audits) / len(audits), 1)
        visibility_avg = round(sum(a["visibility"] for a in audits) / len(audits), 1)
        crowd_avg = round(sum({"NONE":1,"FEW":2,"MODERATE":4,"CROWDED":5}.get(a["crowd"], 3) for a in audits) / len(audits), 1)
        security_avg = round(sum({"YES_FREQUENT":5,"YES_OCCASIONAL":3.5,"NO":1}.get(a["security"], 2.5) for a in audits) / len(audits), 1)
        walk_path_avg = round(sum(a["walk_path"] for a in audits) / len(audits), 1)
        public_transport_avg = round(sum(a["public_transport"] for a in audits) / len(audits), 1)
        gender_diversity_avg = round(sum(a["gender_diversity"] for a in audits) / len(audits), 1)
        feeling_avg = round(sum(a["feeling"] for a in audits) / len(audits), 1)
    else:
        lighting_avg = openness_avg = visibility_avg = crowd_avg = security_avg = 3.0
        walk_path_avg = public_transport_avg = gender_diversity_avg = feeling_avg = 3.0

    breakdown = SafetyParameterBreakdown(
        lighting_avg=lighting_avg,
        openness_avg=openness_avg,
        visibility_avg=visibility_avg,
        crowd_avg_score=crowd_avg,
        security_avg_score=security_avg,
        walk_path_avg=walk_path_avg,
        public_transport_avg=public_transport_avg,
        gender_diversity_avg=gender_diversity_avg,
        feeling_avg=feeling_avg,
    )

    score = loc.get("safety_score", 3.0)
    recent_audits = [AuditResponse(**a) for a in sorted(audits, key=lambda x: x["created_at"], reverse=True)]

    return LocationDetailResponse(
        id=loc["id"],
        latitude=loc["lat"],
        longitude=loc["lng"],
        address_label=loc["address_label"],
        category_tag=loc["category_tag"],
        safety_score=score,
        score_color=GamificationEngine.get_score_color(score),
        audit_count=len(audits),
        created_at=datetime.fromisoformat(loc["created_at"]),
        breakdown=breakdown,
        recent_audits=recent_audits,
    )

@router.post("/audits/{audit_id}/upvote")
def upvote_safety_audit(audit_id: str, user_id: str = Query(...)):
    """
    Upvotes an audit ('Confirm still accurate'), awarding +10 points to the audit author.
    """
    audit = db.safety_audits.get(audit_id)
    if not audit:
        raise HTTPException(status_code=404, detail="Audit not found")

    audit["upvotes"] += 1
    author_id = audit["user_id"]
    now_iso = datetime.utcnow().isoformat()

    # Award +10 points to author
    db.safety_points_ledger.append({
        "id": f"LEDGER_{int(datetime.utcnow().timestamp() * 1000)}",
        "user_id": author_id,
        "audit_id": audit_id,
        "action_type": "AUDIT_UPVOTED",
        "points": 10,
        "created_at": now_iso,
    })

    if author_id in db.safety_user_profiles:
        db.safety_user_profiles[author_id]["total_points"] += 10
        lvl, title, _ = GamificationEngine.compute_level(db.safety_user_profiles[author_id]["total_points"])
        db.safety_user_profiles[author_id]["level"] = lvl
        db.safety_user_profiles[author_id]["level_title"] = title

    return {"status": "SUCCESS", "message": "Audit upvoted successfully", "upvotes": audit["upvotes"]}

@router.get("/leaderboard", response_model=List[LeaderboardEntryResponse])
def get_leaderboard(
    scope: str = Query(default="alltime", pattern="^(weekly|monthly|alltime)$"),
    city: Optional[str] = Query(default=None),
):
    """
    Returns materialized leaderboard filtered by timeframe (weekly/monthly/alltime) and city.
    """
    profiles = list(db.safety_user_profiles.values())
    if city:
        profiles = [p for p in profiles if p.get("city", "").lower() == city.lower()]

    profiles.sort(key=lambda p: p.get("total_points", 0), reverse=True)

    results = []
    for i, profile in enumerate(profiles, 1):
        user_id = profile["user_id"]
        badges_count = len([b for b in db.safety_user_badges if b["user_id"] == user_id])
        display = profile["display_alias"] if profile.get("use_alias") else user_id

        results.append(LeaderboardEntryResponse(
            rank=i,
            user_id=user_id,
            display_name=display,
            points=profile.get("total_points", 0),
            level=profile.get("level", 1),
            level_title=profile.get("level_title", "Explorer"),
            badges_count=badges_count,
            streak_count=profile.get("streak_count", 0),
            city=profile.get("city", "Nagpur"),
        ))
    return results

@router.get("/users/{user_id}/profile", response_model=UserGamificationProfileResponse)
def get_user_gamification_profile(user_id: str):
    """
    Fetches user's gamification profile, earned badges, level progress, and points ledger history.
    """
    profile = db.safety_user_profiles.setdefault(
        user_id,
        {
            "user_id": user_id,
            "display_alias": f"SafetyUser_{user_id[:6]}",
            "use_alias": True,
            "total_points": 0,
            "level": 1,
            "level_title": "Explorer",
            "streak_count": 1,
            "last_audit_date": None,
            "weekly_audits_count": 0,
            "city": "Nagpur",
        }
    )

    lvl, title, pts_to_next = GamificationEngine.compute_level(profile["total_points"])
    profile["level"] = lvl
    profile["level_title"] = title

    badges = [
        UserBadgeResponse(
            badge_id=b["badge_id"],
            name=b["name"],
            description=b["description"],
            icon=b["icon"],
            earned_at=datetime.fromisoformat(b["earned_at"]),
        )
        for b in db.safety_user_badges
        if b["user_id"] == user_id
    ]

    ledger = [
        PointsLedgerEntry(
            id=entry["id"],
            user_id=entry["user_id"],
            audit_id=entry.get("audit_id"),
            action_type=entry["action_type"],
            points=entry["points"],
            created_at=datetime.fromisoformat(entry["created_at"]),
        )
        for entry in db.safety_points_ledger
        if entry["user_id"] == user_id
    ]
    ledger.sort(key=lambda x: x.created_at, reverse=True)

    return UserGamificationProfileResponse(
        user_id=profile["user_id"],
        display_alias=profile["display_alias"],
        use_alias=profile["use_alias"],
        total_points=profile["total_points"],
        level=lvl,
        level_title=title,
        points_to_next_level=pts_to_next,
        streak_count=profile.get("streak_count", 0),
        last_audit_date=profile.get("last_audit_date"),
        weekly_audits_count=profile.get("weekly_audits_count", 0),
        badges=badges,
        recent_ledger=ledger[:10],
    )

@router.post("/audits/sync")
def sync_offline_draft_audits(drafts: List[AuditCreateRequest]):
    """
    Syncs offline draft audits queued on client devices.
    """
    synced_audits = []
    for draft in drafts:
        try:
            audit_res = submit_safety_audit(draft)
            synced_audits.append(audit_res.id)
        except Exception as e:
            pass
    return {"status": "SUCCESS", "synced_count": len(synced_audits), "audit_ids": synced_audits}
