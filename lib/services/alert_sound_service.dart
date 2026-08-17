import 'package:file_picker/file_picker.dart';
import 'package:fluttertoast/fluttertoast.dart';

class PrebuiltSound {
  final String id;
  final String name;
  final String description;
  final String icon;

  const PrebuiltSound({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
  });
}

class AlertSoundService {
  static final AlertSoundService _instance = AlertSoundService._internal();
  factory AlertSoundService() => _instance;
  AlertSoundService._internal();

  bool isProximityAlertEnabled = true;
  String selectedSoundId = 'siren';
  String? customAudioFileName;
  String? customAudioFilePath;

  static const List<PrebuiltSound> prebuiltSounds = [
    PrebuiltSound(
      id: 'siren',
      name: 'Emergency Siren',
      description: 'High-decibel multi-tone emergency siren',
      icon: '🚨',
    ),
    PrebuiltSound(
      id: 'chime',
      name: 'High Pitch Chime',
      description: 'Crisp repeating warning chime',
      icon: '🔔',
    ),
    PrebuiltSound(
      id: 'pulse',
      name: 'Danger Pulse Tone',
      description: 'Rapid repeating radar pulse alert',
      icon: '⚠️',
    ),
    PrebuiltSound(
      id: 'whistle',
      name: 'Police Whistle',
      description: 'Acoustic police whistle warning',
      icon: '📢',
    ),
    PrebuiltSound(
      id: 'radar',
      name: 'Radar Buzz Alert',
      description: 'Dynamic frequency sweep buzz alert',
      icon: '⚡',
    ),
  ];

  PrebuiltSound get currentSound {
    return prebuiltSounds.firstWhere(
      (s) => s.id == selectedSoundId,
      orElse: () => prebuiltSounds.first,
    );
  }

  String get soundDisplayName {
    if (customAudioFileName != null) {
      return '📁 Custom: $customAudioFileName';
    }
    return '${currentSound.icon} ${currentSound.name}';
  }

  void selectPrebuiltSound(String soundId) {
    selectedSoundId = soundId;
    customAudioFileName = null;
    customAudioFilePath = null;
    playPreviewSound();
  }

  Future<void> pickCustomAudioFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        customAudioFilePath = result.files.single.path;
        customAudioFileName = result.files.single.name;
        Fluttertoast.showToast(
          msg: "🎵 Custom Alarm Sound Set: $customAudioFileName",
          toastLength: Toast.LENGTH_LONG,
        );
        playPreviewSound();
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Could not open file picker. Select prebuilt sound.");
    }
  }

  void playPreviewSound() {
    final name = soundDisplayName;
    Fluttertoast.showToast(
      msg: "🔊 Playing Sound Preview: $name",
      toastLength: Toast.LENGTH_SHORT,
    );
  }
}
