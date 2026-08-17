import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:safe/theme/app_theme.dart';
import 'package:safe/widgets/home_widgets/slider_quotes/show_quotes.dart';

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Safety Feed',
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textDark,
                ),
              ),
              Text(
                'Daily Insights & Community Guidelines',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: AppTheme.primaryPurple,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),

              // Quote Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: AppTheme.purpleHeroGradient,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryPurple.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.format_quote_rounded, color: Colors.white, size: 28),
                        const SizedBox(width: 8),
                        Text(
                          'Quote for You',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const ShowQuotes(),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Safety Tips Section
              Text(
                'Essential Safety Guidelines',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 12),

              _buildTipCard(
                icon: Icons.shield_moon_rounded,
                title: "Night Travel Guard",
                description: "Share live track location with trusted contacts whenever traveling past 9 PM.",
                color: const Color(0xFF8B5CF6),
              ),
              const SizedBox(height: 12),
              _buildTipCard(
                icon: Icons.graphic_eq_rounded,
                title: "Edge Audio Decibel Alert",
                description: "Keep decibel audio monitoring active to detect high-intensity screams automatically.",
                color: const Color(0xFFF43F5E),
              ),
              const SizedBox(height: 12),
              _buildTipCard(
                icon: Icons.wifi_tethering_rounded,
                title: "Offline Mesh Network",
                description: "Multi-hop BLE mesh propagates SOS beacons even in zero cellular coverage zones.",
                color: const Color(0xFF38BDF8),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTipCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassCardDecoration(borderRadius: 24),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}