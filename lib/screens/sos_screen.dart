import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:safe/components/custom_button.dart';
import 'package:safe/screens/location_service.dart';
import 'package:safe/services/agent_api_service.dart';
import 'package:safe/services/women_safety_mesh_sos_service.dart';
import 'package:safe/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class AlertMessageScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLon;
  final String? initialRecentCallVector;

  const AlertMessageScreen({
    super.key,
    this.initialLat,
    this.initialLon,
    this.initialRecentCallVector = '9109750185',
  });

  @override
  State<AlertMessageScreen> createState() => _AlertMessageScreenState();
}

class _AlertMessageScreenState extends State<AlertMessageScreen> {
  final TextEditingController textController = TextEditingController(text: "EMERGENCY! I need immediate help!");
  final LocationService _locationService = LocationService();

  String locationMessage = "Fetching exact SOS GPS coordinates...";
  String _exactAddress = "Locating...";
  String mapLink = "";
  double? _lat;
  double? _lon;
  String? _recentCallVector = '9109750185';
  Map<String, dynamic>? _triageResult;

  @override
  void dispose() {
    textController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fetchCurrentLocationAndContext();
  }

  Future<void> _fetchCurrentLocationAndContext() async {
    double latitude = widget.initialLat ?? 21.1458;
    double longitude = widget.initialLon ?? 79.0882;
    final recentCaller = widget.initialRecentCallVector ?? '9109750185';

    // If initial coordinates were provided, use them; otherwise query fresh high-accuracy GPS
    if (widget.initialLat != null && widget.initialLon != null) {
      latitude = widget.initialLat!;
      longitude = widget.initialLon!;
    } else {
      try {
        Position position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 3),
          ),
        );
        latitude = position.latitude;
        longitude = position.longitude;
      } catch (_) {
        try {
          Position position = await _locationService.getCurrentLocation();
          latitude = position.latitude;
          longitude = position.longitude;
        } catch (_) {}
      }
    }

    String address = "Nagpur, Maharashtra, India";
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        address = [p.name, p.subLocality, p.locality, p.administrativeArea]
            .where((s) => s != null && s.isNotEmpty)
            .join(', ');
      }
    } catch (_) {
      try {
        address = await _locationService.getAddressFromCoordinates(latitude, longitude);
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _lat = latitude;
        _lon = longitude;
        _exactAddress = address;
        _recentCallVector = recentCaller;
        locationMessage = "Lat: ${latitude.toStringAsFixed(5)}, Lon: ${longitude.toStringAsFixed(5)}";
        mapLink = 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
      });
    }
  }

  Future<void> _openExactLocationInMap() async {
    final lat = _lat ?? 21.1458;
    final lon = _lon ?? 79.0882;
    final url = Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$lon");
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(url);
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Could not open map: $e");
    }
  }

  Future<void> _dispatchAgenticSOS() async {
    final lat = _lat ?? 21.1458;
    final lon = _lon ?? 79.0882;

    final result = await AgentApiService.triggerSOS(
      userId: 'usr_current_app',
      triggerType: 'MANUAL_BUTTON',
      latitude: lat,
      longitude: lon,
      recentCallVector: _recentCallVector,
    );

    setState(() {
      _triageResult = result;
    });

    final message = "${textController.text}\nRecent Caller Vector: $_recentCallVector\nExact SOS GPS: $mapLink";
    _showAlertDialog(message, result);
  }

  Future<void> sendSMS(String number, String message) async {
    const targetNumber = "9109750185";
    final sentDirect = await WomenSafetyMeshSosService.sendDirectSms(targetNumber, message);
    if (sentDirect) {
      Fluttertoast.showToast(
        msg: "✅ Auto SMS directly sent to $targetNumber!",
        toastLength: Toast.LENGTH_SHORT,
        backgroundColor: const Color(0xFF10B981),
        textColor: Colors.white,
      );
    } else {
      final whatsappUrl = Uri.parse("https://wa.me/91$targetNumber?text=${Uri.encodeComponent(message)}");
      try {
        if (await canLaunchUrl(whatsappUrl)) {
          await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
        }
      } catch (_) {}
    }
  }

  void _showAlertDialog(String message, Map<String, dynamic>? result) {
    final tier = result?['tier'] ?? 'TIER_1';
    final respondersCount = (result?['assigned_responders'] as List?)?.length ?? 0;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            'Agentic Triage: $tier Alert',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Triage Summary:\n${result?['triage_summary'] ?? 'Dispatched'}',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppTheme.accentRose),
                ),
                const SizedBox(height: 8),
                Text('Assigned Responders: $respondersCount spatial units'),
                if (result?['ivr_bridge_initiated'] == true) ...[
                  const SizedBox(height: 6),
                  const Text('⚡ Automated IVR 112 Call Bridge Initiated!', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                ],
                const Divider(),
                Text(
                  'SMS Payload:\n$message',
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryPurple,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Dispatch SMS / Mesh', style: TextStyle(color: Colors.white)),
              onPressed: () {
                Navigator.of(context).pop();
                sendSMS("9109750185", message);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Emergency SOS Dispatcher',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.pageBackgroundGradient,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Distress Message Payload',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    color: AppTheme.textDark,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: textController,
                  decoration: InputDecoration(
                    hintText: 'Enter Message',
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),

                // Interactive Clickable Recent Call Log Vector Card with Exact SOS Pinpoint Location
                InkWell(
                  onTap: _openExactLocationInMap,
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppTheme.primaryPurple.withValues(alpha: 0.4), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryPurple.withValues(alpha: 0.12),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryPurple.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.phone_in_talk_rounded, color: AppTheme.primaryPurple, size: 18),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Recent Call Log Vector:',
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppTheme.textDark, fontSize: 14),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'ACTIVE',
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFF10B981),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _recentCallVector ?? '9109750185 (Emergency Response Vector)',
                          style: GoogleFonts.outfit(color: AppTheme.primaryPurple, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const Divider(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.location_pin, color: Color(0xFFEF4444), size: 20),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Exact SOS Trigger Location:',
                                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textDark),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    locationMessage,
                                    style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple),
                                  ),
                                  Text(
                                    _exactAddress,
                                    style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textMuted),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.map_rounded, color: Colors.white, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                '📍 Tap to Open Exact SOS Pin in Google Maps',
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
                  ),
                ),

                const SizedBox(height: 16),
                if (_triageResult != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.accentRose.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.accentRose),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Incident ID: ${_triageResult!['incident_id']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('Status: ${_triageResult!['status']} | Tier: ${_triageResult!['tier']}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                const Spacer(),
                CustomButton(
                  text: "Dispatch Agentic SOS",
                  onPressed: _dispatchAgenticSOS,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}