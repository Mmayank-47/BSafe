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

  /// Dispatches multi-channel emergency messages: BLE Mesh flood + Agentic Triage API + Direct Background SMS.
  Future<void> _dispatchVolumeEmergencyMessage(Map<String, dynamic> recordMap) async {
    final lat = (recordMap['latitude'] as num?)?.toDouble() ?? 21.1458;
    final lng = (recordMap['longitude'] as num?)?.toDouble() ?? 79.0882;
    final victimName = recordMap['victimName'] ?? 'Primary User';
    final customMessage = recordMap['message'] ?? recordMap['customMessage'] ?? '🚨 HARDWARE VOLUME COMBO SOS! (3x Vol Down + 1x Vol Up)';

    // 1. Add to local distress inbox store
    MeshNetworkService().addLocalDistressRecord(recordMap);

    // 2. Broadcast Noise Encrypted BLE Mesh Beacon
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

    // 3. Trigger Agentic Triage API Gateway
    try {
      await AgentApiService.triggerSOS(
        userId: 'usr_volume_trigger',
        triggerType: 'HARDWARE_VOLUME_COMBO',
        latitude: lat,
        longitude: lng,
        recentCallVector: null,
      );
    } catch (e) {
      debugPrint('Agentic Triage API error: $e');
    }

    // 4. Direct Background SMS Dispatch to Trusted Contacts
    try {
      final mapLink = 'http://maps.google.com/?q=$lat,$lng';
      final smsMessage = '$customMessage\nVictim: $victimName\nGPS Location: $mapLink';
      final trustedContacts = ['+919109750185', '+919876543210'];

      for (final phone in trustedContacts) {
        final sentDirect = await WomenSafetyMeshSosService.sendDirectSms(phone, smsMessage);
        if (sentDirect) {
          debugPrint('✅ Direct background SMS dispatched to trusted contact $phone');
        }
      }
    } catch (e) {
      debugPrint('Emergency Direct SMS dispatch error: $e');
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
