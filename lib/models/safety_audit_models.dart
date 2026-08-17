import 'package:flutter/material.dart';

enum CrowdDensity { none, few, moderate, crowded }
enum SecurityPresence { yesFrequent, yesOccasional, no }
enum TimeOfDayPeriod { day, evening, night }

enum CategoryTag {
  street,
  park,
  busStop,
  market,
  parkingLot,
  metroStation,
  isolatedStretch,
}

extension CategoryTagExtension on CategoryTag {
  String get displayName {
    switch (this) {
      case CategoryTag.street:
        return 'Street';
      case CategoryTag.park:
        return 'Park';
      case CategoryTag.busStop:
        return 'Bus Stop';
      case CategoryTag.market:
        return 'Market';
      case CategoryTag.parkingLot:
        return 'Parking Lot';
      case CategoryTag.metroStation:
        return 'Metro Station';
      case CategoryTag.isolatedStretch:
        return 'Isolated Stretch';
    }
  }

  IconData get icon {
    switch (this) {
      case CategoryTag.street:
        return Icons.add_road_rounded;
      case CategoryTag.park:
        return Icons.park_rounded;
      case CategoryTag.busStop:
        return Icons.directions_bus_rounded;
      case CategoryTag.market:
        return Icons.storefront_rounded;
      case CategoryTag.parkingLot:
        return Icons.local_parking_rounded;
      case CategoryTag.metroStation:
        return Icons.subway_rounded;
      case CategoryTag.isolatedStretch:
        return Icons.warning_amber_rounded;
    }
  }
}

class SafetyLocation {
  final String id;
  final double latitude;
  final double longitude;
  final String addressLabel;
  final String categoryTag;
  final double safetyScore;
  final String scoreColor; // GREEN, AMBER, RED
  final int auditCount;

  SafetyLocation({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.addressLabel,
    required this.categoryTag,
    required this.safetyScore,
    required this.scoreColor,
    required this.auditCount,
  });

  factory SafetyLocation.fromJson(Map<String, dynamic> json) {
    return SafetyLocation(
      id: json['id'] ?? '',
      latitude: (json['lat'] ?? json['latitude'] as num).toDouble(),
      longitude: (json['lng'] ?? json['longitude'] as num).toDouble(),
      addressLabel: json['address_label'] ?? 'Unknown Location',
      categoryTag: json['category_tag'] ?? 'STREET',
      safetyScore: (json['safety_score'] as num? ?? 3.0).toDouble(),
      scoreColor: json['score_color'] ?? 'AMBER',
      auditCount: json['audit_count'] ?? 0,
    );
  }

  Color get color {
    if (scoreColor == 'GREEN' || safetyScore >= 4.0) {
      return const Color(0xFF10B981);
    } else if (scoreColor == 'AMBER' || safetyScore >= 3.0) {
      return const Color(0xFFF59E0B);
    } else {
      return const Color(0xFFEF4444);
    }
  }
}

class SafetyParameterBreakdown {
  final double lightingAvg;
  final double opennessAvg;
  final double visibilityAvg;
  final double crowdAvgScore;
  final double securityAvgScore;
  final double walkPathAvg;
  final double publicTransportAvg;
  final double genderDiversityAvg;
  final double feelingAvg;

  SafetyParameterBreakdown({
    required this.lightingAvg,
    required this.opennessAvg,
    required this.visibilityAvg,
    required this.crowdAvgScore,
    required this.securityAvgScore,
    required this.walkPathAvg,
    required this.publicTransportAvg,
    required this.genderDiversityAvg,
    required this.feelingAvg,
  });

  factory SafetyParameterBreakdown.fromJson(Map<String, dynamic> json) {
    return SafetyParameterBreakdown(
      lightingAvg: (json['lighting_avg'] as num? ?? 3.0).toDouble(),
      opennessAvg: (json['openness_avg'] as num? ?? 3.0).toDouble(),
      visibilityAvg: (json['visibility_avg'] as num? ?? 3.0).toDouble(),
      crowdAvgScore: (json['crowd_avg_score'] as num? ?? 3.0).toDouble(),
      securityAvgScore: (json['security_avg_score'] as num? ?? 3.0).toDouble(),
      walkPathAvg: (json['walk_path_avg'] as num? ?? 3.0).toDouble(),
      publicTransportAvg: (json['public_transport_avg'] as num? ?? 3.0).toDouble(),
      genderDiversityAvg: (json['gender_diversity_avg'] as num? ?? 3.0).toDouble(),
      feelingAvg: (json['feeling_avg'] as num? ?? 3.0).toDouble(),
    );
  }
}

