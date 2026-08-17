import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Dart Service for Women's Safety Offline BLE Mesh SOS.
/// Connects the BSafe Flutter App directly to the native Kotlin WomenSafetyMeshSosManager engine.
class WomenSafetyMeshSosService {
  static const MethodChannel _channel = MethodChannel('com.bsafe/womensafety_mesh_sos');

  static Future<bool> initSosModule({
    required String victimName,
    required String deviceIdHex,
  }) async {
    try {
      final bool? success = await _channel.invokeMethod<bool>('initSosModule', {
        'victimName': victimName,
        'deviceIdHex': deviceIdHex,
      });
      return success ?? false;
    } catch (e) {
      debugPrint("WomenSafetyMeshSosService init error: $e");
      return false;
    }
  }

  /// One-touch trigger to broadcast an emergency SOS over the local BLE mesh
  static Future<Map<String, dynamic>?> triggerEmergencySos({
    required double latitude,
    required double longitude,
    int batteryLevel = 100,
    String message = "EMERGENCY! Help required immediately!",
  }) async {
    try {
      final Map<dynamic, dynamic>? result = await _channel.invokeMethod('triggerEmergencySos', {
        'latitude': latitude,
        'longitude': longitude,
        'batteryLevel': batteryLevel,
        'message': message,
      });
      return result?.cast<String, dynamic>();
    } catch (e) {
      debugPrint("WomenSafetyMeshSosService trigger error: $e");
      return null;
    }
  }

  /// Get current delivery status of the active SOS (QUEUED, RELAYING, BRIDGED, DELIVERED)
  static Future<String> getDeliveryStatus() async {
    try {
      final String? status = await _channel.invokeMethod<String>('getDeliveryStatus');
      return status ?? "UNKNOWN";
    } catch (e) {
      return "UNKNOWN";
    }
  }

  /// Get real-time count of connected live active nodes in the BLE mesh
  static Future<int> getConnectedLiveNodesCount() async {
    try {
      final int? count = await _channel.invokeMethod<int>('getConnectedLiveNodesCount');
      return count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Get real-time count of connected active devices in the BLE mesh
  static Future<int> getConnectedPeersCount() async {
    return getConnectedLiveNodesCount();
  }

  /// Get list of received distress SOS signals caught from nearby peer devices
  static Future<List<Map<String, dynamic>>> getReceivedSosRecords() async {
    try {
      final List<dynamic>? list = await _channel.invokeMethod('getReceivedSosRecords');
      if (list != null) {
        return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (e) {
      debugPrint("WomenSafetyMeshSosService getReceivedSosRecords error: $e");
      return [];
    }
  }

  /// Simulate receiving a distress signal from a nearby peer device for testing
  static Future<Map<String, dynamic>?> simulateIncomingPeerSos({
    String victimName = "Ananya Sharma",
    double latitude = 21.1462,
    double longitude = 79.0890,
    int batteryLevel = 85,
    String message = "HELP! Emergency distress signal caught from nearby guardian device!",
  }) async {
    try {
      final Map<dynamic, dynamic>? result = await _channel.invokeMethod('simulateIncomingPeerSos', {
        'victimName': victimName,
        'latitude': latitude,
        'longitude': longitude,
        'batteryLevel': batteryLevel,
        'message': message,
      });
      return result?.cast<String, dynamic>();
    } catch (e) {
      debugPrint("WomenSafetyMeshSosService simulate error: $e");
      return null;
    }
  }

  /// Send a direct background SMS to a phone number bypassing SMS app UI
  static Future<bool> sendDirectSms(String phoneNumber, String message) async {
    try {
      final bool? success = await _channel.invokeMethod<bool>('sendDirectSms', {
        'phoneNumber': phoneNumber,
        'message': message,
      });
      return success ?? false;
    } catch (e) {
      debugPrint('Direct SMS invocation error: $e');
      return false;
    }
  }

  /// Enable or disable Always-On Display mode
  static Future<bool> enableAlwaysOnDisplay([bool enable = true]) async {
    try {
      final bool? res = await _channel.invokeMethod<bool>('enableAlwaysOnDisplay', {'enable': enable});
      return res ?? true;
    } catch (e) {
      return false;
    }
  }

  /// Manually wake up device screen on emergency trigger
  static Future<bool> wakeUpScreen() async {
    try {
      final bool? res = await _channel.invokeMethod<bool>('wakeUpScreen');
      return res ?? true;
    } catch (e) {
      return false;
    }
  }
}
