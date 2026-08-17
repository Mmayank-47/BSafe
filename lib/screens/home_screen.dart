import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:safe/screens/duress_mask_screen.dart';
import 'package:safe/screens/emergency_screen.dart';
import 'package:safe/screens/feed_screen.dart';
import 'package:safe/screens/location_screen.dart';
import 'package:safe/screens/sos_screen.dart';
import 'package:safe/services/agent_api_service.dart';
import 'package:safe/services/edge_audio_engine.dart';
import 'package:safe/services/mesh_network_service.dart';
import 'package:safe/widgets/contacts/contacts_screen.dart';

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
        title: const Text('Enter Security PIN'),
        content: TextField(
          controller: _pinController,
          obscureText: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: 'Enter 4-digit PIN (e.g. 9999 for Duress)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final pin = _pinController.text;
              Navigator.of(ctx).pop();
              _pinController.clear();

              if (pin == '9999') {
                // Silent Tier 2 escalation via backend
                AgentApiService.triggerSOS(
                  userId: 'usr_current_app',
                  triggerType: 'DURESS_PIN',
                  latitude: 28.6139,
                  longitude: 77.2090,
                  duressPinUsed: true,
                );
                // Open neutral visual disguise screen
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (c) => const DuressMaskScreen()),
                );
              }
            },
            child: const Text('Confirm'),
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
      appBar: AppBar(
        title: Text(
          'bSafe Engine',
          style: GoogleFonts.arimo(
            fontSize: 30,
            fontWeight: FontWeight.bold,
            color: const Color(0xFFF75874),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.shield_outlined, color: Colors.deepOrange),
            tooltip: 'Duress PIN Neutralizer',
            onPressed: _showDuressDialog,
          )
        ],
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(12),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Closed-Loop Agent & Mesh Status Header Banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E2C),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.mic, color: Colors.greenAccent, size: 20),
                                const SizedBox(width: 6),
                                Text(
                                  'Edge AI Decibel: ${_currentDb.toStringAsFixed(1)} dB',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.blueAccent.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Mesh Active (${_meshService.connectedPeersCount} Nodes)',
                                style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 12),
                              ),
                            )
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: const [
                            Icon(Icons.route, color: Colors.amberAccent, size: 20),
                            SizedBox(width: 6),
                            Text(
                              'Route Safety Agent Score: 8.5/10 (LOW RISK)',
                              style: TextStyle(color: Colors.amberAccent, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Big Central SOS Trigger Button
                  GestureDetector(
                    onTap: () {
                      debugPrint("SOS button pressed");
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (ctx) => const AlertMessageScreen()),
                      );
                    },
                    child: Center(
                      child: Container(
                        width: 210.0,
                        height: 210.0,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const RadialGradient(
                            colors: [Colors.white, Colors.pinkAccent],
                            center: Alignment.center,
                            radius: 0.8,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              spreadRadius: 4,
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Container(
                            width: 180.0,
                            height: 180.0,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.pink,
                              border: Border.all(color: Colors.white, width: 4),
                            ),
                            child: Center(
                              child: Text(
                                'SOS',
                                style: GoogleFonts.arimo(
                                  color: Colors.white,
                                  fontSize: 60.0,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Multi-Modal Trigger Shortcut Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _triggerSimulatedScream,
                        icon: const Icon(Icons.record_voice_over, color: Colors.redAccent),
                        label: const Text('Simulate >85dB Scream'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          _meshService.broadcastMeshDistressBeacon(
                            userId: 'usr_current_app',
                            latitude: 28.6139,
                            longitude: 77.2090,
                            triggerType: 'BLE_MESH_RELAY',
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('BLE Multi-Hop Mesh Beacon Broadcasted!')),
                          );
                        },
                        icon: const Icon(Icons.hub, color: Colors.blue),
                        label: const Text('7-Hop BLE Mesh'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ]),
              ),
            ),

            // Navigation Grid
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                ),
                delegate: SliverChildListDelegate([
                  GridItem(
                    title: 'Share Location',
                    image: 'assets/share_location.png',
                    gradientColors: const [Color(0xFFffc94f), Color(0xFFfd7d08)],
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (ctx) => const LocationScreen()),
                    ),
                  ),
                  GridItem(
                    title: 'Emergency',
                    image: 'assets/emergency.png',
                    gradientColors: const [Color(0xFF27fcb3), Color(0xFF0cc291)],
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (ctx) => const EmergencyScreen()),
                    ),
                  ),
                  GridItem(
                    title: 'Contacts',
                    image: 'assets/contacts.png',
                    gradientColors: const [Color.fromARGB(255, 216, 131, 215), Color(0xFFf56ca6)],
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (ctx) => const ContactsScreen()),
                    ),
                  ),
                  GridItem(
                    title: 'Feed',
                    image: 'assets/feed.png',
                    gradientColors: const [Color(0xFF80D0C7), Color(0xFF0093E9)],
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (ctx) => const FeedScreen()),
                    ),
                  ),
                ]),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
          ],
        ),
      ),
    );
  }
}

class GridItem extends StatelessWidget {
  const GridItem({
    super.key,
    required this.title,
    required this.image,
    required this.gradientColors,
    required this.onTap,
  });

  final String title;
  final String image;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashColor: const Color(0xFFebadff),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: gradientColors,
            ),
          ),
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: Image.asset(image, fit: BoxFit.cover, height: 120, width: 120),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        fontSize: 20,
                        color: Colors.white,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
