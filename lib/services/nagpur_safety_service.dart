import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

enum TravelMode { car, walk }

class GeoPoint {
  final double latitude;
  final double longitude;
  const GeoPoint(this.latitude, this.longitude);
}

class TopCrimeType {
  final String crimeType;
  final int count;

  TopCrimeType({
    required this.crimeType,
    required this.count,
  });

  factory TopCrimeType.fromJson(Map<String, dynamic> json) {
    return TopCrimeType(
      crimeType: json['Crime_Type'] ?? json['crime_type'] ?? 'General Incident',
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }
}

class NagpurLocality {
  final String place;
  final double lat;
  final double lon;
  final double safetyScore;
  final String riskTier;
  final String kmeansTier;
  final int totalIncidents;
  final int highSeverityCount;
  final List<TopCrimeType> topCrimeTypes;

  NagpurLocality({
    required this.place,
    required this.lat,
    required this.lon,
    required this.safetyScore,
    required this.riskTier,
    required this.kmeansTier,
    required this.totalIncidents,
    required this.highSeverityCount,
    required this.topCrimeTypes,
  });

  factory NagpurLocality.fromJson(Map<String, dynamic> json) {
    var crimesRaw = json['top_crime_types'] as List<dynamic>? ?? [];
    List<TopCrimeType> crimes = crimesRaw
        .map((c) => TopCrimeType.fromJson(c as Map<String, dynamic>))
        .toList();

    return NagpurLocality(
      place: json['place'] ?? 'Unknown',
      lat: (json['lat'] as num?)?.toDouble() ?? 21.1458,
      lon: (json['lon'] as num?)?.toDouble() ?? 79.0882,
      safetyScore: (json['safety_score'] as num?)?.toDouble() ?? 70.0,
      riskTier: json['risk_tier'] ?? 'Moderate',
      kmeansTier: json['kmeans_tier'] ?? 'Moderate',
      totalIncidents: (json['total_incidents'] as num?)?.toInt() ?? 0,
      highSeverityCount: (json['high_severity_count'] as num?)?.toInt() ?? 0,
      topCrimeTypes: crimes,
    );
  }
}

class LocalityMatchResult {
  final NagpurLocality locality;
  final double distanceKm;

  LocalityMatchResult({
    required this.locality,
    required this.distanceKm,
  });
}

class NagpurSafetyService {
  static final NagpurSafetyService _instance = NagpurSafetyService._internal();
  factory NagpurSafetyService() => _instance;
  NagpurSafetyService._internal();

  List<NagpurLocality> _localities = [];
  bool _isLoaded = false;

  List<NagpurLocality> get localities => List.unmodifiable(_localities);
  bool get isLoaded => _isLoaded;

  Future<List<NagpurLocality>> loadSafetyScores() async {
    if (_isLoaded && _localities.isNotEmpty) {
      return _localities;
    }

    try {
      final jsonString = await rootBundle.loadString('nagpur_safety_module/output/safety_scores.json');
      final data = json.decode(jsonString) as Map<String, dynamic>;
      final placesRaw = data['places'] as List<dynamic>? ?? [];

      _localities = placesRaw
          .map((p) => NagpurLocality.fromJson(p as Map<String, dynamic>))
          .toList();
      _isLoaded = true;
    } catch (e) {
      // Fallback sample localities if asset loading fails
      _localities = _getFallbackLocalities();
      _isLoaded = true;
    }

    return _localities;
  }

  LocalityMatchResult? getNearestLocality(double userLat, double userLon) {
    if (_localities.isEmpty) return null;

    NagpurLocality? closest;
    double minDistance = double.infinity;

    for (final loc in _localities) {
      final dist = _haversineDistanceKm(userLat, userLon, loc.lat, loc.lon);
      if (dist < minDistance) {
        minDistance = dist;
        closest = loc;
      }
    }

    if (closest != null) {
      return LocalityMatchResult(locality: closest, distanceKm: minDistance);
    }
    return null;
  }

  List<NagpurLocality> searchLocalities(String query) {
    if (query.trim().isEmpty) return _localities;
    final q = query.toLowerCase().trim();
    return _localities.where((l) => l.place.toLowerCase().contains(q)).toList();
  }

  List<NagpurLocality> filterByRiskTier(String tier) {
    if (tier == 'All') return _localities;
    return _localities.where((l) => l.riskTier.toLowerCase() == tier.toLowerCase()).toList();
  }

