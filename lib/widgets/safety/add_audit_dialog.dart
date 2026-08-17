import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:safe/models/safety_audit_models.dart';
import 'package:safe/services/nagpur_safety_service.dart';
import 'package:safe/services/safety_audit_service.dart';
import 'package:safe/theme/app_theme.dart';

class AddAuditDialog extends StatefulWidget {
  final double initialLat;
  final double initialLng;
  final String? initialAddress;
  final VoidCallback? onAuditSubmitted;

  const AddAuditDialog({
    super.key,
    required this.initialLat,
    required this.initialLng,
    this.initialAddress,
    this.onAuditSubmitted,
  });

  @override
  State<AddAuditDialog> createState() => _AddAuditDialogState();
}

class _AddAuditDialogState extends State<AddAuditDialog> {
  int _currentStep = 1;
  bool _isSubmitting = false;

  late double _selectedLat;
  late double _selectedLng;
  late String _addressLabel;

  CategoryTag _categoryTag = CategoryTag.street;
  TimeOfDayPeriod _timeOfDay = TimeOfDayPeriod.day;

  // 9 Core SafetiPin Parameters (1-5 scale)
  int _lighting = 4;
  int _openness = 4;
  int _visibility = 4;
  CrowdDensity _crowd = CrowdDensity.moderate;
  SecurityPresence _security = SecurityPresence.yesOccasional;
  int _walkPath = 4;
  int _publicTransport = 4;
  int _genderDiversity = 4;
  int _feeling = 4;

  final TextEditingController _commentController = TextEditingController();
  String? _photoUrl = 'https://images.unsplash.com/photo-1519501025264-65ba15a82390';

