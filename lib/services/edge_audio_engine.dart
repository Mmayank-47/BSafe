import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Edge AI Acoustic & Voice-to-Text Hotword Engine.
/// Uses live physical microphone hardware sampling and Speech-to-Text transcription.
/// Distress signal triggers when a hotword is spoken at >= 85 dB.
/// Uses a 5-second cross-check window to handle timing mismatch between
/// noise_meter dB readings and speech_to_text word recognition.
class EdgeAudioEngine {
  static final EdgeAudioEngine _instance = EdgeAudioEngine._internal();
  factory EdgeAudioEngine() => _instance;
  EdgeAudioEngine._internal();

  bool _isListening = false;
  double _currentDecibelLevel = 48.0;
  DateTime? _lastTriggerTime;

  // Track hotword and dB independently to cross-check within a time window
  String? _lastMatchedHotword;
  DateTime? _lastHotwordTime;
  DateTime? _lastHighDbTime;
  bool _alreadyFiredForWindow = false;

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
    debugPrint('[Edge AI Audio Engine] Live acoustic & voice-to-text hotword engine initializing...');

    try {
      // 1. Request microphone permission
      PermissionStatus status = await Permission.microphone.status;
      if (!status.isGranted) {
        status = await Permission.microphone.request();
      }

      if (!status.isGranted) {
        debugPrint('[Edge AI Audio Engine] Microphone permission not granted.');
        _isListening = false;
        return;
      }

      // 2. Initialize Speech-To-Text model for continuous hotword tracking
      _initSpeechToText();

      // 3. Initialize NoiseMeter for live decibel tracking
      _noiseMeter ??= NoiseMeter();
      _noiseSubscription = _noiseMeter!.noise.listen(
        (NoiseReading noiseReading) {
          double db = noiseReading.meanDecibel;
          if (db.isFinite && !db.isNaN && db > 0) {
            _currentDecibelLevel = double.parse(db.toStringAsFixed(1));
            _decibelStreamController.add(_currentDecibelLevel);

            // Always keep STT listening for real-time hotword capture
            _startVoiceToTextListening();

            // CHECK 1: dB just crossed 85 — check if a hotword was spoken recently (within 5s)
            if (_currentDecibelLevel >= 85.0) {
              _lastHighDbTime = DateTime.now();
              if (_lastHotwordTime != null &&
                  DateTime.now().difference(_lastHotwordTime!).inSeconds <= 5 &&
                  !_alreadyFiredForWindow) {
                _fireDistressAlert(_lastMatchedHotword ?? 'DISTRESS');
              }
            }
          }
        },
        onError: (Object error) {
          debugPrint('[Edge AI Audio Engine] Microphone noise stream error: $error');
          _isListening = false;
        },
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('[Edge AI Audio Engine] Exception starting audio engine: $e');
      _isListening = false;
    }
  }

  void _initSpeechToText() async {
    try {
      _speechToText ??= SpeechToText();
      _speechEnabled = await _speechToText!.initialize(
        onError: (val) {
          debugPrint('[STT Error] $val');
          if (_isListening) {
            Future.delayed(const Duration(milliseconds: 300), () {
              if (_isListening) _startVoiceToTextListening();
            });
          }
        },
        onStatus: (status) {
          debugPrint('[STT Status] $status');
          if (status == 'done' || status == 'notListening') {
            if (_isListening) {
              Future.delayed(const Duration(milliseconds: 100), () {
                if (_isListening) _startVoiceToTextListening();
              });
            }
          }
        },
      );
      if (_speechEnabled) {
        _startVoiceToTextListening();
      }
    } catch (e) {
      debugPrint('[STT Init Error] $e');
    }
  }

  void _startVoiceToTextListening() async {
    if (_speechToText == null || !_speechEnabled) return;
    if (_speechToText!.isListening) return;

    try {
      await _speechToText!.listen(
        onResult: _onSpeechResult,
        listenOptions: SpeechListenOptions(
          listenFor: const Duration(hours: 1),
          pauseFor: const Duration(seconds: 10),
          partialResults: true,
          cancelOnError: false,
          listenMode: ListenMode.dictation,
        ),
      );
    } catch (e) {
      debugPrint('[STT Listen Exception] $e');
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    String words = result.recognizedWords.toLowerCase().trim();
    debugPrint('[STT Recognized]: $words (Current dB: $_currentDecibelLevel)');

    for (final word in _distressHotwords) {
      if (words.contains(word)) {
        _lastMatchedHotword = word;
        _lastHotwordTime = DateTime.now();
        _alreadyFiredForWindow = false;
        debugPrint('[Edge AI Audio Engine] Hotword "$word" captured. Checking dB...');

        // CHECK 2: Hotword just matched — check if dB was >= 85 recently (within 5s)
        if (_currentDecibelLevel >= 85.0 ||
            (_lastHighDbTime != null &&
             DateTime.now().difference(_lastHighDbTime!).inSeconds <= 5)) {
          _fireDistressAlert(word);
        }
        break;
      }
    }
  }

  void _fireDistressAlert(String hotword) {
    final now = DateTime.now();
    if (_lastTriggerTime != null && now.difference(_lastTriggerTime!).inSeconds < 10) {
      return; // Cooldown: don't fire again within 10 seconds
    }
    _lastTriggerTime = now;
    _alreadyFiredForWindow = true;
    _hotwordStreamController.add('Hotword Detected: "${hotword.toUpperCase()}" at ${_currentDecibelLevel.toStringAsFixed(1)} dB');
    debugPrint('[Edge AI Audio Engine] 🚨 DISTRESS ALERT FIRED: $hotword at ${_currentDecibelLevel}dB');
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
    try {
      _noiseSubscription?.cancel();
      _speechToText?.stop();
    } catch (_) {}
    _noiseSubscription = null;
    debugPrint('[Edge AI Audio Engine] Acoustic & Speech engine stopped.');
  }
}