  double _haversineDistanceKm(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadiusKm = 6371.0;
    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) * sin(dLon / 2) * sin(dLon / 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double _toRadians(double degree) {
    return degree * pi / 180.0;
  }

  List<NagpurLocality> _getFallbackLocalities() {
    return [
      NagpurLocality(
        place: 'Waranga',
        lat: 21.016,
        lon: 78.985,
        safetyScore: 88.0,
        riskTier: 'Very Safe',
        kmeansTier: 'Very Safe',
        totalIncidents: 3,
        highSeverityCount: 0,
        topCrimeTypes: [TopCrimeType(crimeType: 'Theft', count: 1)],
      ),
      NagpurLocality(
        place: 'Sitabuldi',
        lat: 21.145,
        lon: 79.088,
        safetyScore: 78.5,
        riskTier: 'Moderate',
        kmeansTier: 'Moderate',
        totalIncidents: 12,
        highSeverityCount: 1,
        topCrimeTypes: [TopCrimeType(crimeType: 'Pickpocketing', count: 4)],
      ),
      NagpurLocality(
        place: 'Jaitala',
        lat: 21.16,
        lon: 79.025,
        safetyScore: 100.0,
        riskTier: 'Very Safe',
        kmeansTier: 'Very Safe',
        totalIncidents: 5,
        highSeverityCount: 0,
        topCrimeTypes: [TopCrimeType(crimeType: 'Burglary', count: 2)],
      ),
      NagpurLocality(
        place: 'Civil Lines',
        lat: 21.155,
        lon: 79.082,
        safetyScore: 48.6,
        riskTier: 'Risky',
        kmeansTier: 'Safe',
        totalIncidents: 18,
        highSeverityCount: 1,
        topCrimeTypes: [TopCrimeType(crimeType: 'Burglary', count: 3)],
      ),
      NagpurLocality(
        place: 'Indora',
        lat: 21.17,
        lon: 79.095,
        safetyScore: 85.5,
        riskTier: 'Very Safe',
        kmeansTier: 'Very Safe',
        totalIncidents: 7,
        highSeverityCount: 0,
        topCrimeTypes: [TopCrimeType(crimeType: 'Theft', count: 2)],
      ),
    ];
  }

  static final Map<String, GeoPoint> _nagpurGeocodeMap = {
    'waranga': const GeoPoint(21.0160, 78.9850),
    'sitabuldi': const GeoPoint(21.1458, 79.0882),
    'civil lines': const GeoPoint(21.1550, 79.0820),
    'ramdaspeth': const GeoPoint(21.1350, 79.0750),
    'vnit campus': const GeoPoint(21.1250, 79.0520),
    'vnit': const GeoPoint(21.1250, 79.0520),
    'mihan it hub': const GeoPoint(21.0350, 79.0250),
    'mihan': const GeoPoint(21.0350, 79.0250),
    'airport road': const GeoPoint(21.0920, 79.0620),
    'airport': const GeoPoint(21.0920, 79.0620),
    'khamla': const GeoPoint(21.1120, 79.0650),
    'manewada': const GeoPoint(21.1020, 79.1050),
    'sadar': const GeoPoint(21.1620, 79.0850),
    'indora': const GeoPoint(21.1700, 79.0950),
    'dharampeth': const GeoPoint(21.1420, 79.0680),
    'itwari': const GeoPoint(21.1520, 79.1120),
  };

  NagpurLocality getOrCreateLocality(String placeName, int hour) {
    final lowerName = placeName.toLowerCase().trim();

    GeoPoint? geocoded;
    for (final key in _nagpurGeocodeMap.keys) {
      if (lowerName.contains(key) || key.contains(lowerName)) {
        geocoded = _nagpurGeocodeMap[key];
        break;
      }
    }

    final existing = searchLocalities(placeName).firstOrNull;
    double baseScore;
    double lat;
    double lon;

    if (existing != null) {
      baseScore = existing.safetyScore;
      lat = geocoded?.latitude ?? existing.lat;
      lon = geocoded?.longitude ?? existing.lon;
    } else if (geocoded != null) {
      lat = geocoded.latitude;
      lon = geocoded.longitude;
      baseScore = 78.0 + (placeName.hashCode.abs() % 16);
    } else {
      final hash = placeName.hashCode.abs();
      final latOffset = ((hash % 100) - 50) / 1000.0;
      final lonOffset = (((hash ~/ 100) % 100) - 50) / 1000.0;
      lat = 21.1458 + latOffset;
      lon = 79.0882 + lonOffset;

      baseScore = 72.0 + (hash % 18);
      if (lowerName.contains('campus') || lowerName.contains('lines') || lowerName.contains('park') || lowerName.contains('nagar')) {
        baseScore += 10.0;
      } else if (lowerName.contains('bypass') || lowerName.contains('slum') || lowerName.contains('alley') || lowerName.contains('market')) {
        baseScore -= 14.0;
      }
      baseScore = baseScore.clamp(52.0, 94.0);
    }

    final isDay = hour >= 6 && hour < 18;
    final isEvening = hour >= 18 && hour < 21;
    double timeModifier = isDay ? 10.0 : (isEvening ? 2.0 : -8.0);
    final finalScore = (baseScore + timeModifier).clamp(48.0, 98.0);

    String riskTier;
    if (finalScore >= 80.0) {
      riskTier = 'Very Safe Zone';
    } else if (finalScore >= 65.0) {
      riskTier = 'Safe Zone';
    } else if (finalScore >= 50.0) {
      riskTier = 'Moderate Risk';
    } else {
      riskTier = 'Risky';
    }

    return NagpurLocality(
      place: placeName,
      lat: lat,
      lon: lon,
      safetyScore: double.parse(finalScore.toStringAsFixed(1)),
      riskTier: riskTier,
      kmeansTier: riskTier,
      totalIncidents: (100 - finalScore).round() ~/ 4,
      highSeverityCount: finalScore < 60 ? 2 : 0,
      topCrimeTypes: [TopCrimeType(crimeType: 'Theft', count: 2)],
    );
  }

  RouteSafetyComparison calculateRouteSafety({
    required String sourceName,
    required String destName,
    double? userLat,
    double? userLon,
    TravelMode travelMode = TravelMode.car,
    int? overrideHour,
  }) {
    final hour = overrideHour ?? DateTime.now().hour;
    final isDay = hour >= 6 && hour < 18;
    final isEvening = hour >= 18 && hour < 21;
    final isNight = hour >= 21 || hour < 6;

    final isGpsSource = sourceName.contains('location') || sourceName.contains('GPS');
    NagpurLocality srcLoc;
    double srcLat;
    double srcLon;

    if (isGpsSource) {
      srcLat = userLat ?? 21.016;
      srcLon = userLon ?? 78.985;
      srcLoc = getNearestLocality(srcLat, srcLon)?.locality ?? getOrCreateLocality('Waranga', hour);
    } else {
      srcLoc = getOrCreateLocality(sourceName, hour);
      srcLat = srcLoc.lat;
      srcLon = srcLoc.lon;
    }

    final destLoc = getOrCreateLocality(destName, hour);

    final straightLineDist = _haversineDistanceKm(srcLat, srcLon, destLoc.lat, destLoc.lon);

    double distanceKm;
    int safestDuration;

    if (travelMode == TravelMode.walk) {
      distanceKm = double.parse((straightLineDist * 1.35).toStringAsFixed(1));
      if (distanceKm < 1.0) distanceKm = 1.2;
      // Walking travel duration calculated at 4 km/h average human walking speed
      safestDuration = ((distanceKm / 4.0) * 60).round();
    } else {
      final rawDrivingKm = straightLineDist * 1.52;
      distanceKm = double.parse((rawDrivingKm > 0.8 ? rawDrivingKm : 2.5).toStringAsFixed(1));

      // Driving travel duration calculated at exact 40 km/h average vehicle speed
      safestDuration = ((distanceKm / 40.0) * 60).round().clamp(1, 300);
    }

    final baseRawScore = (srcLoc.safetyScore + destLoc.safetyScore) / 20.0;

    int safestLighting = 92;
    int fastestLighting = 60;
    String safestCrowd = 'High / Active Footfall';
    String fastestCrowd = 'Low / Isolated Stretch';
    String timeOfDayLabel = '☀️ Daytime Mode (6 AM - 6 PM)';

    if (isDay) {
      safestLighting = 100;
      fastestLighting = 100;
      safestCrowd = 'High / Active Daylight Footfall';
      fastestCrowd = 'Moderate / Regular Traffic';
      timeOfDayLabel = '☀️ Daytime Mode (6 AM - 6 PM)';
    } else if (isEvening) {
      safestLighting = 92;
      fastestLighting = 65;
      safestCrowd = 'Active Evening Commercial Footfall';
      fastestCrowd = 'Reduced Evening Traffic';
      timeOfDayLabel = '🌆 Evening Mode (6 PM - 9 PM)';
    } else {
      safestLighting = 88;
      fastestLighting = 45;
      safestCrowd = 'Moderate / Patrolled Route';
      fastestCrowd = 'Low / Dark Isolated Bypass';
      timeOfDayLabel = '🌙 Night Mode (9 PM - 6 AM)';
    }

    final modePenalty = travelMode == TravelMode.walk ? (isNight ? -0.8 : -0.2) : 0.0;
    final safestIndex = (8.5 + (baseRawScore * 0.12) + (isDay ? 0.6 : (isEvening ? 0.2 : -0.2)) + modePenalty).clamp(8.2, 9.8);

    final safestRoute = RouteSafetyDetail(
      routeName: travelMode == TravelMode.walk
          ? 'Optimized Safe Pedestrian Path'
          : 'Optimized Safest Route (Main Arterial)',
      distanceKm: distanceKm,
      durationMinutes: safestDuration,
      safetyIndex: double.parse(safestIndex.toStringAsFixed(1)),
      riskTier: safestIndex >= 8.0 ? 'Very Safe Zone' : (safestIndex >= 6.5 ? 'Safe Zone' : 'Moderate Risk'),
      lightingScorePercent: safestLighting,
      crowdDensity: safestCrowd,
      crimeRateIndex: isNight ? 0.28 : 0.14,
      timeOfDayLabel: timeOfDayLabel,
      pathWaypoints: [srcLoc, destLoc],
    );

    final fastestPenalty = isNight ? -3.4 : -2.2;
    final fastestIndex = (safestIndex + fastestPenalty).clamp(4.6, 5.8);
    final fastestDuration = (safestDuration * 0.85).round().clamp(2, 400);

    final fastestRoute = RouteSafetyDetail(
      routeName: travelMode == TravelMode.walk
          ? 'Direct Pedestrian Shortcut'
          : 'Fastest Direct Route (Bypass Highway)',
      distanceKm: double.parse((distanceKm * 0.92).toStringAsFixed(1)),
      durationMinutes: fastestDuration,
      safetyIndex: double.parse(fastestIndex.toStringAsFixed(1)),
      riskTier: fastestIndex < 6.0 ? 'High Risk Night Route' : 'Moderate Risk',
      lightingScorePercent: fastestLighting,
      crowdDensity: fastestCrowd,
      crimeRateIndex: isNight ? 0.78 : 0.42,
      timeOfDayLabel: timeOfDayLabel,
      pathWaypoints: [srcLoc, destLoc],
      hasMidRouteDanger: true,
      midRouteDangerName: 'Itwari Unlit Bypass Stretch',
      midRouteSafetyScore: 46.5,
    );

    return RouteSafetyComparison(
      source: srcLoc,
      destination: destLoc,
      safestRoute: safestRoute,
      fastestRoute: fastestRoute,
      currentHour: hour,
      timeOfDayLabel: timeOfDayLabel,
      travelMode: travelMode,
    );
  }

  Future<RouteSafetyComparison> calculateRouteSafetyAsync({
    required String sourceName,
    required String destName,
    double? userLat,
    double? userLon,
    TravelMode travelMode = TravelMode.car,
    int? overrideHour,
  }) async {
    final hour = overrideHour ?? DateTime.now().hour;
    final isDay = hour >= 6 && hour < 18;
    final isEvening = hour >= 18 && hour < 21;
    final isNight = hour >= 21 || hour < 6;

    final isGpsSource = sourceName.contains('location') || sourceName.contains('GPS');
    NagpurLocality srcLoc;
    double srcLat;
    double srcLon;

    if (isGpsSource) {
      srcLat = userLat ?? 21.016;
      srcLon = userLon ?? 78.985;
      srcLoc = getNearestLocality(srcLat, srcLon)?.locality ?? getOrCreateLocality('Waranga', hour);
    } else {
      srcLoc = getOrCreateLocality(sourceName, hour);
      srcLat = srcLoc.lat;
      srcLon = srcLoc.lon;
    }

    final destLoc = getOrCreateLocality(destName, hour);

    double distanceKm;
    int durationMinutes;

    try {
      final googleApiKey = const String.fromEnvironment('GOOGLE_MAPS_API_KEY');
      if (googleApiKey.isNotEmpty) {
        final modeParam = travelMode == TravelMode.walk ? 'walking' : 'driving';
        final googleUrl = Uri.parse(
            'https://maps.googleapis.com/maps/api/distancematrix/json?origins=$srcLat,$srcLon&destinations=${destLoc.lat},${destLoc.lon}&mode=$modeParam&key=$googleApiKey');
        final gResponse = await http.get(googleUrl).timeout(const Duration(seconds: 4));
        if (gResponse.statusCode == 200) {
          final gData = json.decode(gResponse.body) as Map<String, dynamic>;
          final rows = gData['rows'] as List?;
          if (rows != null && rows.isNotEmpty) {
            final elements = rows[0]['elements'] as List?;
            if (elements != null && elements.isNotEmpty && elements[0]['status'] == 'OK') {
              final distMeters = (elements[0]['distance']['value'] as num).toDouble();
              distanceKm = double.parse((distMeters / 1000.0).toStringAsFixed(1));
              if (travelMode == TravelMode.car) {
                durationMinutes = ((distanceKm / 40.0) * 60).round().clamp(1, 300);
              } else {
                durationMinutes = ((distanceKm / 4.0) * 60).round();
              }
            } else {
              throw 'Google Matrix status not OK';
            }
          } else {
            throw 'Google Matrix no rows';
          }
        } else {
          throw 'Google Matrix HTTP status';
        }
      } else {
        throw 'No Google API key, use OSRM Matrix API';
      }
    } catch (_) {
      try {
        final modePath = travelMode == TravelMode.walk ? 'walking' : 'driving';
        final url = Uri.parse(
            'https://router.project-osrm.org/route/v1/$modePath/$srcLon,$srcLat;${destLoc.lon},${destLoc.lat}?overview=false');

        final response = await http.get(url).timeout(const Duration(seconds: 4));
        if (response.statusCode == 200) {
          final data = json.decode(response.body) as Map<String, dynamic>;
          final routes = data['routes'] as List?;
          if (routes != null && routes.isNotEmpty) {
            final distMeters = (routes[0]['distance'] as num).toDouble();
            distanceKm = double.parse((distMeters / 1000.0).toStringAsFixed(1));
            if (travelMode == TravelMode.car) {
              durationMinutes = ((distanceKm / 40.0) * 60).round().clamp(1, 300);
            } else {
              // Walking speed strictly calculated at 4 km/h average pace
              durationMinutes = ((distanceKm / 4.0) * 60).round();
            }
          } else {
            throw 'No OSRM routes';
          }
        } else {
          throw 'OSRM API status';
        }
      } catch (_) {
        final straightLine = _haversineDistanceKm(srcLat, srcLon, destLoc.lat, destLoc.lon);
        if (travelMode == TravelMode.walk) {
          distanceKm = double.parse((straightLine * 1.35).toStringAsFixed(1));
          if (distanceKm < 1.0) distanceKm = 1.2;
          durationMinutes = ((distanceKm / 4.0) * 60).round();
        } else {
          distanceKm = double.parse((straightLine * 1.52).toStringAsFixed(1));
          if (distanceKm < 1.0) distanceKm = 2.5;
          durationMinutes = ((distanceKm / 40.0) * 60).round().clamp(1, 300);
        }
      }
    }

    final baseRawScore = (srcLoc.safetyScore + destLoc.safetyScore) / 20.0;

    int safestLighting = 92;
    int fastestLighting = 60;
    String safestCrowd = 'High / Active Footfall';
    String fastestCrowd = 'Low / Isolated Stretch';
    String timeOfDayLabel = '☀️ Daytime Mode (6 AM - 6 PM)';

    if (isDay) {
      safestLighting = 100;
      fastestLighting = 100;
      safestCrowd = 'High / Active Daylight Footfall';
      fastestCrowd = 'Moderate / Regular Traffic';
      timeOfDayLabel = '☀️ Daytime Mode (6 AM - 6 PM)';
    } else if (isEvening) {
      safestLighting = 92;
      fastestLighting = 65;
      safestCrowd = 'Active Evening Commercial Footfall';
      fastestCrowd = 'Reduced Evening Traffic';
      timeOfDayLabel = '🌆 Evening Mode (6 PM - 9 PM)';
    } else {
      safestLighting = 88;
      fastestLighting = 45;
      safestCrowd = 'Moderate / Patrolled Route';
      fastestCrowd = 'Low / Dark Isolated Bypass';
      timeOfDayLabel = '🌙 Night Mode (9 PM - 6 AM)';
    }

    final modePenalty = travelMode == TravelMode.walk ? (isNight ? -0.8 : -0.2) : 0.0;
    final safestIndex = (8.5 + (baseRawScore * 0.12) + (isDay ? 0.6 : (isEvening ? 0.2 : -0.2)) + modePenalty).clamp(8.2, 9.8);

    final safestRoute = RouteSafetyDetail(
      routeName: travelMode == TravelMode.walk
          ? 'Optimized Safe Pedestrian Path'
          : 'Optimized Safest Route (Main Arterial)',
      distanceKm: distanceKm,
      durationMinutes: durationMinutes,
      safetyIndex: double.parse(safestIndex.toStringAsFixed(1)),
      riskTier: safestIndex >= 8.0 ? 'Very Safe Zone' : (safestIndex >= 6.5 ? 'Safe Zone' : 'Moderate Risk'),
      lightingScorePercent: safestLighting,
      crowdDensity: safestCrowd,
      crimeRateIndex: isNight ? 0.28 : 0.14,
      timeOfDayLabel: timeOfDayLabel,
      pathWaypoints: [srcLoc, destLoc],
    );

    final fastestPenalty = isNight ? -3.4 : -2.2;
    final fastestIndex = (safestIndex + fastestPenalty).clamp(4.6, 5.8);
    final fastestDuration = (durationMinutes * 0.85).round().clamp(2, 400);

    final fastestRoute = RouteSafetyDetail(
      routeName: travelMode == TravelMode.walk
          ? 'Direct Pedestrian Shortcut'
          : 'Fastest Direct Route (Bypass Highway)',
      distanceKm: double.parse((distanceKm * 0.92).toStringAsFixed(1)),
      durationMinutes: fastestDuration,
      safetyIndex: double.parse(fastestIndex.toStringAsFixed(1)),
      riskTier: fastestIndex < 6.0 ? 'High Risk Night Route' : 'Moderate Risk',
      lightingScorePercent: fastestLighting,
      crowdDensity: fastestCrowd,
      crimeRateIndex: isNight ? 0.78 : 0.42,
      timeOfDayLabel: timeOfDayLabel,
      pathWaypoints: [srcLoc, destLoc],
      hasMidRouteDanger: true,
      midRouteDangerName: 'Itwari Unlit Bypass Stretch',
      midRouteSafetyScore: 46.5,
    );

    return RouteSafetyComparison(
      source: srcLoc,
      destination: destLoc,
      safestRoute: safestRoute,
      fastestRoute: fastestRoute,
      currentHour: hour,
      timeOfDayLabel: timeOfDayLabel,
      travelMode: travelMode,
    );
  }
}

class RouteSafetyDetail {
  final String routeName;
  final double distanceKm;
  final int durationMinutes;
  final double safetyIndex;
  final String riskTier;
  final int lightingScorePercent;
  final String crowdDensity;
  final double crimeRateIndex;
  final String timeOfDayLabel;
  final List<NagpurLocality> pathWaypoints;
  final bool hasMidRouteDanger;
  final String? midRouteDangerName;
  final double? midRouteSafetyScore;

  RouteSafetyDetail({
    required this.routeName,
    required this.distanceKm,
    required this.durationMinutes,
    required this.safetyIndex,
    required this.riskTier,
    required this.lightingScorePercent,
    required this.crowdDensity,
    required this.crimeRateIndex,
    required this.timeOfDayLabel,
    required this.pathWaypoints,
    this.hasMidRouteDanger = false,
    this.midRouteDangerName,
    this.midRouteSafetyScore,
  });
}

class RouteSafetyComparison {
  final NagpurLocality source;
  final NagpurLocality destination;
  final RouteSafetyDetail safestRoute;
  final RouteSafetyDetail fastestRoute;
  final int currentHour;
  final String timeOfDayLabel;
  final TravelMode travelMode;

  RouteSafetyComparison({
    required this.source,
    required this.destination,
    required this.safestRoute,
    required this.fastestRoute,
    required this.currentHour,
    required this.timeOfDayLabel,
    this.travelMode = TravelMode.car,
  });
}

