import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:safe/services/alert_sound_service.dart';
import 'package:safe/theme/app_theme.dart';
import 'package:safe/widgets/home_widgets/emergency_card/emergency_card.dart';
import 'package:safe/widgets/home_widgets/live_safe/live_safe.dart';

class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  final AlertSoundService _soundService = AlertSoundService();

  void _showSoundPickerModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Select Unsafe Zone Warning Sound',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textDark,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Choose prebuilt alarm tone or pick custom audio file from storage:',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 5 Prebuilt Sound Tiles
                  ...AlertSoundService.prebuiltSounds.map((sound) {
                    final isSelected =
                        _soundService.selectedSoundId == sound.id &&
                            _soundService.customAudioFileName == null;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primaryPurple.withValues(alpha: 0.1)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.primaryPurple
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: ListTile(
                        leading: Text(sound.icon, style: const TextStyle(fontSize: 22)),
                        title: Text(
                          sound.name,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isSelected ? AppTheme.primaryPurple : AppTheme.textDark,
                          ),
                        ),
                        subtitle: Text(
                          sound.description,
                          style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textMuted),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.play_circle_fill_rounded, color: AppTheme.primaryPurple),
                          onPressed: () {
                            _soundService.selectPrebuiltSound(sound.id);
                            setModalState(() {});
                            setState(() {});
                          },
                        ),
                        onTap: () {
                          _soundService.selectPrebuiltSound(sound.id);
                          setModalState(() {});
                          setState(() {});
                          Navigator.pop(context);
                        },
                      ),
                    );
                  }),

                  const SizedBox(height: 8),
                  const Divider(),
                  const SizedBox(height: 8),

                  // Browse Custom Audio File Tile
                  ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      await _soundService.pickCustomAudioFile();
                      setState(() {});
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.folder_open_rounded, size: 20),
                    label: Text(
                      'Browse Custom Sound from Gallery / Storage',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(top: 12, bottom: 100),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Emergency Hub',
                    style: GoogleFonts.outfit(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textDark,
                    ),
                  ),
                  Text(
                    'Direct Hotlines & Proximity Notification Settings',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: AppTheme.primaryPurple,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Emergency Contacts SOS Card
            const EmergencyCard(),
            const SizedBox(height: 14),

            // UNSAFE ZONE PROXIMITY NOTIFICATION & CUSTOM SOUND SETTINGS CARD
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.add_alert_rounded,
                                color: Color(0xFFEF4444),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Unsafe Zone Warning Alert',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textDark,
                              ),
                            ),
                          ],
                        ),
                        Switch(
                          value: _soundService.isProximityAlertEnabled,
                          activeThumbColor: AppTheme.primaryPurple,
                          onChanged: (val) {
                            setState(() {
                              _soundService.isProximityAlertEnabled = val;
                            });
                            Fluttertoast.showToast(
                              msg: val
                                  ? "🟢 Proximity Alerts Active"
                                  : "🔴 Proximity Alerts Disabled",
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Notifies you with an interactive pop-up warning on the map page before entering low safety zones (< 60 rating).',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Custom Alarm Sound Selector Tile
                    GestureDetector(
                      onTap: _showSoundPickerModal,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.music_note_rounded, color: AppTheme.primaryPurple, size: 20),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Alarm Alert Sound',
                                      style: GoogleFonts.outfit(
                                        fontSize: 11,
                                        color: AppTheme.textMuted,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      _soundService.soundDisplayName,
                                      style: GoogleFonts.outfit(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.volume_up_rounded, color: AppTheme.primaryPurple, size: 20),
                                  onPressed: () => _soundService.playPreviewSound(),
                                ),
                                const Icon(Icons.tune_rounded, color: AppTheme.textMuted, size: 18),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Live Safe Spots Component
            const LiveSafe(),
          ],
        ),
      ),
    );
  }
}