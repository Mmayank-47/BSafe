import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:safe/data/emergency_list.dart';
import 'package:safe/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class EmergencyCard extends StatelessWidget {
  const EmergencyCard({super.key});

  Future<void> _makeCall(String number) async {
    final Uri url = Uri.parse("tel:$number");
    try {
      await launchUrl(url);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Text(
            'Emergency Helplines',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textDark,
            ),
          ),
        ),
        SizedBox(
          height: 180,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            physics: const BouncingScrollPhysics(),
            scrollDirection: Axis.horizontal,
            itemCount: emergencyList.length,
            itemBuilder: (ctx, index) {
              final emergency = emergencyList[index];
              return EmergencyItem(
                emergency: emergency,
                onCall: () => _makeCall(emergency.number),
              );
            },
          ),
        ),
      ],
    );
  }
}

class EmergencyItem extends StatelessWidget {
  final dynamic emergency;
  final VoidCallback onCall;

  const EmergencyItem({
    super.key,
    required this.emergency,
    required this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    final List<List<Color>> gradientPalettes = [
      [const Color(0xFFF43F5E), const Color(0xFFFB7185)],
      [const Color(0xFF38BDF8), const Color(0xFF818CF8)],
      [const Color(0xFFF59E0B), const Color(0xFFFCD34D)],
      [const Color(0xFF10B981), const Color(0xFF34D399)],
    ];

    final colors = gradientPalettes[emergency.name.length % gradientPalettes.length];

    return Container(
      width: 250,
      margin: const EdgeInsets.all(6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colors[0].withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.local_hospital_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  emergency.name,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          Text(
            emergency.info,
            style: GoogleFonts.outfit(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 13,
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: colors[0],
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: onCall,
            icon: const Icon(Icons.phone_in_talk_rounded, size: 18),
            label: Text(
              'Call ${emergency.number}',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
