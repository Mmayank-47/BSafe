import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:safe/models/safety_audit_models.dart';
import 'package:safe/services/nagpur_safety_service.dart';
import 'package:safe/services/safety_audit_service.dart';
import 'package:safe/theme/app_theme.dart';
import 'package:safe/widgets/safety/gamification_progress_widget.dart';

class ContributionScreen extends StatefulWidget {
  const ContributionScreen({super.key});

  @override
  State<ContributionScreen> createState() => _ContributionScreenState();
}

class _ContributionScreenState extends State<ContributionScreen> {
  final NagpurSafetyService _nagpurService = NagpurSafetyService();
  final SafetyAuditService _auditService = SafetyAuditService();

  bool _isSubmitting = false;
  String _selectedLocalityName = 'Sitabuldi';
  double _selectedLat = 21.1458;
  double _selectedLng = 79.0882;

  final CategoryTag _categoryTag = CategoryTag.street;
  final TimeOfDayPeriod _timeOfDay = TimeOfDayPeriod.night;

  int _lighting = 4;
  int _openness = 4;
  final int _visibility = 4;
  CrowdDensity _crowd = CrowdDensity.moderate;
  final SecurityPresence _security = SecurityPresence.yesOccasional;
  int _walkPath = 4;
  final int _publicTransport = 4;
  final int _genderDiversity = 3;
  int _feeling = 4;

  final TextEditingController _commentController = TextEditingController();
  final List<SafetyAudit> _recentAudits = [];

  @override
  void initState() {
    super.initState();
    _nagpurService.loadSafetyScores().then((_) {
      if (mounted) {
        setState(() {
          _loadLocalityCoordinates();
        });
      }
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _loadLocalityCoordinates() {
    try {
      final loc = _nagpurService.localities.firstWhere(
        (l) => l.place == _selectedLocalityName,
      );
      _selectedLat = loc.lat;
      _selectedLng = loc.lon;
    } catch (_) {}
  }

  Future<void> _submitAudit() async {
    setState(() => _isSubmitting = true);

    final payload = {
      'user_id': 'USER_DEMO_001',
      'latitude': _selectedLat,
      'longitude': _selectedLng,
      'address_label': "$_selectedLocalityName, Nagpur",
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
          ? "Verified safety parameters for $_selectedLocalityName."
          : _commentController.text.trim(),
    };

    try {
      final audit = await _auditService.submitAudit(payload);

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          if (audit != null) {
            _recentAudits.insert(0, audit);
          }
        });
        Fluttertoast.showToast(
          msg: "🎉 Audit Submitted! +50 Gamification Pts Earned!",
          toastLength: Toast.LENGTH_LONG,
          backgroundColor: const Color(0xFF10B981),
        );
        _commentController.clear();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        Fluttertoast.showToast(msg: "Error submitting audit: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localities = _nagpurService.localities;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Safety Contribution',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Audit local areas & earn +50 Gamification Pts',
                        style: GoogleFonts.outfit(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryPurple.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.accentCyan, width: 1.5),
                    ),
                    child: const Icon(Icons.add_location_alt_rounded, color: AppTheme.accentCyan, size: 24),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Gamification Reward Card
              const GamificationProgressWidget(),
              const SizedBox(height: 20),

              // Audit Submission Form Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: AppTheme.glassCardDecoration(borderRadius: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.rate_review_rounded, color: AppTheme.accentMint, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'Audit Locality Safety Factors',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Locality Selector
                    Text('Select Nagpur Area:', style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedLocalityName,
                          dropdownColor: const Color(0xFF1E1B4B),
                          isExpanded: true,
                          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
                          items: (localities.isNotEmpty
                                  ? localities
                                  : [
                                      NagpurLocality(
                                        place: 'Sitabuldi',
                                        lat: 21.1458,
                                        lon: 79.0882,
                                        safetyScore: 85.0,
                                        riskTier: 'Very Safe',
                                        kmeansTier: 'Very Safe',
                                        totalIncidents: 2,
                                        highSeverityCount: 0,
                                        topCrimeTypes: const [],
                                      ),
                                    ])
                              .map((loc) {
                            return DropdownMenuItem<String>(
                              value: loc.place,
                              child: Text('${loc.place} (Score: ${loc.safetyScore.toStringAsFixed(0)}/100)'),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedLocalityName = val;
                                _loadLocalityCoordinates();
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 1. Lighting Level Slider
                    _buildRatingSlider('💡 Street Lighting', _lighting, (val) => setState(() => _lighting = val)),
                    const SizedBox(height: 12),

                    // 2. Openness Slider
                    _buildRatingSlider('👁️ Openness & Visibility', _openness, (val) => setState(() => _openness = val)),
                    const SizedBox(height: 12),

                    // 3. Walk Path Quality
                    _buildRatingSlider('🚶 Footpath & Walk Path', _walkPath, (val) => setState(() => _walkPath = val)),
                    const SizedBox(height: 12),

                    // 4. Overall Feeling Score
                    _buildRatingSlider('🛡️ Safety Perception / Feeling', _feeling, (val) => setState(() => _feeling = val)),
                    const SizedBox(height: 16),

                    // Crowd Density Selector
                    Text('👥 Crowd Footfall Density:', style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: CrowdDensity.values.map((c) {
                        final isSelected = _crowd == c;
                        return ChoiceChip(
                          label: Text(c.name.toUpperCase(), style: GoogleFonts.outfit(fontSize: 12, color: Colors.white)),
                          selected: isSelected,
                          selectedColor: AppTheme.primaryPurple,
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                          onSelected: (_) => setState(() => _crowd = c),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Comments / Observation Notes
                    Text('📝 Incident Notes / Observations:', style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _commentController,
                      style: GoogleFonts.outfit(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'e.g. Well-lit street, active CCTV cameras present...',
                        hintStyle: GoogleFonts.outfit(color: Colors.white38),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.08),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : _submitAudit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        icon: _isSubmitting
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.stars_rounded, color: Colors.white, size: 24),
                        label: Text(
                          _isSubmitting ? 'Submitting Audit...' : 'Submit Audit & Claim +50 Pts 🎁',
                          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Recent Contributions Feed
              if (_recentAudits.isNotEmpty) ...[
                Text(
                  'Your Recent Audit Contributions',
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ..._recentAudits.map((item) => _buildContributionItem(item)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRatingSlider(String label, int value, ValueChanged<int> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: GoogleFonts.outfit(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
            Text('$value / 5', style: GoogleFonts.outfit(color: AppTheme.accentCyan, fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
        Slider(
          value: value.toDouble(),
          min: 1,
          max: 5,
          divisions: 4,
          activeColor: AppTheme.accentCyan,
          inactiveColor: Colors.white24,
          onChanged: (val) => onChanged(val.round()),
        ),
      ],
    );
  }

  Widget _buildContributionItem(SafetyAudit item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassCardDecoration(borderRadius: 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.2), shape: BoxShape.circle),
            child: const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.addressLabel, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                Text(item.comment ?? 'Verified safety factors.', style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: AppTheme.primaryPurple, borderRadius: BorderRadius.circular(12)),
            child: Text('+50 Pts', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
          ),
        ],
      ),
    );
  }
}
