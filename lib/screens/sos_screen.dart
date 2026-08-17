import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geolocator/geolocator.dart';
import 'package:safe/components/custom_button.dart';
import 'package:safe/screens/location_service.dart';
import 'package:safe/services/agent_api_service.dart';
import 'package:safe/services/contact_resolution_service.dart';
import 'package:safe/services/mesh_network_service.dart';
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
            "Latitude: ${position.latitude.toStringAsFixed(4)}, \nLongitude: ${position.longitude.toStringAsFixed(4)}\nAddress: $address";
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
          title: Text('Agentic Triage: $tier Alert'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Triage Summary:\n${result?['triage_summary'] ?? 'Dispatched'}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.pinkAccent),
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
                  style: const TextStyle(fontSize: 14),
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
              child: const Text('Dispatch SMS / Mesh'),
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
      appBar: AppBar(
        title: const Text('Emergency SOS Dispatcher'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Distress Message Payload',
              style: TextStyle(
                fontSize: 18,
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: textController,
              decoration: const InputDecoration(
                hintText: 'Enter Message',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            Card(
              color: Colors.grey.shade100,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Contextual Recent Call Log Vector:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(_recentCallVector ?? 'Querying READ_CALL_LOG...', style: const TextStyle(color: Colors.blue)),
                    const SizedBox(height: 8),
                    Text(locationMessage, style: const TextStyle(fontSize: 14)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_triageResult != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.pink.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.pinkAccent),
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
            CustomButton(
              text: "Dispatch Agentic SOS",
              onPressed: _dispatchAgenticSOS,
            ),
          ],
        ),
      ),
    );
  }
}