import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:safe/models/safety_audit_models.dart';
import 'package:safe/services/nagpur_safety_service.dart';
import 'package:safe/services/safety_audit_service.dart';
import 'package:safe/theme/app_theme.dart';
import 'package:safe/widgets/safety/safety_leaderboard_screen.dart';

class ContributionScreen extends StatefulWidget {
  const ContributionScreen({super.key});

  @override
  State<ContributionScreen> createState() => _ContributionScreenState();
}

class _ContributionScreenState extends State<ContributionScreen> {
  final NagpurSafetyService _nagpurService = NagpurSafetyService();
  final SafetyAuditService _auditService = SafetyAuditService();

  int _selectedTab = 0; // 0: Contribute, 1: Timeline
  int _userPoints = 63;
  int _totalContributeActions = 5;
  int _userLevel = 1;
  int _rateNearbyCount = 2;
  int _rateNearbyPoints = 50;

  bool _isSubmitting = false;
  String _selectedLocalityName = 'Sitabuldi';
  double _selectedLat = 21.1458;
  double _selectedLng = 79.0882;

  String? _attachedPhotoPath;
  String? _attachedPhotoName;

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

  Future<void> _pickPhoto(StateSetter setModalState) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1B4B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Select Photo Source',
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: AppTheme.accentCyan, size: 28),
                title: Text('📸 Take Photo with Camera', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final ImagePicker picker = ImagePicker();
                  final XFile? image = await picker.pickImage(source: ImageSource.camera);
                  if (image != null) {
                    setModalState(() {
                      _attachedPhotoPath = image.path;
                      _attachedPhotoName = image.name;
                    });
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: AppTheme.accentMint, size: 28),
                title: Text('🖼️ Choose from Photo Gallery', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final ImagePicker picker = ImagePicker();
                  final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                  if (image != null) {
                    setModalState(() {
                      _attachedPhotoPath = image.path;
                      _attachedPhotoName = image.name;
                    });
                  }
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  void _openMakeContributionSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.88,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppTheme.purpleHeroGradient,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: const [
                  BoxShadow(color: Colors.black38, blurRadius: 24, offset: Offset(0, -6)),
                ],
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 48,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.white60,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.25),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.rate_review_rounded, color: Colors.white, size: 22),
                            ),
                            const SizedBox(width: 10),
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
                        IconButton(
                          onPressed: () => Navigator.pop(modalCtx),
                          icon: const Icon(Icons.close_rounded, color: Colors.white),
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
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white38),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedLocalityName,
                          dropdownColor: AppTheme.primaryPurple,
                          isExpanded: true,
                          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
                          items: (_nagpurService.localities.isNotEmpty
                                  ? _nagpurService.localities
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
                              setModalState(() {
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
                    _buildModalRatingSlider('💡 Street Lighting', _lighting, (val) => setModalState(() => _lighting = val)),
                    const SizedBox(height: 12),

                    // 2. Openness Slider
                    _buildModalRatingSlider('👁️ Openness & Visibility', _openness, (val) => setModalState(() => _openness = val)),
                    const SizedBox(height: 12),

                    // 3. Walk Path Quality
                    _buildModalRatingSlider('🚶 Footpath & Walk Path', _walkPath, (val) => setModalState(() => _walkPath = val)),
                    const SizedBox(height: 12),

                    // 4. Overall Feeling Score
                    _buildModalRatingSlider('🛡️ Safety Perception / Feeling', _feeling, (val) => setModalState(() => _feeling = val)),
                    const SizedBox(height: 16),

                    // Crowd Density Selector (High Contrast Custom Pills - 100% Text Visible)
                    Text('👥 Crowd Footfall Density:', style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: CrowdDensity.values.map((c) {
                        final isSelected = _crowd == c;
                        return InkWell(
                          onTap: () => setModalState(() => _crowd = c),
                          borderRadius: BorderRadius.circular(20),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected ? Colors.white : Colors.white38,
                                width: isSelected ? 2.0 : 1.2,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: Colors.white.withValues(alpha: 0.3),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isSelected) ...[
                                  const Icon(Icons.check_rounded, color: AppTheme.primaryPurple, size: 16),
                                  const SizedBox(width: 4),
                                ],
                                Text(
                                  c.name.toUpperCase(),
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? AppTheme.primaryPurple : Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Observation Notes & Camera Photo Attachment
                    Text('📝 Incident Notes / Observations:', style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _commentController,
                      style: GoogleFonts.outfit(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'e.g. Well-lit street, active CCTV cameras present...',
                        hintStyle: GoogleFonts.outfit(color: Colors.white60),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.15),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Camera / Photo Attachment Row with Direct Camera Option
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _pickPhoto(setModalState),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white70, width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                          icon: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 20),
                          label: Text('📷 Add Photo / Camera', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                        if (_attachedPhotoName != null) ...[
                          const SizedBox(width: 10),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF10B981), width: 1.5),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.image_rounded, color: Colors.white, size: 16),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      _attachedPhotoName!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      setModalState(() {
                                        _attachedPhotoPath = null;
                                        _attachedPhotoName = null;
                                      });
                                    },
                                    child: const Icon(Icons.close_rounded, color: Colors.white70, size: 16),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : () async {
                          Navigator.pop(modalCtx);
                          await _submitAudit();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        icon: const Icon(Icons.stars_rounded, color: Colors.white, size: 24),
                        label: Text(
                          'Submit Audit & Claim +50 Pts 🎁',
                          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildModalRatingSlider(String label, int value, ValueChanged<int> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: GoogleFonts.outfit(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
            Text('$value / 5', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
        Slider(
          value: value.toDouble(),
          min: 1,
          max: 5,
          divisions: 4,
          activeColor: Colors.white,
          inactiveColor: Colors.white38,
          onChanged: (val) => onChanged(val.round()),
        ),
      ],
    );
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
      'photo_url': _attachedPhotoPath,
      'comment': _commentController.text.trim().isEmpty
          ? "Verified safety parameters for $_selectedLocalityName."
          : _commentController.text.trim(),
    };

    try {
      final audit = await _auditService.submitAudit(payload);

      // Dynamically recalculate Nagpur locality score
      _nagpurService.updateLocalityWithAudit(
        lat: _selectedLat,
        lon: _selectedLng,
        auditData: payload,
      );

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _userPoints += 50;
          _totalContributeActions += 1;
          _rateNearbyCount += 1;
          _rateNearbyPoints += 50;
          if (_userPoints >= 100 && _userLevel == 1) {
            _userLevel = 2;
          }
          if (audit != null) {
            _recentAudits.insert(0, audit);
          }
          _attachedPhotoPath = null;
          _attachedPhotoName = null;
        });
        Fluttertoast.showToast(
          msg: "🎉 Audit Submitted! +50 Pts Added to Profile!",
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
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Profile Header Matching Safety Audit Theme & Black Text
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.primaryPurple.withValues(alpha: 0.15),
                          border: Border.all(color: AppTheme.primaryPurple, width: 2),
                        ),
                        child: Center(
                          child: Text(
                            'N',
                            style: GoogleFonts.outfit(
                              color: AppTheme.primaryPurple,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Nikhil Makhija',
                            style: GoogleFonts.outfit(
                              color: AppTheme.textDark,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Safeti-Starter • Safety Hero',
                            style: GoogleFonts.outfit(
                              color: AppTheme.textMuted,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (ctx) => const SafetyLeaderboardScreen()),
                      );
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: AppTheme.glassCardDecoration(
                        borderColor: AppTheme.primaryPurple.withValues(alpha: 0.4),
                      ),
                      child: Row(
                        children: [
                          const Text('🏆 ', style: TextStyle(fontSize: 14)),
                          Text(
                            'Leaderboard',
                            style: GoogleFonts.outfit(
                              color: AppTheme.primaryPurple,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 3 Key Stats Grid (Point, Contribute, Level) in Dark Text & Purple Accents
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: AppTheme.glassCardDecoration(),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatColumn('$_userPoints', 'Point'),
                    _buildStatColumn('$_totalContributeActions', 'Contribute'),
                    _buildStatColumn('$_userLevel', 'Level'),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Levels Completed Medals Carousel Header
              Text(
                'Levels completed',
                style: GoogleFonts.outfit(
                  color: AppTheme.textDark,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              // Medals Horizontal Scroll
              SizedBox(
                height: 100,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildMedalBadge('🏅 Level 1', '$_userPoints Pts', const Color(0xFFF59E0B), isUnlocked: true),
                    const SizedBox(width: 12),
                    _buildMedalBadge('🥈 Level 2', '100 Pts', AppTheme.primaryPurple, isUnlocked: _userLevel >= 2),
                    const SizedBox(width: 12),
                    _buildMedalBadge('🥉 Level 3', '250 Pts', AppTheme.primaryPurple, isUnlocked: _userLevel >= 3),
                    const SizedBox(width: 12),
                    _buildMedalBadge('💎 Level 4', '500 Pts', const Color(0xFF06B6D4), isUnlocked: false),
                    const SizedBox(width: 12),
                    _buildMedalBadge('👑 Level 5', '1000 Pts', const Color(0xFF10B981), isUnlocked: false),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Contribute vs Timeline Tabbed Switch Bar
              Container(
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.black12, width: 1)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedTab = 0),
                        child: Column(
                          children: [
                            Text(
                              'Contribute',
                              style: GoogleFonts.outfit(
                                color: _selectedTab == 0 ? AppTheme.primaryPurple : AppTheme.textMuted,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              height: 3,
                              color: _selectedTab == 0 ? AppTheme.primaryPurple : Colors.transparent,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedTab = 1),
                        child: Column(
                          children: [
                            Text(
                              'Timeline',
                              style: GoogleFonts.outfit(
                                color: _selectedTab == 1 ? AppTheme.primaryPurple : AppTheme.textMuted,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              height: 3,
                              color: _selectedTab == 1 ? AppTheme.primaryPurple : Colors.transparent,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              if (_selectedTab == 0) ...[
                // Contribution Action Breakdown Table Card (Light Glassmorphism Theme)
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: AppTheme.glassCardDecoration(
                    borderColor: AppTheme.primaryPurple.withValues(alpha: 0.3),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Contribute', style: GoogleFonts.outfit(color: AppTheme.primaryPurple, fontWeight: FontWeight.bold, fontSize: 14)),
                          Text('Number', style: GoogleFonts.outfit(color: AppTheme.primaryPurple, fontWeight: FontWeight.bold, fontSize: 14)),
                          Text('Point', style: GoogleFonts.outfit(color: AppTheme.primaryPurple, fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Highlighted Total Action Box
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryPurple.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.primaryPurple.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total Contribution Actions', style: GoogleFonts.outfit(color: AppTheme.textDark, fontWeight: FontWeight.bold, fontSize: 14)),
                            Text('$_totalContributeActions', style: GoogleFonts.outfit(color: AppTheme.primaryPurple, fontWeight: FontWeight.bold, fontSize: 14)),
                            Text('$_userPoints', style: GoogleFonts.outfit(color: AppTheme.primaryPurple, fontWeight: FontWeight.bold, fontSize: 14)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      _buildActionRow('Rate Nearby Place', '$_rateNearbyCount', '$_rateNearbyPoints'),
                      const Divider(color: Colors.black12),
                      _buildActionRow('Share App', '2', '2'),
                      const Divider(color: Colors.black12),
                      _buildActionRow('Sign Up', '1', '6'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // "➕ Make Contribution" CTA Button (Styled to match SOS & Safety Hero purple hero gradient)
                SizedBox(
                  width: double.infinity,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: AppTheme.purpleHeroGradient,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryPurple.withValues(alpha: 0.35),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: _openMakeContributionSheet,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                      icon: const Icon(Icons.add_location_alt_rounded, color: Colors.white, size: 26),
                      label: Text(
                        '➕ Make Contribution (+50 Pts)',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ] else ...[
                // Timeline List
                Text(
                  'Recent Contribution Activity Timeline',
                  style: GoogleFonts.outfit(color: AppTheme.textDark, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (_recentAudits.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: AppTheme.glassCardDecoration(),
                    child: Center(
                      child: Text(
                        'No contributions yet. Tap "Make Contribution" to submit an audit!',
                        style: GoogleFonts.outfit(color: AppTheme.textMuted, fontSize: 13),
                      ),
                    ),
                  )
                else
                  ..._recentAudits.map((item) => _buildContributionItem(item)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatColumn(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.outfit(
            color: AppTheme.primaryPurple,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.outfit(
            color: AppTheme.textMuted,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildMedalBadge(String title, String pts, Color color, {required bool isUnlocked}) {
    return Container(
      width: 84,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isUnlocked ? color.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isUnlocked ? color : Colors.black12, width: 1.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title.split(' ')[0], style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 4),
          Text(
            title.split(' ')[1],
            style: GoogleFonts.outfit(
              color: isUnlocked ? AppTheme.textDark : AppTheme.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            pts,
            style: GoogleFonts.outfit(
              color: isUnlocked ? color : AppTheme.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow(String action, String number, String points) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(action, style: GoogleFonts.outfit(color: AppTheme.textDark, fontSize: 13, fontWeight: FontWeight.w600)),
          Text(number, style: GoogleFonts.outfit(color: AppTheme.primaryPurple, fontWeight: FontWeight.bold, fontSize: 13)),
          Text(points, style: GoogleFonts.outfit(color: AppTheme.primaryPurple, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildContributionItem(SafetyAudit item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassCardDecoration(),
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
                Text(item.addressLabel, style: GoogleFonts.outfit(color: AppTheme.textDark, fontWeight: FontWeight.bold, fontSize: 14)),
                Text(item.comment ?? 'Verified safety factors.', style: GoogleFonts.outfit(color: AppTheme.textMuted, fontSize: 12)),
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
