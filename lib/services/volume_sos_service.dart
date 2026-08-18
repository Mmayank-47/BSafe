import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:safe/services/agent_api_service.dart';
import 'package:safe/services/mesh_network_service.dart';
import 'package:safe/services/women_safety_mesh_sos_service.dart';

/// Dart Service for Hardware Volume Button Combo SOS Trigger (3x Vol Down + 1x Vol Up).
/// Listens for volume button key sequence events from native Android and dispatches multi-channel SOS alerts.
class VolumeSosService {
  static final VolumeSosService _instance = VolumeSosService._internal();
  factory VolumeSosService() => _instance;
  VolumeSosService._internal() {
    _initChannelHandler();
  }

  static const MethodChannel _channel = MethodChannel('com.bsafe/womensafety_mesh_sos');
  final StreamController<Map<String, dynamic>> _volumeSosController = StreamController<Map<String, dynamic>>.broadcast();

  bool _isVolumeComboEnabled = true;
  bool get isVolumeComboEnabled => _isVolumeComboEnabled;

  Stream<Map<String, dynamic>> get onVolumeComboSosTriggered => _volumeSosController.stream;

  void _initChannelHandler() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onVolumeComboSosTriggered') {
        final Map<dynamic, dynamic>? args = call.arguments as Map<dynamic, dynamic>?;
        if (args != null) {
          final map = args.cast<String, dynamic>();
          debugPrint('🚨 HARDWARE VOLUME COMBO SOS DETECTED! (3x Vol Down + 1x Vol Up)');

          await _dispatchVolumeEmergencyMessage(map);
          _volumeSosController.add(map);
        }
      }
    });
  }

  /// Dispatches full normal emergency SOS payload: Direct SMS, BLE Mesh, and Agentic Triage.
  Future<void> _dispatchVolumeEmergencyMessage(Map<String, dynamic> recordMap) async {
    final lat = (recordMap['latitude'] as num?)?.toDouble() ?? 21.1458;
    final lng = (recordMap['longitude'] as num?)?.toDouble() ?? 79.0882;
    const targetContact = '9109750185';
    final mapLink = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    final smsMsg = '🚨 RED ALERT: Hardware Volume Combo SOS Triggered (3x Vol Down + 1x Vol Up)! Immediate assistance required! GPS Location: $mapLink';

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
        userId: 'USER_VOLUME_SOS',
        latitude: lat,
        longitude: lng,
        triggerType: 'HARDWARE_VOLUME_COMBO',
      );
    } catch (e) {
      debugPrint('BLE Mesh Broadcast error: $e');
    }

    // 4. Trigger Agentic Triage API Gateway
    try {
      await AgentApiService.triggerSOS(
        userId: 'usr_volume_trigger',
        triggerType: 'HARDWARE_VOLUME_COMBO',
        latitude: lat,
        longitude: lng,
        recentCallVector: targetContact,
      );
    } catch (e) {
      debugPrint('Agentic Triage API error: $e');
    }
  }

  /// Enable or disable Volume Combo SOS key sequence listener
  Future<bool> toggleVolumeComboSos(bool enable) async {
    try {
      final bool? res = await _channel.invokeMethod<bool>('toggleVolumeComboSos', {'enable': enable});
      _isVolumeComboEnabled = res ?? enable;
      return _isVolumeComboEnabled;
    } catch (e) {
      _isVolumeComboEnabled = enable;
      return enable;
    }
  }

  /// Simulate a Volume Combo SOS trigger manually for testing
  Future<Map<String, dynamic>?> triggerVolumeComboSimulation() async {
    try {
      final Map<dynamic, dynamic>? res = await _channel.invokeMethod('triggerVolumeComboSosSimulation');
      if (res != null) {
        final map = res.cast<String, dynamic>();
        await _dispatchVolumeEmergencyMessage(map);
        _volumeSosController.add(map);
        return map;
      }
    } catch (e) {
      debugPrint('Volume combo simulation error: $e');
    }
    return null;
  }
}
