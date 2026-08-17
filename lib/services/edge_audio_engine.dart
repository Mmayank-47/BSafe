import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Edge AI Acoustic & Voice-to-Text Hotword Engine.
///
/// ARCHITECTURE: noise_meter and speech_to_text CANNOT share the Android
/// microphone simultaneously. This engine alternates between them:
///
/// Phase 1 (MONITOR):  noise_meter reads dB levels continuously.
///                     When dB >= 85 threshold, switch to Phase 2.
/// Phase 2 (CAPTURE):  Pause noise_meter, start speech_to_text for 8 seconds
///                     to capture hotwords ("help", "bachao", "save me").
///                     If hotword found → fire distress alert.
///                     After 8s, return to Phase 1.
class EdgeAudioEngine {
  static final EdgeAudioEngine _instance = EdgeAudioEngine._internal();
  factory EdgeAudioEngine() => _instance;
  EdgeAudioEngine._internal();

  bool _isListening = false;
  double _currentDecibelLevel = 48.0;
  DateTime? _lastTriggerTime;

  bool _inCaptureMode = false;
  Timer? _captureTimeout;

  final StreamController<double> _decibelStreamController = StreamController<double>.broadcast();
  final StreamController<String> _hotwordStreamController = StreamController<String>.broadcast();

  NoiseMeter? _noiseMeter;
  StreamSubscription<NoiseReading>? _noiseSubscription;
  SpeechToText? _speechToText;
  bool _speechEnabled = false;

  final List<String> _distressHotwords = const [
    'help',
    'bachao',
    'save me',
    'emergency',
    'police',
    'danger',
    'bachaoo',
    'help me',
    'save',
  ];

  bool get isListening => _isListening;
  Stream<double> get decibelStream => _decibelStreamController.stream;
  Stream<String> get hotwordStream => _hotwordStreamController.stream;

  void startEngine() async {
    if (_isListening) return;
    _isListening = true;
    debugPrint('[Edge AI Audio Engine] Initializing...');

    try {
      PermissionStatus status = await Permission.microphone.status;
      if (!status.isGranted) {
        status = await Permission.microphone.request();
      }
      if (!status.isGranted) {
        debugPrint('[Edge AI Audio Engine] Microphone permission not granted.');
        _isListening = false;
        return;
      }

      // Pre-initialize STT so it's ready when needed
      _speechToText ??= SpeechToText();
      _speechEnabled = await _speechToText!.initialize(
        onError: (val) => debugPrint('[STT Error] $val'),
        onStatus: (status) => debugPrint('[STT Status] $status'),
      );
      debugPrint('[Edge AI Audio Engine] STT initialized: $_speechEnabled');

      // Start Phase 1: dB monitoring
      _startNoiseMonitoring();
    } catch (e) {
      debugPrint('[Edge AI Audio Engine] Exception: $e');
      _isListening = false;
    }
  }

  // ── PHASE 1: MONITOR dB levels ──────────────────────────────────────
  void _startNoiseMonitoring() {
    if (!_isListening) return;
    _inCaptureMode = false;
    debugPrint('[Edge AI Audio Engine] Phase 1: dB monitoring active');

    _noiseMeter ??= NoiseMeter();
    _noiseSubscription = _noiseMeter!.noise.listen(
      (NoiseReading noiseReading) {
        double db = noiseReading.meanDecibel;
        if (db.isFinite && !db.isNaN && db > 0) {
          _currentDecibelLevel = double.parse(db.toStringAsFixed(1));
          _decibelStreamController.add(_currentDecibelLevel);

          // When dB crosses 85 threshold → switch to capture mode
          if (_currentDecibelLevel >= 85.0 && !_inCaptureMode) {
            debugPrint('[Edge AI Audio Engine] 🔊 dB threshold crossed: ${_currentDecibelLevel}dB → switching to speech capture');
            _switchToCaptureMode();
          }
        }
      },
      onError: (Object error) {
        debugPrint('[Edge AI Audio Engine] Noise stream error: $error');
        // Retry after 1 second
        Future.delayed(const Duration(seconds: 1), () {
          if (_isListening && !_inCaptureMode) _startNoiseMonitoring();
        });
      },
      cancelOnError: false,
    );
  }

