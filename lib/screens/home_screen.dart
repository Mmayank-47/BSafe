import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:safe/screens/duress_mask_screen.dart';
import 'package:safe/screens/sos_screen.dart';
import 'package:safe/services/agent_api_service.dart';
import 'package:safe/services/edge_audio_engine.dart';
import 'package:safe/services/mesh_network_service.dart';
import 'package:safe/theme/app_theme.dart';
import 'package:safe/widgets/pulse_sos_button.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final EdgeAudioEngine _audioEngine = EdgeAudioEngine();
  final MeshNetworkService _meshService = MeshNetworkService();
  double _currentDb = 48.0;
  final TextEditingController _pinController = TextEditingController();
  StreamSubscription<double>? _decibelSubscription;

  @override
  void initState() {
    super.initState();
    _audioEngine.startEngine();
    _decibelSubscription = _audioEngine.decibelStream.listen((dbLevel) {
      if (mounted) {
        setState(() {
          _currentDb = dbLevel;
        });
      }
    });
  }

  @override
  void dispose() {
    _decibelSubscription?.cancel();
    _pinController.dispose();
    super.dispose();
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

  void _triggerSimulatedScream() {
    _audioEngine.simulateExtremeScreamSpike(94.2, 'Bachao');
    Navigator.of(context).push(
      MaterialPageRoute(builder: (ctx) => const AlertMessageScreen()),
    );
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
                          'bSafe Engine',
                          style: GoogleFonts.outfit(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textDark,
                          ),
                        ),
                        Text(
                          'Active Agentic Protection',
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
                      Text(
                        'Route Safety Index',
                        style: GoogleFonts.outfit(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '8.5 / 10',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.accentMint.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'LOW RISK ZONE',
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
              ),
            ),

            // Central Animated SOS Trigger
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Center(
                  child: PulseSosButton(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (ctx) => const AlertMessageScreen()),
                      );
                    },
                  ),
                ),
              ),
            ),

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
