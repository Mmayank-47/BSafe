import 'dart:async';
import 'package:flutter/foundation.dart';

/// Service intercepting physical hardware button patterns (Volume Up -> Volume Down -> Volume Up).
/// Bypasses lock screen and triggers silent stealth payload with haptic feedback.
class HardwareTriggerService {
  static final HardwareTriggerService _instance = HardwareTriggerService._internal();
  factory HardwareTriggerService() => _instance;
  HardwareTriggerService._internal();

  final List<String> _keyHistory = [];
  DateTime? _firstKeyPressTime;
  final StreamController<void> _triggerStreamController = StreamController<void>.broadcast();

  Stream<void> get onHardwareSequenceTriggered => _triggerStreamController.stream;

  void registerKeyPress(String keyName) {
    final now = DateTime.now();

    if (_firstKeyPressTime == null || now.difference(_firstKeyPressTime!) > const Duration(milliseconds: 1500)) {
      _keyHistory.clear();
      _firstKeyPressTime = now;
    }

    _keyHistory.add(keyName);

    // Target sequence: VolUp -> VolDown -> VolUp
    if (_keyHistory.length >= 3) {
      final len = _keyHistory.length;
      if (_keyHistory[len - 3] == 'VolUp' &&
          _keyHistory[len - 2] == 'VolDown' &&
          _keyHistory[len - 1] == 'VolUp') {
        debugPrint('[Hardware Trigger] Stealth Hardware Key Sequence Detected! (VolUp -> VolDown -> VolUp)');
        _keyHistory.clear();
        _firstKeyPressTime = null;
        _triggerStreamController.add(null);
      }
    }
  }
}
