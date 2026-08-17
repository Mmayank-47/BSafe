import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:safe/models/safety_audit_models.dart';
import 'package:safe/services/safety_audit_service.dart';
import 'package:safe/theme/app_theme.dart';

class SafetyLeaderboardScreen extends StatefulWidget {
  const SafetyLeaderboardScreen({super.key});

  @override
  State<SafetyLeaderboardScreen> createState() => _SafetyLeaderboardScreenState();
}

class _SafetyLeaderboardScreenState extends State<SafetyLeaderboardScreen> {
  String _selectedScope = 'alltime'; // weekly, monthly, alltime
  String? _selectedCity;
  bool _isLoading = true;
  List<LeaderboardEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    setState(() => _isLoading = true);
    final entries = await SafetyAuditService().fetchLeaderboard(
      scope: _selectedScope,
      city: _selectedCity,
    );
    if (mounted) {
      setState(() {
        _entries = entries;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Find current user entry or default to #4
    final myEntry = _entries.firstWhere(
      (e) => e.userId == 'USER_DEMO_001',
      orElse: () => LeaderboardEntry(
        rank: 4,
        userId: 'USER_DEMO_001',
        displayName: 'Nikhil Makhija (Safety Hero)',
        points: 18,
        level: 1,
        levelTitle: 'Safeti-Starter',
        badgesCount: 1,
        streakCount: 3,
        city: 'Nagpur',
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0F071E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '🏆 Community Champions',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 20,
          ),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Filter Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      _buildScopeTab('weekly', 'Weekly'),
                      _buildScopeTab('monthly', 'Monthly'),
                      _buildScopeTab('alltime', 'All Time'),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Main Leaderboard Scrollable Content
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: AppTheme.accentNeonPurple),
                      )
                    : SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
                        child: Column(
                          children: [
                            // Top 3 Podium Layout
                            if (_entries.length >= 3) _buildPodiumWidget(_entries),
                            const SizedBox(height: 20),

                            // Leaderboard List (Rank #4 downwards)
                            ..._entries.map((entry) => _buildLeaderboardTile(entry)),
                          ],
                        ),
                      ),
              ),
            ],
          ),

          // Sticky "Your Global Ranking" Bottom Card
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF2E1065),
                    const Color(0xFF1E1B4B),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF06B6D4), width: 1.8),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF06B6D4).withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Rank Badge
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF06B6D4).withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF06B6D4), width: 1.5),
                    ),
                    child: Center(
                      child: Text(
                        '#${myEntry.rank}',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF06B6D4),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // User Profile Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Text(
                              'YOUR GLOBAL RANKING',
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF06B6D4),
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 14),
                          ],
                        ),
                        Text(
                          'Nikhil Makhija (Safety Hero)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          '⭐ Top 5% Global Contributor • Nagpur',
                          style: GoogleFonts.outfit(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Points Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.accentNeonPurple.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.accentNeonPurple, width: 1),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${myEntry.points}',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Pts',
                          style: GoogleFonts.outfit(
                            color: AppTheme.accentNeonPurple,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScopeTab(String scope, String label) {
    final isSelected = _selectedScope == scope;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedScope = scope);
          _loadLeaderboard();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryPurple : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.outfit(
                color: isSelected ? Colors.white : Colors.white60,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPodiumWidget(List<LeaderboardEntry> entries) {
    final rank1 = entries.firstWhere((e) => e.rank == 1, orElse: () => entries[0]);
    final rank2 = entries.firstWhere((e) => e.rank == 2, orElse: () => entries[1]);
    final rank3 = entries.firstWhere((e) => e.rank == 3, orElse: () => entries[2]);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Rank 2 (Silver)
          _buildPodiumColumn(rank2, '🥈', const Color(0xFF94A3B8), 100),

          // Rank 1 (Gold)
          _buildPodiumColumn(rank1, '🥇', const Color(0xFFF59E0B), 130),

          // Rank 3 (Bronze)
          _buildPodiumColumn(rank3, '🥉', const Color(0xFFD97706), 85),
        ],
      ),
    );
  }

  Widget _buildPodiumColumn(LeaderboardEntry entry, String medal, Color accentColor, double height) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(medal, style: const TextStyle(fontSize: 28)),
        const SizedBox(height: 4),
        Text(
          entry.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
        ),
        Text(
          '${entry.points} Pts',
          style: GoogleFonts.outfit(color: accentColor, fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Container(
          width: 85,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                accentColor.withValues(alpha: 0.4),
                accentColor.withValues(alpha: 0.1),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border.all(color: accentColor.withValues(alpha: 0.6), width: 1.5),
          ),
          child: Center(
            child: Text(
              '#${entry.rank}',
              style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLeaderboardTile(LeaderboardEntry entry) {
    final isMe = entry.userId == 'USER_DEMO_001';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isMe
            ? const Color(0xFF2E1065).withValues(alpha: 0.9)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isMe ? AppTheme.accentNeonPurple : Colors.white10,
          width: isMe ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          // Rank Badge
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: entry.rank == 1
                  ? const Color(0xFFF59E0B)
                  : entry.rank == 2
                      ? const Color(0xFF94A3B8)
                      : entry.rank == 3
                          ? const Color(0xFFD97706)
                          : Colors.white10,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                entry.rank == 1
                    ? '🥇'
                    : entry.rank == 2
                        ? '🥈'
                        : entry.rank == 3
                            ? '🥉'
                            : '#${entry.rank}',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: entry.rank <= 3 ? 16 : 13,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // User Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.displayName,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '${entry.levelTitle} • ${entry.city}',
                  style: GoogleFonts.outfit(
                    color: Colors.white60,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          // Points Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primaryPurple.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primaryPurple),
            ),
            child: Text(
              '${entry.points} Pts',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
