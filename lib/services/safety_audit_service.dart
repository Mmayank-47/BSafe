import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:safe/models/safety_audit_models.dart';
import 'package:safe/services/nagpur_safety_service.dart';

class SafetyAuditService {
  static final SafetyAuditService _instance = SafetyAuditService._internal();
  factory SafetyAuditService() => _instance;
  SafetyAuditService._internal();

  static const String baseUrl = 'http://127.0.0.1:8000/safety';
  static const String kOfflineDraftsKey = 'safety_offline_draft_audits';

  final StreamController<String> _eventStreamController =
      StreamController<String>.broadcast();
  Stream<String> get eventStream => _eventStreamController.stream;

  /// Fetch nearby safety locations with recency-weighted scores.
  Future<List<SafetyLocation>> fetchNearbyLocations({
    required double lat,
    required double lng,
    double radiusKm = 10.0,
  }) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/locations/nearby?lat=$lat&lng=$lng&radius_km=$radiusKm'))
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final List list = jsonDecode(response.body);
        return list.map((json) => SafetyLocation.fromJson(json)).toList();
      }
    } catch (e) {
      debugPrint('[SafetyAuditService] Fetch nearby fallback: $e');
    }

    // Offline / Fallback pre-seeded data
    return [
      SafetyLocation(
        id: 'LOC_NAGPUR_01',
        latitude: 21.1458,
        longitude: 79.0882,
        addressLabel: 'Sitabuldi Metro Station Entrance, Nagpur',
        categoryTag: 'METRO_STATION',
        safetyScore: 4.6,
        scoreColor: 'GREEN',
        auditCount: 12,
      ),
      SafetyLocation(
        id: 'LOC_NAGPUR_02',
        latitude: 21.1255,
        longitude: 79.0520,
        addressLabel: 'VNIT South Gate Walkway, Bajaj Nagar',
        categoryTag: 'ISOLATED_STRETCH',
        safetyScore: 2.4,
        scoreColor: 'RED',
        auditCount: 8,
      ),
      SafetyLocation(
        id: 'LOC_NAGPUR_03',
        latitude: 21.1500,
        longitude: 79.0800,
        addressLabel: 'Futala Lake Promenade, Nagpur',
        categoryTag: 'PARK',
        safetyScore: 3.8,
        scoreColor: 'AMBER',
        auditCount: 15,
      ),
    ];
  }

  /// Submit a new safety audit.
  Future<SafetyAudit?> submitAudit(Map<String, dynamic> auditData) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/audits'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(auditData),
          )
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final auditJson = jsonDecode(response.body);
        final audit = SafetyAudit.fromJson(auditJson);
        NagpurSafetyService().updateLocalityWithAudit(
          lat: (auditData['latitude'] as num? ?? 21.1458).toDouble(),
          lon: (auditData['longitude'] as num? ?? 79.0882).toDouble(),
          auditData: auditData,
        );
        _eventStreamController.add('AUDIT_SUBMITTED');
        return audit;
      }
    } catch (e) {
      debugPrint('[SafetyAuditService] Network error, drafting offline: $e');
      await queueOfflineDraft(auditData);
    }

    // Trigger local dynamic score update for smooth offline experience
    NagpurSafetyService().updateLocalityWithAudit(
      lat: (auditData['latitude'] as num? ?? 21.1458).toDouble(),
      lon: (auditData['longitude'] as num? ?? 79.0882).toDouble(),
      auditData: auditData,
    );

    // Return synthetic response for smooth offline UX
    final syntheticAudit = SafetyAudit(
      id: 'AUD_OFFLINE_${DateTime.now().millisecondsSinceEpoch}',
      userId: auditData['user_id'] ?? 'USER_DEMO_001',
      locationId: 'LOC_NEW',
      latitude: auditData['latitude'] ?? 21.1458,
      longitude: auditData['longitude'] ?? 79.0882,
      addressLabel: auditData['address_label'] ?? 'Offline Draft Location',
      categoryTag: auditData['category_tag'] ?? 'STREET',
      timeOfDay: auditData['time_of_day'] ?? 'DAY',
      lighting: auditData['lighting'] ?? 3,
      openness: auditData['openness'] ?? 3,
      visibility: auditData['visibility'] ?? 3,
      crowd: auditData['crowd'] ?? 'MODERATE',
      security: auditData['security'] ?? 'YES_OCCASIONAL',
      walkPath: auditData['walk_path'] ?? 3,
      publicTransport: auditData['public_transport'] ?? 3,
      genderDiversity: auditData['gender_diversity'] ?? 3,
      feeling: auditData['feeling'] ?? 3,
      comment: auditData['comment'],
      photoUrl: auditData['photo_url'],
      pointsAwarded: 65,
      upvotes: 0,
      createdAt: DateTime.now(),
    );

    _eventStreamController.add('AUDIT_DRAFTED_OFFLINE');
    return syntheticAudit;
  }

  /// Upvote an existing audit.
  Future<bool> upvoteAudit(String auditId, String userId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/audits/$auditId/upvote?user_id=$userId'),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[SafetyAuditService] Upvote error: $e');
      return true; // Optimistic UI
    }
  }

  /// Fetch user's gamification profile.
  Future<GamificationProfile> fetchUserProfile(String userId) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/users/$userId/profile'))
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        return GamificationProfile.fromJson(jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint('[SafetyAuditService] Profile fallback: $e');
    }

    return GamificationProfile(
      userId: userId,
      displayAlias: 'Safety Hero',
      useAlias: true,
      totalPoints: 450,
      level: 3,
      levelTitle: 'Pathfinder',
      pointsToNextLevel: 450,
      streakCount: 5,
      weeklyAuditsCount: 4,
      badges: [
        UserBadge(
          badgeId: 'NIGHT_OWL',
          name: 'Night Owl',
          description: 'Completed 10 night-time safety audits',
          icon: '🌙',
          earnedAt: DateTime.now(),
        ),
        UserBadge(
          badgeId: 'FIRST_RESPONDER',
          name: 'First Responder',
          description: 'First person to audit a new unmapped location',
          icon: '⚡',
          earnedAt: DateTime.now(),
        ),
      ],
    );
  }

  /// Fetch leaderboard.
  Future<List<LeaderboardEntry>> fetchLeaderboard({
    String scope = 'alltime',
    String? city,
  }) async {
    try {
      var url = '$baseUrl/leaderboard?scope=$scope';
      if (city != null) url += '&city=$city';

      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final List list = jsonDecode(response.body);
        return list.map((j) => LeaderboardEntry.fromJson(j)).toList();
      }
    } catch (e) {
      debugPrint('[SafetyAuditService] Leaderboard fallback: $e');
    }

    return [
      LeaderboardEntry(
        rank: 1,
        userId: 'USER_DEMO_001',
        displayName: 'Safety Hero',
        points: 450,
        level: 3,
        levelTitle: 'Pathfinder',
        badgesCount: 2,
        streakCount: 5,
        city: 'Nagpur',
      ),
      LeaderboardEntry(
        rank: 2,
        userId: 'USER_002',
        displayName: 'Nagpur_Scout',
        points: 380,
        level: 2,
        levelTitle: 'Scout',
        badgesCount: 1,
        streakCount: 3,
        city: 'Nagpur',
      ),
      LeaderboardEntry(
        rank: 3,
        userId: 'USER_003',
        displayName: 'CampusGuardian',
        points: 290,
        level: 2,
        levelTitle: 'Scout',
        badgesCount: 1,
        streakCount: 2,
        city: 'Nagpur',
      ),
    ];
  }

  /// Store offline draft audit.
  Future<void> queueOfflineDraft(Map<String, dynamic> auditData) async {
    final prefs = await SharedPreferences.getInstance();
    final draftsRaw = prefs.getStringList(kOfflineDraftsKey) ?? [];
    draftsRaw.add(jsonEncode(auditData));
    await prefs.setStringList(kOfflineDraftsKey, draftsRaw);
  }

  /// Sync queued offline drafts on reconnect.
  Future<int> syncOfflineDrafts() async {
    final prefs = await SharedPreferences.getInstance();
    final draftsRaw = prefs.getStringList(kOfflineDraftsKey) ?? [];
    if (draftsRaw.isEmpty) return 0;

    int syncedCount = 0;
    final List<String> remainingDrafts = [];

    for (var draftStr in draftsRaw) {
      try {
        final draftJson = jsonDecode(draftStr);
        final res = await http.post(
          Uri.parse('$baseUrl/audits'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(draftJson),
        );
        if (res.statusCode == 200) {
          syncedCount++;
        } else {
          remainingDrafts.add(draftStr);
        }
      } catch (e) {
        remainingDrafts.add(draftStr);
      }
    }

    await prefs.setStringList(kOfflineDraftsKey, remainingDrafts);
    return syncedCount;
  }
}
