import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:safe/models/safety_audit_models.dart';
import 'package:safe/services/safety_audit_service.dart';
import 'package:safe/theme/app_theme.dart';

class GamificationProgressWidget extends StatefulWidget {
  final String userId;
  final VoidCallback? onLeaderboardTapped;

  const GamificationProgressWidget({
    super.key,
    this.userId = 'USER_DEMO_001',
    this.onLeaderboardTapped,
  });

  @override
  State<GamificationProgressWidget> createState() => _GamificationProgressWidgetState();
}

class _GamificationProgressWidgetState extends State<GamificationProgressWidget> {
  bool _isLoading = true;
  GamificationProfile? _profile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await SafetyAuditService().fetchUserProfile(widget.userId);
    if (mounted) {
      setState(() {
        _profile = profile;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _profile == null) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Center(
          child: CircularProgressIndicator(color: AppTheme.accentNeonPurple),
        ),
      );
    }

    final p = _profile!;
    final levelProgress = p.pointsToNextLevel > 0
        ? (p.totalPoints % 500) / 500.0
        : 1.0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF2E1065).withValues(alpha: 0.9),
            const Color(0xFF1E1B4B).withValues(alpha: 0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: AppTheme.accentNeonPurple.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Alias, Level Title & Streak
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryPurple.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.accentNeonPurple, width: 1.5),
                    ),
                    child: const Text('🛡️', style: TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.displayAlias,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Level ${p.level} • ${p.levelTitle}',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.accentNeonPurple,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Streak Chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFF59E0B), width: 1),
                ),
                child: Row(
                  children: [
                    const Text('🔥 ', style: TextStyle(fontSize: 14)),
                    Text(
                      '${p.streakCount}d Streak',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFF59E0B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Points & Progress Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${p.totalPoints} Total Safety Points',
                style: GoogleFonts.inter(fontSize: 13, color: Colors.white70),
              ),
              Text(
                '${p.pointsToNextLevel} pts to next level',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.white54),
              ),
            ],
          ),
          const SizedBox(height: 8),

          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: levelProgress.clamp(0.05, 1.0),
              minHeight: 8,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentNeonPurple),
            ),
          ),

          const SizedBox(height: 16),

          // Badges Row & Leaderboard Action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: p.badges.map((b) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Tooltip(
                          message: '${b.name}: ${b.description}',
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Text(b.icon, style: const TextStyle(fontSize: 14)),
                                const SizedBox(width: 4),
                                Text(
                                  b.name,
                                  style: GoogleFonts.inter(fontSize: 11, color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              if (widget.onLeaderboardTapped != null)
                TextButton.icon(
                  onPressed: widget.onLeaderboardTapped,
                  icon: Icon(Icons.leaderboard_rounded, size: 16, color: AppTheme.accentNeonPurple),
                  label: Text(
                    'Leaderboard',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.accentNeonPurple,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