  // ── PHASE 2: CAPTURE hotwords via STT ───────────────────────────────
  void _switchToCaptureMode() {
    if (_inCaptureMode) return;
    _inCaptureMode = true;

    // Step 1: Stop noise_meter to free the microphone
    _noiseSubscription?.cancel();
    _noiseSubscription = null;
    debugPrint('[Edge AI Audio Engine] Phase 2: noise_meter paused, starting STT capture');

    // Step 2: Start STT after a brief delay to let mic release
    Future.delayed(const Duration(milliseconds: 200), () {
      _startSpeechCapture();
    });

    // Step 3: Set timeout — return to Phase 1 after 8 seconds if no hotword
    _captureTimeout?.cancel();
    _captureTimeout = Timer(const Duration(seconds: 8), () {
      debugPrint('[Edge AI Audio Engine] Capture timeout. Returning to dB monitoring.');
      _stopSpeechCapture();
      _startNoiseMonitoring();
    });
  }

  void _startSpeechCapture() async {
    if (_speechToText == null || !_speechEnabled) {
      debugPrint('[Edge AI Audio Engine] STT not available, returning to monitoring');
      _inCaptureMode = false;
      _startNoiseMonitoring();
      return;
    }

    try {
      if (_speechToText!.isListening) {
        await _speechToText!.stop();
        await Future.delayed(const Duration(milliseconds: 100));
      }

      await _speechToText!.listen(
        onResult: _onSpeechResult,
        listenOptions: SpeechListenOptions(
          listenFor: const Duration(seconds: 7),
          pauseFor: const Duration(seconds: 5),
          partialResults: true,
          cancelOnError: false,
          listenMode: ListenMode.dictation,
        ),
      );
      debugPrint('[Edge AI Audio Engine] STT now actively listening for hotwords...');
    } catch (e) {
      debugPrint('[Edge AI Audio Engine] STT listen failed: $e');
      _inCaptureMode = false;
      _captureTimeout?.cancel();
      _startNoiseMonitoring();
    }
  }

  void _stopSpeechCapture() {
    try {
      _speechToText?.stop();
    } catch (_) {}
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    String words = result.recognizedWords.toLowerCase().trim();
    debugPrint('[STT Recognized]: "$words"');

    for (final word in _distressHotwords) {
      if (words.contains(word)) {
        debugPrint('[Edge AI Audio Engine] 🚨 HOTWORD MATCH: "$word" in "$words"');
        _fireDistressAlert(word);
        break;
      }
    }
  }

  void _fireDistressAlert(String hotword) {
    final now = DateTime.now();
    if (_lastTriggerTime != null && now.difference(_lastTriggerTime!).inSeconds < 15) {
      return; // Cooldown: don't fire again within 15 seconds
    }
    _lastTriggerTime = now;

    // Stop capture mode and return to monitoring
    _captureTimeout?.cancel();
    _stopSpeechCapture();

    _hotwordStreamController.add(
      'Hotword Detected: "${hotword.toUpperCase()}" at ${_currentDecibelLevel.toStringAsFixed(1)} dB',
    );
    debugPrint('[Edge AI Audio Engine] 🚨 DISTRESS ALERT FIRED: $hotword at ${_currentDecibelLevel}dB');

    // Resume dB monitoring after alert cooldown
    Future.delayed(const Duration(seconds: 15), () {
      if (_isListening) _startNoiseMonitoring();
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
    _captureTimeout?.cancel();
    try {
      _noiseSubscription?.cancel();
      _speechToText?.stop();
    } catch (_) {}
    _noiseSubscription = null;
    debugPrint('[Edge AI Audio Engine] Engine stopped.');
  }
}