class SafetyAudit {
  final String id;
  final String userId;
  final String locationId;
  final double latitude;
  final double longitude;
  final String addressLabel;
  final String categoryTag;
  final String timeOfDay;
  final int lighting;
  final int openness;
  final int visibility;
  final String crowd;
  final String security;
  final int walkPath;
  final int publicTransport;
  final int genderDiversity;
  final int feeling;
  final String? comment;
  final String? photoUrl;
  final int pointsAwarded;
  final int upvotes;
  final DateTime createdAt;

  SafetyAudit({
    required this.id,
    required this.userId,
    required this.locationId,
    required this.latitude,
    required this.longitude,
    required this.addressLabel,
    required this.categoryTag,
    required this.timeOfDay,
    required this.lighting,
    required this.openness,
    required this.visibility,
    required this.crowd,
    required this.security,
    required this.walkPath,
    required this.publicTransport,
    required this.genderDiversity,
    required this.feeling,
    this.comment,
    this.photoUrl,
    required this.pointsAwarded,
    required this.upvotes,
    required this.createdAt,
  });

  factory SafetyAudit.fromJson(Map<String, dynamic> json) {
    return SafetyAudit(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      locationId: json['location_id'] ?? '',
      latitude: (json['latitude'] as num? ?? 0.0).toDouble(),
      longitude: (json['longitude'] as num? ?? 0.0).toDouble(),
      addressLabel: json['address_label'] ?? '',
      categoryTag: json['category_tag'] ?? 'STREET',
      timeOfDay: json['time_of_day'] ?? 'DAY',
      lighting: json['lighting'] ?? 3,
      openness: json['openness'] ?? 3,
      visibility: json['visibility'] ?? 3,
      crowd: json['crowd'] ?? 'MODERATE',
      security: json['security'] ?? 'YES_OCCASIONAL',
      walkPath: json['walk_path'] ?? 3,
      publicTransport: json['public_transport'] ?? 3,
      genderDiversity: json['gender_diversity'] ?? 3,
      feeling: json['feeling'] ?? 3,
      comment: json['comment'],
      photoUrl: json['photo_url'],
      pointsAwarded: json['points_awarded'] ?? 0,
      upvotes: json['upvotes'] ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }
}

class UserBadge {
  final String badgeId;
  final String name;
  final String description;
  final String icon;
  final DateTime earnedAt;

  UserBadge({
    required this.badgeId,
    required this.name,
    required this.description,
    required this.icon,
    required this.earnedAt,
  });

  factory UserBadge.fromJson(Map<String, dynamic> json) {
    return UserBadge(
      badgeId: json['badge_id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      icon: json['icon'] ?? '🏅',
      earnedAt: json['earned_at'] != null
          ? DateTime.parse(json['earned_at'])
          : DateTime.now(),
    );
  }
}

class GamificationProfile {
  final String userId;
  final String displayAlias;
  final bool useAlias;
  final int totalPoints;
  final int level;
  final String levelTitle;
  final int pointsToNextLevel;
  final int streakCount;
  final int weeklyAuditsCount;
  final List<UserBadge> badges;

  GamificationProfile({
    required this.userId,
    required this.displayAlias,
    required this.useAlias,
    required this.totalPoints,
    required this.level,
    required this.levelTitle,
    required this.pointsToNextLevel,
    required this.streakCount,
    required this.weeklyAuditsCount,
    required this.badges,
  });

  factory GamificationProfile.fromJson(Map<String, dynamic> json) {
    return GamificationProfile(
      userId: json['user_id'] ?? 'USER_DEMO_001',
      displayAlias: json['display_alias'] ?? 'SafetyExplorer',
      useAlias: json['use_alias'] ?? true,
      totalPoints: json['total_points'] ?? 0,
      level: json['level'] ?? 1,
      levelTitle: json['level_title'] ?? 'Explorer',
      pointsToNextLevel: json['points_to_next_level'] ?? 150,
      streakCount: json['streak_count'] ?? 1,
      weeklyAuditsCount: json['weekly_audits_count'] ?? 0,
      badges: (json['badges'] as List? ?? [])
          .map((b) => UserBadge.fromJson(b))
          .toList(),
    );
  }
}

class LeaderboardEntry {
  final int rank;
  final String userId;
  final String displayName;
  final int points;
  final int level;
  final String levelTitle;
  final int badgesCount;
  final int streakCount;
  final String city;

  LeaderboardEntry({
    required this.rank,
    required this.userId,
    required this.displayName,
    required this.points,
    required this.level,
    required this.levelTitle,
    required this.badgesCount,
    required this.streakCount,
    required this.city,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      rank: json['rank'] ?? 1,
      userId: json['user_id'] ?? '',
      displayName: json['display_name'] ?? 'Anonymous',
      points: json['points'] ?? 0,
      level: json['level'] ?? 1,
      levelTitle: json['level_title'] ?? 'Explorer',
      badgesCount: json['badges_count'] ?? 0,
      streakCount: json['streak_count'] ?? 1,
      city: json['city'] ?? 'Nagpur',
    );
  }
}
