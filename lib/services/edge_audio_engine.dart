import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

/// Edge AI Acoustic & Decibel Intensity Engine.
/// Operates continuous background listening for acoustic distress hotwords and scream spikes.
class EdgeAudioEngine {
  static final EdgeAudioEngine _instance = EdgeAudioEngine._internal();
  factory EdgeAudioEngine() => _instance;
  EdgeAudioEngine._internal();

  bool _isListening = false;
  double _currentDecibelLevel = 45.0;
  final StreamController<double> _decibelStreamController = StreamController<double>.broadcast();
  final StreamController<String> _hotwordStreamController = StreamController<String>.broadcast();
  Timer? _simulationTimer;

  bool get isListening => _isListening;
  Stream<double> get decibelStream => _decibelStreamController.stream;
  Stream<String> get hotwordStream => _hotwordStreamController.stream;

  void startEngine() {
    if (_isListening) return;
    _isListening = true;
    debugPrint('[Edge AI Audio Engine] Acoustic listening started.');

    // Simulates continuous acoustic sound pressure monitoring
    _simulationTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      // Random baseline environmental noise 40dB - 65dB
      final randomDb = 40.0 + Random().nextDouble() * 25.0;
      _currentDecibelLevel = double.parse(randomDb.toStringAsFixed(1));
      _decibelStreamController.add(_currentDecibelLevel);
    });
  }

  void simulateExtremeScreamSpike(double dbLevel, String? hotword) {
    _currentDecibelLevel = dbLevel;
    _decibelStreamController.add(dbLevel);
    if (hotword != null) {
      _hotwordStreamController.add(hotword);
    }
  }

  void stopEngine() {
    _isListening = false;
    _simulationTimer?.cancel();
    debugPrint('[Edge AI Audio Engine] Stopped.');
  }
}
