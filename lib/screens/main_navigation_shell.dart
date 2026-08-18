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
import 'package:safe/services/shake_sos_service.dart';
import 'package:safe/services/volume_sos_service.dart';
import 'package:safe/services/edge_audio_engine.dart';
import 'package:safe/services/women_safety_mesh_sos_service.dart';
import 'package:safe/services/agent_api_service.dart';
import 'package:url_launcher/url_launcher.dart';

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();
  StreamSubscription<Map<String, dynamic>>? _shakeSubscription;
  StreamSubscription<Map<String, dynamic>>? _volumeSubscription;
  StreamSubscription<String>? _hotwordSubscription;
  bool _isEscalationActive = false;
  int _escalationAttempt = 1;
  int _secondsRemaining = 5;
  Timer? _escalationTimer;

  @override
  void initState() {
    super.initState();
    _shakeSubscription = ShakeSosService().onShakeSosTriggered.listen((data) {
      _handleShakeSosTriggered(data);
    });
    _volumeSubscription = VolumeSosService().onVolumeComboSosTriggered.listen((data) {
      _handleVolumeSosTriggered(data);
    });

    EdgeAudioEngine().startEngine();
    _hotwordSubscription = EdgeAudioEngine().hotwordStream.listen((hotword) {
      debugPrint('[MainNavigationShell] 🚨 HOTWORD MATCH RECEIVED: $hotword');
      _triggerVoiceEmergencyEscalation(hotword);
    });
  }

  @override
  void dispose() {
    _shakeSubscription?.cancel();
    _volumeSubscription?.cancel();
    _hotwordSubscription?.cancel();
    _escalationTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _handleShakeSosTriggered(Map<String, dynamic> data) async {
    if (!mounted) return;

    final lat = (data['latitude'] as num?)?.toDouble();
    final lng = (data['longitude'] as num?)?.toDouble();

    Fluttertoast.showToast(
      msg: "🚨 RED ALERT: Shake SOS Triggered! Opening SOS Control & Direct SMS.",
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
              child: const Icon(Icons.shield_outlined, color: Colors.white, size: 26),
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
                    '2 Shakes Detected! Full Normal SOS triggered & dispatches Direct SMS + BLE Mesh.',
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

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AlertMessageScreen(
          initialLat: lat,
          initialLon: lng,
          initialRecentCallVector: '9109750185',
        ),
      ),
    );
  }

  void _handleVolumeSosTriggered(Map<String, dynamic> data) async {
    if (!mounted) return;

    final lat = (data['latitude'] as num?)?.toDouble();
    final lng = (data['longitude'] as num?)?.toDouble();

    Fluttertoast.showToast(
      msg: "🚨 HARDWARE VOLUME COMBO SOS DETECTED! Opening SOS Control & Direct SMS.",
      toastLength: Toast.LENGTH_LONG,
      backgroundColor: const Color(0xFFE11D48),
      textColor: Colors.white,
      fontSize: 14,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF9F1239),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFFDA4AF), width: 1.8),
        ),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.white24,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.volume_down_rounded, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🚨 HARDWARE VOLUME COMBO SOS DETECTED!',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'Volume Combo (3x Vol Down + 1x Vol Up) Detected! Full Normal SOS dispatched.',
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

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AlertMessageScreen(
          initialLat: lat,
          initialLon: lng,
          initialRecentCallVector: '9109750185',
        ),
      ),
    );
  }

  void _triggerVoiceEmergencyEscalation(String triggerReason) {
    if (!mounted || _isEscalationActive) return;
    _isEscalationActive = true;
    _escalationAttempt = 1;
    _secondsRemaining = 5;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '🚨 VOICE DISTRESS DETECTED: $triggerReason',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );

    _showRedAlertEscalationDialog(triggerReason);
  }

  void _showRedAlertEscalationDialog(String triggerReason) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            _escalationTimer?.cancel();
            _escalationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
              if (_secondsRemaining > 1) {
                if (mounted) setDialogState(() => _secondsRemaining--);
              } else {
                timer.cancel();
                if (_escalationAttempt < 2) {
                  if (mounted) {
                    setDialogState(() {
                      _escalationAttempt++;
                      _secondsRemaining = 5;
                    });
                  }
                } else {
                  Navigator.of(dialogCtx, rootNavigator: true).pop();
                  _isEscalationActive = false;
                  _executeEmergencyCallAndSms('Automatic Escalation: No response after 2 safety checks ($triggerReason)');
                }
              }
            });

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF991B1B),
                      Color(0xFF7F1D1D),
                      Color(0xFF450A0A),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: Colors.redAccent, width: 2.5),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.redAccent,
                      blurRadius: 30,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white54),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Colors.yellowAccent, size: 20),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '🚨 RED ALERT SIGN: VOICE DISTRESS',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                letterSpacing: 0.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 90,
                          height: 90,
                          child: CircularProgressIndicator(
                            value: _secondsRemaining / 5.0,
                            strokeWidth: 6,
                            backgroundColor: Colors.white24,
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.yellowAccent),
                          ),
                        ),
                        Container(
                          width: 70,
                          height: 70,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '$_secondsRemaining',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'ARE YOU SAFE?',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Emergency Voice Trigger: "$triggerReason"',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        color: Colors.yellowAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Attempt $_escalationAttempt of 2 (Auto Helpline Call in ${_secondsRemaining + (2 - _escalationAttempt) * 5}s)',
                      style: GoogleFonts.outfit(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              _escalationTimer?.cancel();
                              Navigator.of(dialogCtx, rootNavigator: true).pop();
                              _isEscalationActive = false;
                              Fluttertoast.showToast(
                                msg: "🟢 Situation Normal. Alert Cancelled.",
                                backgroundColor: const Color(0xFF10B981),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
                            label: Text(
                              'YES, Safe',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              _escalationTimer?.cancel();
                              Navigator.of(dialogCtx, rootNavigator: true).pop();
                              _isEscalationActive = false;
                              _executeEmergencyCallAndSms('User pressed NO (Need Help)! Trigger: $triggerReason');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFDC2626),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            icon: const Icon(Icons.sos_rounded, color: Colors.white),
                            label: Text(
                              'NO, Help!',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _executeEmergencyCallAndSms(String reason) async {
    const phone = '9109750185';
    double lat = 21.1458;
    double lon = 79.0882;

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 3),
        ),
      );
      lat = pos.latitude;
      lon = pos.longitude;
    } catch (_) {}

    final message = '🚨 EMERGENCY RAKSHASETU ALERT! $reason Live GPS Location: https://maps.google.com/?q=$lat,$lon Helpline: $phone';

    final sentDirect = await WomenSafetyMeshSosService.sendDirectSms(phone, message);
    if (sentDirect) {
      Fluttertoast.showToast(
        msg: "✅ Emergency Auto SMS directly sent to $phone!",
        toastLength: Toast.LENGTH_SHORT,
        backgroundColor: const Color(0xFF10B981),
        textColor: Colors.white,
      );
    }

    try {
      await AgentApiService.triggerSOS(
        userId: 'usr_voice_hotword',
        triggerType: 'ACOUSTIC_HOTWORD',
        latitude: lat,
        longitude: lon,
        recentCallVector: phone,
      );
    } catch (_) {}

    final telUri = Uri.parse('tel:$phone');
    try {
      await launchUrl(telUri);
    } catch (_) {}

    Fluttertoast.showToast(
      msg: "🚨 Emergency Call & SMS Dispatched to 9109750185!",
      toastLength: Toast.LENGTH_LONG,
      backgroundColor: Colors.red,
    );

    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AlertMessageScreen(
            initialLat: lat,
            initialLon: lon,
            initialRecentCallVector: phone,
          ),
        ),
      );
    }
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