  @override
  void initState() {
    super.initState();
    _selectedLat = widget.initialLat;
    _selectedLng = widget.initialLng;
    _addressLabel = widget.initialAddress ??
        'Location (${_selectedLat.toStringAsFixed(4)}, ${_selectedLng.toStringAsFixed(4)})';
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitAudit() async {
    setState(() => _isSubmitting = true);

    final payload = {
      'user_id': 'USER_DEMO_001',
      'latitude': _selectedLat,
      'longitude': _selectedLng,
      'address_label': _addressLabel,
      'category_tag': _categoryTag.name.toUpperCase(),
      'time_of_day': _timeOfDay.name.toUpperCase(),
      'lighting': _lighting,
      'openness': _openness,
      'visibility': _visibility,
      'crowd': _crowd.name.toUpperCase(),
      'security': _security.name.toUpperCase(),
      'walk_path': _walkPath,
      'public_transport': _publicTransport,
      'gender_diversity': _genderDiversity,
      'feeling': _feeling,
      'comment': _commentController.text.trim().isEmpty
          ? null
          : _commentController.text.trim(),
      'photo_url': _photoUrl,
    };

    final result = await SafetyAuditService().submitAudit(payload);
    
    // Recalculate dynamic safety score for nearest locality
    final updatedLocality = NagpurSafetyService().updateLocalityWithAudit(
      lat: _selectedLat,
      lon: _selectedLng,
      auditData: payload,
    ) ?? NagpurSafetyService().getNearestLocality(_selectedLat, _selectedLng)?.locality;

    setState(() => _isSubmitting = false);

    if (mounted) {
      Navigator.of(context).pop();
      widget.onAuditSubmitted?.call();
      _showPointsCelebrationDialog(result?.pointsAwarded ?? 65, updatedLocality);
    }
  }

  void _showPointsCelebrationDialog(int pts, NagpurLocality? locality) {
    Color tierColor = const Color(0xFF10B981);
    if (locality != null) {
      if (locality.safetyScore >= 80) tierColor = const Color(0xFF10B981);
      else if (locality.safetyScore >= 60) tierColor = const Color(0xFF3B82F6);
      else if (locality.safetyScore >= 45) tierColor = const Color(0xFFF59E0B);
      else tierColor = const Color(0xFFEF4444);
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1035),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: AppTheme.accentNeonPurple.withValues(alpha: 0.5), width: 1.5),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 54)),
            const SizedBox(height: 12),
            Text(
              '+$pts Safety Points Earned!',
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF10B981),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Your contribution directly updated community safety intelligence.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: Colors.white70),
            ),

            if (locality != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: tierColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: tierColor.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.shield_rounded, color: tierColor, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            locality.place,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Updated Safety Score',
                            style: GoogleFonts.inter(fontSize: 11, color: Colors.white60),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${locality.safetyScore.toStringAsFixed(1)} / 100',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: tierColor,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: tierColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            locality.riskTier,
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: tierColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryPurple,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Awesome!',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF180B2E),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(
          color: AppTheme.accentNeonPurple.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white38,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header & Step indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Audit Location Safety',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.accentNeonPurple.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.accentNeonPurple.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    'Step $_currentStep of 3',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Step Content
            if (_currentStep == 1) _buildStep1(),
            if (_currentStep == 2) _buildStep2(),
            if (_currentStep == 3) _buildStep3(),

            const SizedBox(height: 24),

            // Navigation Buttons
            Row(
              children: [
                if (_currentStep > 1)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _currentStep--),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white54),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text('Back', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                  ),
                if (_currentStep > 1) const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSubmitting
                        ? null
                        : () {
                            if (_currentStep < 3) {
                              setState(() => _currentStep++);
                            } else {
                              _submitAudit();
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryPurple,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _currentStep < 3 ? 'Next Step →' : 'Submit Audit (+50 Pts)',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: 15,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF261447),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            children: [
              const Icon(Icons.location_on_rounded, color: AppTheme.accentNeonPurple, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _addressLabel,
                  style: GoogleFonts.inter(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w500),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text('Category Tag', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: CategoryTag.values.map((tag) {
            final isSelected = _categoryTag == tag;
            return ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(tag.icon, size: 16, color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.9)),
                  const SizedBox(width: 6),
                  Text(tag.displayName, style: GoogleFonts.inter(color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.9), fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                ],
              ),
              selected: isSelected,
              selectedColor: AppTheme.primaryPurple,
              backgroundColor: const Color(0xFF2D1B4E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: isSelected ? AppTheme.accentNeonPurple : Colors.white24, width: 1.2),
              ),
              onSelected: (val) => setState(() => _categoryTag = tag),
            );
          }).toList(),
        ),
        const SizedBox(height: 18),
        Text('Time of Day', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF261447),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24),
          ),
          child: SegmentedButton<TimeOfDayPeriod>(
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppTheme.primaryPurple;
                }
                return Colors.transparent;
              }),
              foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.white;
                }
                return Colors.white70;
              }),
            ),
            segments: const [
              ButtonSegment(value: TimeOfDayPeriod.day, label: Text('☀️ Day')),
              ButtonSegment(value: TimeOfDayPeriod.evening, label: Text('🌆 Evening')),
              ButtonSegment(value: TimeOfDayPeriod.night, label: Text('🌙 Night')),
            ],
            selected: {_timeOfDay},
            onSelectionChanged: (val) => setState(() => _timeOfDay = val.first),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Score 9 Core Safety Parameters (1=Poor, 5=Excellent)',
          style: GoogleFonts.inter(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 14),
        _buildSliderTile('💡 Lighting', _lighting, (v) => setState(() => _lighting = v.toInt())),
        _buildSliderTile('👁️ Openness / Blindspots', _openness, (v) => setState(() => _openness = v.toInt())),
        _buildSliderTile('🔭 Visibility from Distance', _visibility, (v) => setState(() => _visibility = v.toInt())),
        _buildSliderTile('🚶 Walk Path / Footpath Quality', _walkPath, (v) => setState(() => _walkPath = v.toInt())),
        _buildSliderTile('🚌 Public Transport Proximity', _publicTransport, (v) => setState(() => _publicTransport = v.toInt())),
        _buildSliderTile('👩‍👩‍👧 Gender Diversity Present', _genderDiversity, (v) => setState(() => _genderDiversity = v.toInt())),
        _buildSliderTile('🛡️ Overall Feeling of Safety', _feeling, (v) => setState(() => _feeling = v.toInt())),
      ],
    );
  }

  Widget _buildSliderTile(String label, int val, ValueChanged<double> onChanged) {
    Color badgeColor = const Color(0xFF10B981);
    if (val <= 1) badgeColor = const Color(0xFFEF4444);
    else if (val == 2) badgeColor = const Color(0xFFF59E0B);
    else if (val == 3) badgeColor = const Color(0xFFEAB308);
    else if (val == 4) badgeColor = const Color(0xFF3B82F6);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF23123D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: badgeColor, width: 1),
                ),
                child: Text(
                  '$val / 5',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: badgeColor,
              inactiveTrackColor: Colors.white24,
              thumbColor: badgeColor,
              overlayColor: badgeColor.withValues(alpha: 0.2),
              trackHeight: 4,
            ),
            child: Slider(
              value: val.toDouble(),
              min: 1,
              max: 5,
              divisions: 4,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Optional Notes & Photo Evidence (+15 Pts Bonus)',
          style: GoogleFonts.inter(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _commentController,
          maxLength: 280,
          maxLines: 3,
          style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Describe safety hazards, lighting issues, or police presence...',
            hintStyle: GoogleFonts.inter(color: Colors.white38),
            filled: true,
            fillColor: const Color(0xFF261447),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.white24),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppTheme.accentNeonPurple, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF261447),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.accentNeonPurple.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              const Icon(Icons.add_a_photo_rounded, color: AppTheme.accentNeonPurple),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _photoUrl != null ? 'Photo Attached (+10 Pts)' : 'Add Photo Evidence',
                  style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
              Switch(
                value: _photoUrl != null,
                activeTrackColor: AppTheme.accentNeonPurple,
                activeColor: Colors.white,
                onChanged: (val) {
                  setState(() {
                    _photoUrl = val
                        ? 'https://images.unsplash.com/photo-1519501025264-65ba15a82390'
                        : null;
                  });
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
