import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:safe/screens/duress_mask_screen.dart';
import 'package:safe/screens/sos_screen.dart';
import 'package:safe/screens/nagpur_safety_screen.dart';
import 'package:safe/services/agent_api_service.dart';
import 'package:safe/services/edge_audio_engine.dart';
import 'package:safe/services/mesh_network_service.dart';
import 'package:safe/services/nagpur_safety_service.dart';
import 'package:safe/theme/app_theme.dart';
import 'package:safe/widgets/pulse_sos_button.dart';
import 'package:url_launcher/url_launcher.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final EdgeAudioEngine _audioEngine = EdgeAudioEngine();
  final MeshNetworkService _meshService = MeshNetworkService();
  final NagpurSafetyService _safetyService = NagpurSafetyService();
  LocalityMatchResult? _matchedLocality;
  double _currentDb = 48.0;
  final TextEditingController _pinController = TextEditingController();
  StreamSubscription<double>? _decibelSubscription;
  StreamSubscription<String>? _hotwordSubscription;
  StreamSubscription<String>? _auditSubscription;

  int _escalationAttempt = 1;
  Timer? _escalationTimer;
  int _secondsRemaining = 5;
  bool _isEscalationActive = false;

  @override
  void initState() {
    super.initState();
    _loadNagpurSafety();
    _auditSubscription = _safetyService.eventStream.listen((_) {
      _loadNagpurSafety();
    });
    _decibelSubscription = _audioEngine.decibelStream.listen((dbLevel) {
      if (mounted) {
        setState(() {
          _currentDb = dbLevel;
        });
      }
    });
    _hotwordSubscription = _audioEngine.hotwordStream.listen((hotword) {
      debugPrint('[HomeScreen] 🚨 HOTWORD RECEIVED FROM ENGINE: $hotword');
      if (mounted) {
        _triggerVoiceEmergencyEscalation(hotword);
      }
    });
    // Start audio engine (it handles its own mic permission internally)
    _audioEngine.startEngine();
  }

  Future<void> _loadNagpurSafety() async {
    await _safetyService.loadSafetyScores();
    if (mounted) {
      setState(() {
        _matchedLocality = _safetyService.getNearestLocality(21.1458, 79.0882);
      });
    }
  }

  @override
  void dispose() {
    _escalationTimer?.cancel();
    _auditSubscription?.cancel();
    _decibelSubscription?.cancel();
    _hotwordSubscription?.cancel();
    _pinController.dispose();
    super.dispose();
  }

  void _triggerVoiceEmergencyEscalation(String triggerReason) {
    debugPrint('[HomeScreen] _triggerVoiceEmergencyEscalation called. Active: $_isEscalationActive');
    if (_isEscalationActive) return;
    _isEscalationActive = true;
    _escalationAttempt = 1;
    _secondsRemaining = 5;

    // Show a snackbar as immediate visual feedback
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
                  _executeEmergencyCallAndSms('Automatic Escalation: No response after 2 safety checks.');
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
                          Text(
                            '🚨 RED ALERT SIGN: VOICE DISTRESS',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              letterSpacing: 0.5,
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
                              _executeEmergencyCallAndSms('User pressed NO (Need Help)!');
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
    final message = Uri.encodeComponent(
      '🚨 EMERGENCY RAKSHASETU ALERT! $reason Live GPS Location: https://maps.google.com/?q=21.1458,79.0882 Helpline: 9109750185',
    );

    final smsUri = Uri.parse('sms:$phone?body=$message');
    try {
      await launchUrl(smsUri);
    } catch (_) {}

    final telUri = Uri.parse('tel:$phone');
    try {
      await launchUrl(telUri);
    } catch (_) {}

    Fluttertoast.showToast(
      msg: "🚨 Emergency Call & SMS Dispatched to 9109750185!",
      toastLength: Toast.LENGTH_LONG,
      backgroundColor: Colors.redAccent,
    );
  }


  void _showDuressDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            const Icon(Icons.shield_outlined, color: AppTheme.accentRose),
            const SizedBox(width: 8),
            Text(
              'Enter Security PIN',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter 4-digit PIN (e.g. 9999 for Duress disguised trigger):',
              style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Enter 4-digit PIN',
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryPurple,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final pin = _pinController.text;
              Navigator.of(ctx).pop();
              _pinController.clear();

              if (pin == '9999') {
                AgentApiService.triggerSOS(
                  userId: 'usr_current_app',
                  triggerType: 'DURESS_PIN',
                  latitude: 28.6139,
                  longitude: 77.2090,
                  duressPinUsed: true,
                );
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (c) => const DuressMaskScreen()),
                );
              }
            },
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }



  Future<void> _sendEmergencySMSOrWhatsApp() async {
    const phoneNumber = "9109750185";
    const message = "🚨 EMERGENCY SOS ALERT from RakshaSetu! I need immediate help at GPS location (21.1458, 79.0882), Sitabuldi, Nagpur. Please send assistance!";

    final whatsappUrl = Uri.parse("https://wa.me/91$phoneNumber?text=${Uri.encodeComponent(message)}");
    try {
      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}

    final smsUrl = Uri.parse("sms:$phoneNumber?body=${Uri.encodeComponent(message)}");
    try {
      await launchUrl(smsUrl);
    } catch (_) {
      await launchUrl(smsUrl, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildCentralSOSTrigger(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: PulseSosButton(
            onTap: () {
              _sendEmergencySMSOrWhatsApp();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (ctx) => const AlertMessageScreen()),
              );
            },
          ),
        ),
      ),
    );
  }

  int _safetyCheckAttemptCount = 0;
  Timer? _safetyCheckTimer;
  int _safetyCheckSecondsRemaining = 5;

  Future<void> _makeEmergencyDirectCall() async {
    final Uri phoneUri = Uri.parse('tel:9109750185');
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      await launchUrl(phoneUri, mode: LaunchMode.externalApplication);
    }
  }

  void _triggerLPatternSafetyCheck() {
    _sendEmergencySMSOrWhatsApp();
    _safetyCheckAttemptCount = 1;
    _startSafetyCheckEscalation();
  }

  void _startSafetyCheckEscalation() {
    _safetyCheckSecondsRemaining = 5;
    _safetyCheckTimer?.cancel();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            _safetyCheckTimer ??= Timer.periodic(const Duration(seconds: 1), (t) {
              if (!mounted) {
                t.cancel();
                return;
              }
              if (_safetyCheckSecondsRemaining > 1) {
                setDialogState(() {
                  _safetyCheckSecondsRemaining--;
                });
              } else {
                t.cancel();
                _safetyCheckTimer = null;
                Navigator.of(dialogCtx).pop();

                if (_safetyCheckAttemptCount < 3) {
                  _safetyCheckAttemptCount++;
                  _startSafetyCheckEscalation();
                } else {
                  _sendEmergencySMSOrWhatsApp();
                  _makeEmergencyDirectCall();
                  Fluttertoast.showToast(
                    msg: "🚨 NO RESPONSE AFTER 3 ATTEMPTS! Auto-calling & dispatching live location to 9109750185!",
                    toastLength: Toast.LENGTH_LONG,
                  );
                }
              }
            });

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              backgroundColor: const Color(0xFF0F172A),
              title: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.shield_moon_rounded, color: Color(0xFFEF4444), size: 36),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'ARE YOU SAFE?',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                    ),
                  ),
                  Text(
                    'Gesture Trigger • Attempt $_safetyCheckAttemptCount of 3',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFFFCA5A5),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Initial SMS dispatched to 9109750185. Please verify your safety:',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: 70,
                    height: 70,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFEF4444), width: 3),
                    ),
                    child: Text(
                      '${_safetyCheckSecondsRemaining}s',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              actionsAlignment: MainAxisAlignment.spaceEvenly,
              actions: [
                ElevatedButton.icon(
                  onPressed: () {
                    _safetyCheckTimer?.cancel();
                    _safetyCheckTimer = null;
                    Navigator.of(dialogCtx).pop();
                    Fluttertoast.showToast(msg: "🟢 Situation Normal — Safety Confirmed!");
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  label: Text('YES, I\'m Safe', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    _safetyCheckTimer?.cancel();
                    _safetyCheckTimer = null;
                    Navigator.of(dialogCtx).pop();
                    _sendEmergencySMSOrWhatsApp();
                    _makeEmergencyDirectCall();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                  label: Text('NO, Need Help!', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _triggerSimulatedScream() {
    _audioEngine.simulateExtremeScreamSpike(94.2, 'Bachao');
    _triggerLPatternSafetyCheck();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Top App Bar / Branding
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Safety Audit',
                          style: GoogleFonts.outfit(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textDark,
                          ),
                        ),
                        Text(
                          'Active Agentic Protection & Audit Engine',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            color: AppTheme.primaryPurple,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: _showDuressDialog,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: AppTheme.glassCardDecoration(
                          borderRadius: 16,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                        child: const Icon(
                          Icons.shield_outlined,
                          color: AppTheme.accentRose,
                          size: 26,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Main Hero Purple Card (matching reference design style)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              sliver: SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: AppTheme.purpleHeroGradient,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryPurple.withValues(alpha: 0.35),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  'Edge Decibel: ${_currentDb.toStringAsFixed(1)} dB',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.hub_rounded, color: AppTheme.accentMint, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  'Mesh (${_meshService.connectedPeersCount} Nodes)',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (ctx) => const NagpurSafetyScreen(),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _matchedLocality != null
                                      ? 'Nagpur Locality: ${_matchedLocality!.locality.place}'
                                      : 'Route Safety Index',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  color: Colors.white70,
                                  size: 14,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  _matchedLocality != null
                                      ? '${_matchedLocality!.locality.safetyScore.toStringAsFixed(1)} / 100'
                                      : '85.5 / 100',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 30,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: (_matchedLocality?.locality.safetyScore ?? 85) >= 60
                                        ? AppTheme.accentMint.withValues(alpha: 0.3)
                                        : AppTheme.accentRose.withValues(alpha: 0.4),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    (_matchedLocality?.locality.riskTier ?? 'VERY SAFE').toUpperCase(),
                                    style: GoogleFonts.outfit(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Central Animated SOS Trigger
            _buildCentralSOSTrigger(context),

            // Multi-Modal Shortcuts Bar
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _triggerSimulatedScream,
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: AppTheme.glassCardDecoration(borderRadius: 20),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentRose.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.record_voice_over_rounded,
                                  color: AppTheme.accentRose,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Audio Spike',
                                      style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: AppTheme.textDark,
                                      ),
                                    ),
                                    Text(
                                      '>85dB Scream',
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        color: AppTheme.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          _meshService.broadcastMeshDistressBeacon(
                            userId: 'usr_current_app',
                            latitude: 28.6139,
                            longitude: 77.2090,
                            triggerType: 'BLE_MESH_RELAY',
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'BLE Multi-Hop Mesh Beacon Broadcasted!',
                                style: GoogleFonts.outfit(),
                              ),
                              backgroundColor: AppTheme.primaryPurple,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: AppTheme.glassCardDecoration(borderRadius: 20),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryPurple.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.wifi_tethering_rounded,
                                  color: AppTheme.primaryPurple,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Mesh Relay',
                                      style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: AppTheme.textDark,
                                      ),
                                    ),
                                    Text(
                                      '7-Hop Offline',
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        color: AppTheme.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }
}
