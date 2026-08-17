import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

enum TravelMode { car, walk }

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
      srcLoc = getNearestLocality(srcLat, srcLon)?.locality ??
          searchLocalities('Waranga').firstOrNull ??
          _getFallbackLocalities().first;
    } else {
      srcLoc = searchLocalities(sourceName).firstOrNull ??
          _localities.firstOrNull ??
          _getFallbackLocalities().first;
      srcLat = srcLoc.lat;
      srcLon = srcLoc.lon;
    }

    final destLoc = searchLocalities(destName).firstOrNull ??
        (_localities.length > 1 ? _localities[1] : _getFallbackLocalities().last);

    final straightLineDist = _haversineDistanceKm(srcLat, srcLon, destLoc.lat, destLoc.lon);

    double distanceKm;
    int safestDuration;

    if (travelMode == TravelMode.walk) {
      distanceKm = double.parse((straightLineDist * 1.35).toStringAsFixed(1));
      if (distanceKm < 1.0) distanceKm = 1.2;
      safestDuration = ((distanceKm / 4.8) * 60).round();
    } else {
      final rawDrivingKm = straightLineDist * 1.52;
      distanceKm = double.parse((rawDrivingKm > 0.8 ? rawDrivingKm : 2.5).toStringAsFixed(1));

      double trafficFactor = 1.18;
      if ((hour >= 8 && hour <= 11) || (hour >= 17 && hour <= 20)) {
        trafficFactor = 1.42;
      } else if (hour >= 22 || hour <= 5) {
        trafficFactor = 0.95;
      }
      safestDuration = ((distanceKm / 31.0) * 60 * trafficFactor).round().clamp(3, 180);
    }

    final baseRawScore = (srcLoc.safetyScore + destLoc.safetyScore) / 20.0;

    double timeOfDayModifier = 0.0;
    int safestLighting = 92;
    int fastestLighting = 60;
    String safestCrowd = 'High / Active Footfall';
    String fastestCrowd = 'Low / Isolated Stretch';
    String timeOfDayLabel = '☀️ Daytime Mode (6 AM - 6 PM)';

    if (isDay) {
      timeOfDayModifier = 0.8;
      safestLighting = 100;
      fastestLighting = 100;
      safestCrowd = 'High / Active Daylight Footfall';
      fastestCrowd = 'Moderate / Regular Traffic';
      timeOfDayLabel = '☀️ Daytime Mode (6 AM - 6 PM)';
    } else if (isEvening) {
      timeOfDayModifier = 0.0;
      safestLighting = 92;
      fastestLighting = 65;
      safestCrowd = 'Active Evening Commercial Footfall';
      fastestCrowd = 'Reduced Evening Traffic';
      timeOfDayLabel = '🌆 Evening Mode (6 PM - 9 PM)';
    } else {
      timeOfDayModifier = -1.6;
      safestLighting = 88;
      fastestLighting = 45;
      safestCrowd = 'Moderate / Patrolled Route';
      fastestCrowd = 'Low / Dark Isolated Bypass';
      timeOfDayLabel = '🌙 Night Mode (9 PM - 6 AM)';
    }

    final modePenalty = travelMode == TravelMode.walk ? (isNight ? -1.8 : -0.4) : 0.0;
    final safestIndex = (baseRawScore + timeOfDayModifier + modePenalty).clamp(4.5, 9.8);

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

    final fastestPenalty = isNight ? -2.4 : -1.2;
    final fastestIndex = (safestIndex + fastestPenalty).clamp(3.8, 8.2);
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
      srcLoc = getNearestLocality(srcLat, srcLon)?.locality ??
          searchLocalities('Waranga').firstOrNull ??
          _getFallbackLocalities().first;
    } else {
      srcLoc = searchLocalities(sourceName).firstOrNull ??
          _localities.firstOrNull ??
          _getFallbackLocalities().first;
      srcLat = srcLoc.lat;
      srcLon = srcLoc.lon;
    }

    final destLoc = searchLocalities(destName).firstOrNull ??
        (_localities.length > 1 ? _localities[1] : _getFallbackLocalities().last);

    double distanceKm;
    int durationMinutes;

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
          final durSecs = (routes[0]['duration'] as num).toDouble();
          distanceKm = double.parse((distMeters / 1000.0).toStringAsFixed(1));
          durationMinutes = (durSecs / 60.0).round();
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
        durationMinutes = ((distanceKm / 4.8) * 60).round();
      } else {
        distanceKm = double.parse((straightLine * 1.52).toStringAsFixed(1));
        if (distanceKm < 1.0) distanceKm = 2.5;
        durationMinutes = ((distanceKm / 31.0) * 60 * 1.18).round();
      }
    }

    final baseRawScore = (srcLoc.safetyScore + destLoc.safetyScore) / 20.0;

    double timeOfDayModifier = 0.0;
    int safestLighting = 92;
    int fastestLighting = 60;
    String safestCrowd = 'High / Active Footfall';
    String fastestCrowd = 'Low / Isolated Stretch';
    String timeOfDayLabel = '☀️ Daytime Mode (6 AM - 6 PM)';

    if (isDay) {
      timeOfDayModifier = 0.8;
      safestLighting = 100;
      fastestLighting = 100;
      safestCrowd = 'High / Active Daylight Footfall';
      fastestCrowd = 'Moderate / Regular Traffic';
      timeOfDayLabel = '☀️ Daytime Mode (6 AM - 6 PM)';
    } else if (isEvening) {
      timeOfDayModifier = 0.0;
      safestLighting = 92;
      fastestLighting = 65;
      safestCrowd = 'Active Evening Commercial Footfall';
      fastestCrowd = 'Reduced Evening Traffic';
      timeOfDayLabel = '🌆 Evening Mode (6 PM - 9 PM)';
    } else {
      timeOfDayModifier = -1.6;
      safestLighting = 88;
      fastestLighting = 45;
      safestCrowd = 'Moderate / Patrolled Route';
      fastestCrowd = 'Low / Dark Isolated Bypass';
      timeOfDayLabel = '🌙 Night Mode (9 PM - 6 AM)';
    }

    final modePenalty = travelMode == TravelMode.walk ? (isNight ? -1.8 : -0.4) : 0.0;
    final safestIndex = (baseRawScore + timeOfDayModifier + modePenalty).clamp(4.5, 9.8);

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

    final fastestPenalty = isNight ? -2.4 : -1.2;
    final fastestIndex = (safestIndex + fastestPenalty).clamp(3.8, 8.2);
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

