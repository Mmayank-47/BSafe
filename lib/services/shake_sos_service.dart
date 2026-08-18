import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:safe/services/agent_api_service.dart';
import 'package:safe/services/mesh_network_service.dart';
import 'package:safe/services/women_safety_mesh_sos_service.dart';

/// Dart Service for Shake-to-SOS Emergency Trigger.
/// Listens for accelerometer shake events from native Android and dispatches end-to-end SOS messages:
/// 1. 7-Hop Encrypted BLE Mesh SOS Flood
/// 2. Agentic Emergency Triage API Gateway Relay
/// 3. Direct Background SMS Dispatch to Trusted Contacts (bypasses app UI prompts)
class ShakeSosService {
  static final ShakeSosService _instance = ShakeSosService._internal();
  factory ShakeSosService() => _instance;
  ShakeSosService._internal() {
    _initChannelHandler();
  }

  static const MethodChannel _channel = MethodChannel('com.bsafe/womensafety_mesh_sos');
  final StreamController<Map<String, dynamic>> _shakeSosController = StreamController<Map<String, dynamic>>.broadcast();

  bool _isShakeEnabled = true;
  bool get isShakeEnabled => _isShakeEnabled;

  Stream<Map<String, dynamic>> get onShakeSosTriggered => _shakeSosController.stream;

  void _initChannelHandler() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onShakeSosTriggered') {
        final Map<dynamic, dynamic>? args = call.arguments as Map<dynamic, dynamic>?;
        if (args != null) {
          final map = args.cast<String, dynamic>();
          debugPrint('🚨 SHAKE-TO-SOS DETECTED! Dispatching emergency BLE Mesh & Direct SMS payload...');

          await _dispatchShakeEmergencyMessage(map);
          _shakeSosController.add(map);
        }
      }
    });
  }

  /// Dispatches full normal emergency SOS payload: Direct SMS, BLE Mesh, and Agentic Triage.
  Future<void> _dispatchShakeEmergencyMessage(Map<String, dynamic> recordMap) async {
    final lat = (recordMap['latitude'] as num?)?.toDouble() ?? 21.1458;
    final lng = (recordMap['longitude'] as num?)?.toDouble() ?? 79.0882;
    const targetContact = '9109750185';
    final mapLink = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    final smsMsg = '🚨 RED ALERT: Shake-to-SOS Emergency Triggered! Immediate assistance required! GPS Location: $mapLink';

    // 1. Send Direct Cellular Background SMS to Emergency Contact
    try {
      await WomenSafetyMeshSosService.sendDirectSms(targetContact, smsMsg);
    } catch (e) {
      debugPrint('Direct background SMS send error: $e');
    }

    // 2. Add to local distress inbox store (Distress Box)
    MeshNetworkService().addLocalDistressRecord(recordMap);

    // 3. Broadcast Noise Encrypted BLE Mesh Beacon
    try {
      await MeshNetworkService().broadcastMeshDistressBeacon(
        userId: 'USER_SHAKE_SOS',
        latitude: lat,
        longitude: lng,
        triggerType: 'SHAKE_ACCELEROMETER',
      );
    } catch (e) {
      debugPrint('BLE Mesh Broadcast error: $e');
    }

    // 4. Trigger Agentic Triage API Gateway
    try {
      await AgentApiService.triggerSOS(
        userId: 'usr_shake_trigger',
        triggerType: 'SHAKE_ACCELEROMETER',
        latitude: lat,
        longitude: lng,
        recentCallVector: targetContact,
      );
    } catch (e) {
      debugPrint('Agentic Triage API error: $e');
    }
  }

  /// Enable or disable Shake-to-SOS accelerometer detection
  Future<bool> toggleShakeSos(bool enable) async {
    try {
      final bool? res = await _channel.invokeMethod<bool>('toggleShakeSos', {'enable': enable});
      _isShakeEnabled = res ?? enable;
      return _isShakeEnabled;
    } catch (e) {
      _isShakeEnabled = enable;
      return enable;
    }
  }

  /// Simulate a Shake-to-SOS trigger manually for testing on emulators
  Future<Map<String, dynamic>?> triggerShakeSimulation() async {
    try {
      final Map<dynamic, dynamic>? res = await _channel.invokeMethod('triggerShakeSosSimulation');
      if (res != null) {
        final map = res.cast<String, dynamic>();
        await _dispatchShakeEmergencyMessage(map);
        _shakeSosController.add(map);
        return map;
      }
    } catch (e) {
      debugPrint('Shake simulation error: $e');
    }
    return null;
  }
}
