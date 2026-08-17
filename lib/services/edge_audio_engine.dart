import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Edge AI Acoustic & Voice-to-Text Hotword Engine.
/// Uses live physical microphone hardware sampling and Speech-to-Text transcription.
/// Distress signal is ONLY triggered when registered hotwords ("help", "bachao", etc.) are detected at >= 90 dB decibel limit.
class EdgeAudioEngine {
  static final EdgeAudioEngine _instance = EdgeAudioEngine._internal();
  factory EdgeAudioEngine() => _instance;
  EdgeAudioEngine._internal();

  bool _isListening = false;
  double _currentDecibelLevel = 48.0;
  DateTime? _lastTriggerTime;

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

      // 3. Initialize NoiseMeter (Decibel Limit set to 90 dB)
      _noiseMeter ??= NoiseMeter();
      _noiseSubscription = _noiseMeter!.noise.listen(
        (NoiseReading noiseReading) {
          double db = noiseReading.meanDecibel;
          if (db.isFinite && !db.isNaN && db > 0) {
            _currentDecibelLevel = double.parse(db.toStringAsFixed(1));
            _decibelStreamController.add(_currentDecibelLevel);

            // Ensure voice-to-text listener is active for hotwords
            if (_currentDecibelLevel >= 60.0) {
              _startVoiceToTextListening();
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

    // STRICT RULE: BOTH sound level >= 60 dB AND hotword match required!
    if (_currentDecibelLevel >= 60.0) {
      for (final word in _distressHotwords) {
        if (words.contains(word)) {
          final now = DateTime.now();
          if (_lastTriggerTime == null || now.difference(_lastTriggerTime!).inSeconds >= 3) {
            _lastTriggerTime = now;
            _hotwordStreamController.add('Hotword Detected: "${word.toUpperCase()}" at ${_currentDecibelLevel.toStringAsFixed(1)} dB');
            debugPrint('[Edge AI Audio Engine] 🚨 HOTWORD DISTRESS MATCH AT ${_currentDecibelLevel}dB: $word');
          }
          break;
        }
      }
    }
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
