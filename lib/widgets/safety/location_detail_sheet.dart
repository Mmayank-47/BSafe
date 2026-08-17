import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:safe/services/safety_audit_service.dart';
import 'package:safe/theme/app_theme.dart';

class LocationDetailSheet extends StatefulWidget {
  final String locationId;

  const LocationDetailSheet({
    super.key,
    required this.locationId,
  });

  @override
  State<LocationDetailSheet> createState() => _LocationDetailSheetState();
}

class _LocationDetailSheetState extends State<LocationDetailSheet> {
  bool _isLoading = true;
  LocationDetailResponseMock? _detail;

  @override
  void initState() {
    super.initState();
    _loadLocationDetail();
  }

  Future<void> _loadLocationDetail() async {
    // Attempt fetch or fallback mock
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      setState(() {
        _isLoading = false;
        _detail = LocationDetailResponseMock(
          id: widget.locationId,
          addressLabel: 'Sitabuldi Metro Station Entrance, Nagpur',
          categoryTag: 'METRO_STATION',
          safetyScore: 4.6,
          scoreColor: 'GREEN',
          auditCount: 12,
          lightingAvg: 4.8,
          opennessAvg: 4.5,
          visibilityAvg: 4.6,
          crowdAvg: 4.2,
          securityAvg: 4.5,
          walkPathAvg: 4.4,
          publicTransportAvg: 4.9,
          genderDiversityAvg: 4.3,
          feelingAvg: 4.7,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF180B2E),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(
          color: AppTheme.accentNeonPurple.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: _isLoading
          ? const SizedBox(
              height: 200,
              child: Center(
                child: CircularProgressIndicator(color: AppTheme.accentNeonPurple),
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white30,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Location header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _detail!.color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(Icons.shield_rounded, color: _detail!.color, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _detail!.addressLabel,
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            '${_detail!.categoryTag} • ${_detail!.auditCount} Community Audits',
                            style: GoogleFonts.inter(fontSize: 13, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _detail!.color,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_detail!.safetyScore.toStringAsFixed(1)} / 5.0',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Parameter breakdown bars
                Text(
                  'SafetiPin 9-Parameter Breakdown',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),

                _buildParamBar('💡 Lighting', _detail!.lightingAvg),
                _buildParamBar('👁️ Openness', _detail!.opennessAvg),
                _buildParamBar('🔭 Visibility', _detail!.visibilityAvg),
                _buildParamBar('👥 Crowd Density', _detail!.crowdAvg),
                _buildParamBar('🛡️ Security Presence', _detail!.securityAvg),
                _buildParamBar('🚶 Walk Path', _detail!.walkPathAvg),
                _buildParamBar('🚌 Public Transport', _detail!.publicTransportAvg),
                _buildParamBar('👩‍👩‍👧 Gender Diversity', _detail!.genderDiversityAvg),
                _buildParamBar('❤️ Overall Feeling', _detail!.feelingAvg),

                const SizedBox(height: 20),

                // Upvote / Confirm accuracy button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await SafetyAuditService().upvoteAudit(widget.locationId, 'USER_DEMO_001');
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('🎉 Thanks for verifying! +10 Points awarded to author.'),
                            backgroundColor: Color(0xFF10B981),
                          ),
                        );
                        Navigator.of(context).pop();
                      }
                    },
                    icon: const Icon(Icons.thumb_up_rounded, color: Colors.white),
                    label: Text(
                      'Confirm Still Accurate (+10 Pts)',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryPurple,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildParamBar(String label, double val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(label, style: GoogleFonts.inter(fontSize: 12, color: Colors.white70)),
          ),
          Expanded(
            flex: 5,
            child: LinearProgressIndicator(
              value: val / 5.0,
              backgroundColor: Colors.white10,
              color: val >= 4.0
                  ? const Color(0xFF10B981)
                  : val >= 3.0
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFFEF4444),
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${val.toStringAsFixed(1)}',
            style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class LocationDetailResponseMock {
  final String id;
  final String addressLabel;
  final String categoryTag;
  final double safetyScore;
  final String scoreColor;
  final int auditCount;
  final double lightingAvg;
  final double opennessAvg;
  final double visibilityAvg;
  final double crowdAvg;
  final double securityAvg;
  final double walkPathAvg;
  final double publicTransportAvg;
  final double genderDiversityAvg;
  final double feelingAvg;

  LocationDetailResponseMock({
    required this.id,
    required this.addressLabel,
    required this.categoryTag,
    required this.safetyScore,
    required this.scoreColor,
    required this.auditCount,
    required this.lightingAvg,
    required this.opennessAvg,
    required this.visibilityAvg,
    required this.crowdAvg,
    required this.securityAvg,
    required this.walkPathAvg,
    required this.publicTransportAvg,
    required this.genderDiversityAvg,
    required this.feelingAvg,
  });

  Color get color {
    if (scoreColor == 'GREEN' || safetyScore >= 4.0) {
      return const Color(0xFF10B981);
    } else if (scoreColor == 'AMBER' || safetyScore >= 3.0) {
      return const Color(0xFFF59E0B);
    } else {
      return const Color(0xFFEF4444);
    }
  }
}
