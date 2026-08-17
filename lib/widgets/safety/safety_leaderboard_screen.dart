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
    return Scaffold(
      backgroundColor: const Color(0xFF0F071E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Community Safety Champions',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: Column(
        children: [
          // Filter Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'weekly', label: Text('Weekly')),
                      ButtonSegment(value: 'monthly', label: Text('Monthly')),
                      ButtonSegment(value: 'alltime', label: Text('All Time')),
                    ],
                    selected: {_selectedScope},
                    onSelectionChanged: (val) {
                      setState(() => _selectedScope = val.first);
                      _loadLeaderboard();
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Leaderboard List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.accentNeonPurple),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _entries.length,
                    itemBuilder: (context, index) {
                      final entry = _entries[index];
                      final isTop3 = entry.rank <= 3;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isTop3
                              ? const Color(0xFF2E1065).withValues(alpha: 0.8)
                              : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isTop3
                                ? const Color(0xFFF59E0B)
                                : Colors.white10,
                            width: isTop3 ? 1.5 : 1,
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
                                    fontSize: isTop3 ? 16 : 13,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),

                            // User Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entry.displayName,
                                    style: GoogleFonts.outfit(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    'Lvl ${entry.level} ${entry.levelTitle} • 🔥 ${entry.streakCount}d streak',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: AppTheme.accentNeonPurple,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Points
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${entry.points} Pts',
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF10B981),
                                  ),
                                ),
                                Text(
                                  '${entry.badgesCount} Badges',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: Colors.white54,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
