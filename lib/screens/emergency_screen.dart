import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:safe/theme/app_theme.dart';
import 'package:safe/widgets/home_widgets/emergency_card/emergency_card.dart';
import 'package:safe/widgets/home_widgets/live_safe/live_safe.dart';

class EmergencyScreen extends StatelessWidget {
  const EmergencyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(top: 12, bottom: 100),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Emergency Hub',
                    style: GoogleFonts.outfit(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textDark,
                    ),
                  ),
                  Text(
                    'Direct Hotlines & Verified Safe Spots',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: AppTheme.primaryPurple,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const EmergencyCard(),
            const SizedBox(height: 12),
            const LiveSafe(),
          ],
        ),
      ),
    );
  }
}