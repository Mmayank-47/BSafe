import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe/models/safety_audit_models.dart';

void main() {
  group('Gamified Safety Module - Dart Models & Helper Logic', () {
    test('SafetyLocation color mapping', () {
      final locGreen = SafetyLocation(
        id: '1',
        latitude: 21.0,
        longitude: 79.0,
        addressLabel: 'Green Spot',
        categoryTag: 'PARK',
        safetyScore: 4.5,
        scoreColor: 'GREEN',
        auditCount: 10,
      );
      expect(locGreen.color.toARGB32(), const Color(0xFF10B981).toARGB32());

      final locAmber = SafetyLocation(
        id: '2',
        latitude: 21.0,
        longitude: 79.0,
        addressLabel: 'Amber Spot',
        categoryTag: 'STREET',
        safetyScore: 3.5,
        scoreColor: 'AMBER',
        auditCount: 5,
      );
      expect(locAmber.color.toARGB32(), const Color(0xFFF59E0B).toARGB32());

      final locRed = SafetyLocation(
        id: '3',
        latitude: 21.0,
        longitude: 79.0,
        addressLabel: 'Red Spot',
        categoryTag: 'ISOLATED_STRETCH',
        safetyScore: 2.1,
        scoreColor: 'RED',
        auditCount: 2,
      );
      expect(locRed.color.toARGB32(), const Color(0xFFEF4444).toARGB32());
    });

    test('GamificationProfile deserialization', () {
      final profile = GamificationProfile.fromJson({
        'user_id': 'USER_101',
        'display_alias': 'HeroExplorer',
        'use_alias': true,
        'total_points': 950,
        'level': 4,
        'level_title': 'Guardian',
        'points_to_next_level': 850,
        'streak_count': 7,
        'weekly_audits_count': 6,
        'badges': [
          {
            'badge_id': 'NIGHT_OWL',
            'name': 'Night Owl',
            'description': '10 night audits',
            'icon': '🌙',
            'earned_at': '2026-08-17T12:00:00.000Z',
          }
        ]
      });

      expect(profile.userId, 'USER_101');
      expect(profile.level, 4);
      expect(profile.levelTitle, 'Guardian');
      expect(profile.badges.length, 1);
      expect(profile.badges.first.name, 'Night Owl');
    });

    test('LeaderboardEntry rank ordering', () {
      final entry = LeaderboardEntry.fromJson({
        'rank': 1,
        'user_id': 'U1',
        'display_name': 'Ananya',
        'points': 1200,
        'level': 5,
        'level_title': 'Sentinel',
        'badges_count': 4,
        'streak_count': 10,
        'city': 'Nagpur'
      });

      expect(entry.rank, 1);
      expect(entry.displayName, 'Ananya');
      expect(entry.points, 1200);
    });
  });
}
