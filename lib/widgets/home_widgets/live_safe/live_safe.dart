import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:safe/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class LiveSafe extends StatelessWidget {
  const LiveSafe({super.key});

  Future<void> openMap(String location) async {
    final Uri url = Uri.parse("https://www.google.com/maps/search/$location");
    try {
      await launchUrl(url);
    } catch (_) {}
  }

  Widget buildCard({
    required IconData icon,
    required String title,
    required String location,
    required Color color,
  }) {
    return GestureDetector(
      onTap: () => openMap(location),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.glassCardDecoration(borderRadius: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const Spacer(),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  'Directions',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.arrow_forward_rounded, size: 14, color: color),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> places = [
      {
        "title": "Police Station",
        "location": "Police Stations near me",
        "icon": Icons.local_police_rounded,
        "color": const Color(0xFF8B5CF6),
      },
      {
        "title": "Hospitals",
        "location": "Hospitals near me",
        "icon": Icons.local_hospital_rounded,
        "color": const Color(0xFFF43F5E),
      },
      {
        "title": "Bus Station",
        "location": "Bus Stations near me",
        "icon": Icons.directions_bus_rounded,
        "color": const Color(0xFF38BDF8),
      },
      {
        "title": "Pharmacies",
        "location": "Pharmacies near me",
        "icon": Icons.medical_services_rounded,
        "color": const Color(0xFF34D399),
      },
      {
        "title": "Safe Hotels",
        "location": "Hotels near me",
        "icon": Icons.hotel_rounded,
        "color": const Color(0xFFF59E0B),
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LiveSafe Places Nearby',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: places.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.2,
            ),
            itemBuilder: (context, index) {
              final item = places[index];
              return buildCard(
                icon: item["icon"],
                title: item["title"],
                location: item["location"],
                color: item["color"],
              );
            },
          ),
        ],
      ),
    );
  }
}
