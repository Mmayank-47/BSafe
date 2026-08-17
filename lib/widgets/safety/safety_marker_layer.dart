import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:safe/models/safety_audit_models.dart';

typedef OnSafetyMarkerTapped = void Function(SafetyLocation location);

class SafetyMarkerLayer extends StatelessWidget {
  final List<SafetyLocation> locations;
  final OnSafetyMarkerTapped? onMarkerTapped;

  const SafetyMarkerLayer({
    super.key,
    required this.locations,
    this.onMarkerTapped,
  });

  @override
  Widget build(BuildContext context) {
    return MarkerLayer(
      markers: locations.map((loc) {
        return Marker(
          point: LatLng(loc.latitude, loc.longitude),
          width: 44,
          height: 44,
          child: GestureDetector(
            onTap: () => onMarkerTapped?.call(loc),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                color: loc.color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: loc.color.withValues(alpha: 0.5),
                    blurRadius: 10,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  loc.safetyScore.toStringAsFixed(1),
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
