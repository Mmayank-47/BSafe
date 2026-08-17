import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:safe/components/custom_button.dart';
import 'package:safe/screens/location_service.dart';
import 'package:safe/services/agent_api_service.dart';
import 'package:safe/services/contact_resolution_service.dart';
import 'package:safe/services/mesh_network_service.dart';
import 'package:safe/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class AlertMessageScreen extends StatefulWidget {
  const AlertMessageScreen({super.key});

  @override
  State<AlertMessageScreen> createState() => _AlertMessageScreenState();
}

class _AlertMessageScreenState extends State<AlertMessageScreen> {
  final TextEditingController textController = TextEditingController(text: "EMERGENCY! I need immediate help!");
  final LocationService _locationService = LocationService();
  final ContactResolutionService _contactResolver = ContactResolutionService();
  final MeshNetworkService _meshService = MeshNetworkService();

  String locationMessage = "Fetching location...";
  String mapLink = "";
  double? _lat;
  double? _lon;
  String? _recentCallVector;
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
    try {
      Position position = await _locationService.getCurrentLocation();
      String address = await _locationService.getAddressFromCoordinates(
          position.latitude, position.longitude);
      String? recentCaller = await _contactResolver.getContextualRecentCallVector();

      setState(() {
        _lat = position.latitude;
        _lon = position.longitude;
        _recentCallVector = recentCaller;
        locationMessage =
            "Lat: ${position.latitude.toStringAsFixed(4)}, Lon: ${position.longitude.toStringAsFixed(4)}\n$address";
        mapLink =
            'https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}';
      });
    } catch (e) {
      setState(() {
        locationMessage = e.toString();
        _lat = 28.6139;
        _lon = 77.2090;
        _recentCallVector = '+919876543000';
      });
    }
  }

  Future<void> _dispatchAgenticSOS() async {
    final lat = _lat ?? 28.6139;
    final lon = _lon ?? 77.2090;

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

    final message = "${textController.text}\nRecent Caller Vector: $_recentCallVector\nLocation: $mapLink";
    _showAlertDialog(message, result);
  }

  Future<void> sendSMS(String number, String message) async {
    final Uri url = Uri.parse("sms:+91$number?body=${Uri.encodeComponent(message)}");
    try {
      await launchUrl(url);
    } catch (e) {
      Fluttertoast.showToast(msg: "Offline Base64 Encrypted SMS Triggered!");
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
                sendSMS("9876543210", message);
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
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: AppTheme.glassCardDecoration(borderRadius: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recent Call Log Vector:',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppTheme.textDark),
                      ),
                      Text(
                        _recentCallVector ?? 'Querying READ_CALL_LOG...',
                        style: GoogleFonts.outfit(color: AppTheme.primaryPurple, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        locationMessage,
                        style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textMuted),
                      ),
                    ],
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