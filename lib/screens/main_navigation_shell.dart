import 'package:flutter/material.dart';
import 'package:safe/screens/contribution_screen.dart';
import 'package:safe/screens/bt_mesh_screen.dart';
import 'package:safe/screens/emergency_screen.dart';
import 'package:safe/screens/home_screen.dart';
import 'package:safe/screens/location_screen.dart';
import 'package:safe/theme/app_theme.dart';
import 'package:safe/widgets/contacts/contacts_screen.dart';

import 'package:geolocator/geolocator.dart';
import 'package:safe/screens/sos_screen.dart';
import 'package:safe/widgets/smart_wake_gesture_detector.dart';

import 'dart:async';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:safe/services/shake_sos_service.dart';

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();
  StreamSubscription<Map<String, dynamic>>? _shakeSubscription;

  @override
  void initState() {
    super.initState();
    _shakeSubscription = ShakeSosService().onShakeSosTriggered.listen((data) {
      _handleShakeSosTriggered(data);
    });
  }

  void _handleShakeSosTriggered(Map<String, dynamic> data) async {
    final lat = (data['latitude'] as num?)?.toDouble() ?? 21.1458;
    final lng = (data['longitude'] as num?)?.toDouble() ?? 79.0882;

    if (!mounted) return;

    // 1. Generate High-Priority Red Color Error Message Banner & Toast
    Fluttertoast.showToast(
      msg: "🚨 RED ALERT: Shake SOS Triggered (2 Shakes)! Launching Auto SMS...",
      toastLength: Toast.LENGTH_LONG,
      backgroundColor: const Color(0xFFDC2626),
      textColor: Colors.white,
      fontSize: 14,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF991B1B),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFFCA5A5), width: 1.8),
        ),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.white24,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🚨 RED ALERT: SHAKE-TO-SOS DETECTED!',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '2 Shakes Detected! Redirecting to Emergency Auto SMS (9109750185)...',
                    style: GoogleFonts.outfit(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 4),
      ),
    );

    // 2. Direct Redirect to Emergency Auto SMS
    final smsMessage = '🚨 RED ALERT: SHAKE-TO-SOS DETECTED (2 SHAKES)! Immediate Help Needed!\nLive GPS Location: https://maps.google.com/?q=$lat,$lng\nHelpline: 9109750185';
    final Uri smsUri = Uri.parse('sms:9109750185?body=${Uri.encodeComponent(smsMessage)}');
    try {
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(smsUri);
      }
    } catch (_) {}

    // 3. Open Alert Message Screen (SOS Call Log Vector)
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => AlertMessageScreen(
          initialLat: lat,
          initialLon: lng,
          initialRecentCallVector: '9109750185',
        ),
      ),
    );
  }

  void _onSmartWakeLDetected() async {
    double sosLat = 21.1458;
    double sosLon = 79.0882;
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 2),
        ),
      );
      sosLat = pos.latitude;
      sosLon = pos.longitude;
    } catch (_) {}

    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (ctx) => AlertMessageScreen(
            initialLat: sosLat,
            initialLon: sosLon,
            initialRecentCallVector: '9109750185',
          ),
        ),
      );
    }
  }

  // Initial App Entry: Route Safety & Source-Destination Finder (Photo 1 & 2 UI/UX)
  final List<Widget> _pages = const [
    LocationScreen(),
    HomeScreen(),
    EmergencyScreen(),
    BtMeshScreen(),
    ContactsScreen(),
    ContributionScreen(),
  ];

  final List<_NavItemData> _navItems = const [
    _NavItemData(icon: Icons.map_rounded, label: 'Route Safety'),
    _NavItemData(icon: Icons.shield_rounded, label: 'Safety Audit'),
    _NavItemData(icon: Icons.local_police_rounded, label: 'Emergency'),
    _NavItemData(icon: Icons.bluetooth_searching_rounded, label: 'BT Mesh'),
    _NavItemData(icon: Icons.people_alt_rounded, label: 'Contacts'),
    _NavItemData(icon: Icons.rate_review_rounded, label: 'Contribution'),
  ];

  void _onTabTapped(int index) {
    if (index >= 0 && index < _pages.length) {
      setState(() {
        _currentIndex = index;
      });
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _shakeSubscription?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: SmartWakeGestureDetector(
        onLPatternDetected: _onSmartWakeLDetected,
        child: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.pageBackgroundGradient,
          ),
          child: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            children: _pages,
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.95),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                blurRadius: 28,
                spreadRadius: 2,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_navItems.length, (index) {
                final isSelected = _currentIndex == index;
                final item = _navItems[index];

                return GestureDetector(
                  onTap: () => _onTabTapped(index),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    padding: EdgeInsets.symmetric(
                      horizontal: isSelected ? 12 : 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? const LinearGradient(
                              colors: [
                                Color(0xFF8B5CF6),
                                Color(0xFFA855F7),
                              ],
                            )
                          : null,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              )
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          item.icon,
                          color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                          size: 20,
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: 5),
                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: isSelected ? 1.0 : 0.0,
                            child: Text(
                              item.label,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItemData {
  final IconData icon;
  final String label;

  const _NavItemData({required this.icon, required this.label});
}
