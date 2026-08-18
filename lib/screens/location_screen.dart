import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:safe/models/safety_audit_models.dart';
import 'package:safe/screens/nagpur_safety_screen.dart';
import 'package:safe/screens/sos_screen.dart';
import 'package:safe/services/alert_sound_service.dart';
import 'package:safe/services/nagpur_safety_service.dart';
import 'package:safe/services/safety_audit_service.dart';
import 'package:safe/theme/app_theme.dart';
import 'package:safe/widgets/safety/location_detail_sheet.dart';
import 'package:safe/widgets/safety/safety_marker_layer.dart';
import 'package:safe/services/women_safety_mesh_sos_service.dart';
import 'package:url_launcher/url_launcher.dart';

class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> with TickerProviderStateMixin {
  double? lat;
  double? long;
  String locationMessage = "Fetching GPS location...";
  String address = "Fetching reverse geocoded address...";
  String mapLink = "";
  StreamSubscription<Position>? _positionSubscription;

  final NagpurSafetyService _nagpurService = NagpurSafetyService();
  final AlertSoundService _soundService = AlertSoundService();

  // Source & Destination Route State
  static const String gpsSourceLabel = "Your current GPS location";
  String _sourceLocalityName = gpsSourceLabel;
  String _destLocalityName = "Sitabuldi";
  final TextEditingController _sourceController = TextEditingController(text: gpsSourceLabel);
  final TextEditingController _destController = TextEditingController(text: "Sitabuldi");
  bool _useSafestRoute = true;
  RouteSafetyComparison? _routeComparison;

  // 10-Second Auto-Dismissing Route Caution Banner State
  bool _show10sRouteBanner = false;
  String _bannerLocalityName = '';
  double _bannerSafetyScore = 0.0;
  Timer? _route10sBannerTimer;

  // 10-Second Blinking Red Screen Flash Alert State
  bool _isBlinkingRedFlashActive = false;
  AnimationController? _redBlinkController;
  Animation<double>? _redBlinkAnimation;
  Timer? _redBlink10sTimer;
  String _redAlertTitle = '';
  String _redAlertSubtitle = '';

  // In-App Turn-By-Turn Navigation Engine State
  bool _isNavigating = false;
  bool _isNavPaused = false;
  Timer? _navTimer;
  double _navProgressFraction = 0.0;
  final MapController _navMapController = MapController();

  // Navigation Pause Safety Check State
  int _pauseEscalationAttempt = 1;
  int _pauseSecondsRemaining = 5;
  Timer? _pauseEscalationTimer;
  bool _isPauseSafetyActive = false;



  List<SafetyLocation> _safetyLocations = [];

  @override
  void initState() {
    super.initState();
    _redBlinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _redBlinkAnimation = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(parent: _redBlinkController!, curve: Curves.easeInOut),
    );
    _initNagpurSafety();
    _fetchSafetyLocations();
    _getCurrentLocation();
  }

  void _trigger2sRedBlinkingAlert(String title, String subtitle) {
    if (!_soundService.isProximityAlertEnabled) return;

    _soundService.playPreviewSound();
    _redBlink10sTimer?.cancel();
    _redBlinkController?.repeat(reverse: true);

    setState(() {
      _isBlinkingRedFlashActive = true;
      _redAlertTitle = title;
      _redAlertSubtitle = subtitle;
    });

    // Auto-dismiss and stop blinking after exactly 2 seconds (30-50 score zone rule)
    _redBlink10sTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        _redBlinkController?.stop();
        setState(() {
          _isBlinkingRedFlashActive = false;
        });
      }
    });
  }

  Future<void> _fetchSafetyLocations() async {
    final locs = await SafetyAuditService().fetchNearbyLocations(
      lat: lat ?? 21.1458,
      lng: long ?? 79.0882,
    );
    if (mounted) {
      setState(() {
        _safetyLocations = locs;
      });
    }
  }

  Future<void> _initNagpurSafety() async {
    await _nagpurService.loadSafetyScores();
    if (mounted) {
      _updateRouteComparison();
    }
  }

  TravelMode _selectedTravelMode = TravelMode.car;

  List<LatLng> _liveRouteWaypoints = [];

  void _updateRouteComparison() async {
    final comparison = await _nagpurService.calculateRouteSafetyAsync(
      sourceName: _sourceLocalityName,
      destName: _destLocalityName,
      userLat: lat,
      userLon: long,
      travelMode: _selectedTravelMode,
    );

    final waypoints = await _nagpurService.fetchRoutePolyline(
      comparison.source.lat,
      comparison.source.lon,
      comparison.destination.lat,
      comparison.destination.lon,
      travelMode: _selectedTravelMode,
    );

    if (mounted) {
      setState(() {
        _routeComparison = comparison;
        _liveRouteWaypoints = waypoints;
      });
    }
  }

  LatLng _getSourceCoordinates() {
    if (_routeComparison != null) {
      return LatLng(_routeComparison!.source.lat, _routeComparison!.source.lon);
    }
    if (_sourceLocalityName != gpsSourceLabel) {
      final created = _nagpurService.getOrCreateLocality(_sourceLocalityName, DateTime.now().hour);
      return LatLng(created.lat, created.lon);
    }
    return LatLng(lat ?? 21.016, long ?? 78.985);
  }

  LatLng _getDestinationCoordinates() {
    if (_routeComparison != null) {
      return LatLng(_routeComparison!.destination.lat, _routeComparison!.destination.lon);
    }
    final created = _nagpurService.getOrCreateLocality(_destLocalityName, DateTime.now().hour);
    return LatLng(created.lat, created.lon);
  }

  void _checkRouteLowestSafetyZone(RouteSafetyComparison comparison) {
    if (!_soundService.isProximityAlertEnabled) return;

    final srcScore = comparison.source.safetyScore;
    final destScore = comparison.destination.safetyScore;

    NagpurLocality lowestLoc = comparison.destination;
    double lowestScore = destScore;

    if (srcScore < lowestScore) {
      lowestLoc = comparison.source;
      lowestScore = srcScore;
    }

    if (lowestScore >= 30.0 && lowestScore <= 50.0) {
      _trigger2sRedBlinkingAlert(
        "🚨 RISKY AREA ALERT (30-50 SCORE)!",
        "Caution: ${lowestLoc.place} (${lowestScore.toStringAsFixed(1)}/100) — Low Safety Rating",
      );

      _route10sBannerTimer?.cancel();
      setState(() {
        _show10sRouteBanner = true;
        _bannerLocalityName = lowestLoc.place;
        _bannerSafetyScore = lowestScore;
      });

      // Auto-dismiss after exactly 2 seconds
      _route10sBannerTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _show10sRouteBanner = false;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _navTimer?.cancel();
    _pauseEscalationTimer?.cancel();
    _route10sBannerTimer?.cancel();
    _redBlink10sTimer?.cancel();
    _redBlinkController?.dispose();
    _sourceController.dispose();
    _destController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw "Location services are disabled.";
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw "Location permission denied.";
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw "Location permission is permanently denied.";
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 4),
        ),
      );
      _updateLocation(position);
      _listenToLocationUpdates();
    } catch (e) {
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) {
          _updateLocation(last);
          _listenToLocationUpdates();
          return;
        }
      } catch (_) {}
      setState(() {
        locationMessage = e.toString();
        lat = 21.1458;
        long = 79.0882;
        address = "Detecting live GPS location...";
        _updateRouteComparison();
      });
    }
  }

  void _updateLocation(Position position) {
    setState(() {
      lat = position.latitude;
      long = position.longitude;
      locationMessage = "Lat: ${lat?.toStringAsFixed(4)} | Lon: ${long?.toStringAsFixed(4)}";
      _getAddress(lat!, long!);
      _updateRouteComparison();
    });
  }

  void _listenToLocationUpdates() {
    _positionSubscription?.cancel();
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 20,
      ),
    ).listen(_updateLocation);
  }

  Future<void> _getAddress(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks =
          await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        final parts = [place.name, place.subLocality, place.locality]
            .where((p) => p != null && p.isNotEmpty)
            .toSet()
            .toList();
        final addrStr = parts.join(', ');
        final localArea = (place.subLocality != null && place.subLocality!.isNotEmpty)
            ? place.subLocality!
            : (place.locality ?? 'Live Location');

        if (mounted) {
          setState(() {
            address = addrStr.isNotEmpty ? addrStr : "Lat: ${latitude.toStringAsFixed(4)}, Lon: ${longitude.toStringAsFixed(4)}";
            if (_sourceLocalityName == gpsSourceLabel) {
              _sourceController.text = "$gpsSourceLabel ($localArea)";
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          address = "Lat: ${latitude.toStringAsFixed(4)}, Lon: ${longitude.toStringAsFixed(4)}";
        });
      }
    }
  }

  bool _isInMidRouteDangerZone = false;
  bool _hasArrivedAtDestination = false;

  String _currentTraversingAreaName = '';
  double _currentTraversingAreaScore = 80.0;

  List<LatLng> _generateGoogleMapsWaypoints(double srcLat, double srcLon, double destLat, double destLon) {
    if (_liveRouteWaypoints.length >= 2) {
      return _liveRouteWaypoints;
    }
    final dLat = destLat - srcLat;
    final dLon = destLon - srcLon;

    return [
      LatLng(srcLat, srcLon),
      LatLng(srcLat + dLat * 0.20 + 0.0016, srcLon + dLon * 0.15 - 0.0014),
      LatLng(srcLat + dLat * 0.42 + 0.0010, srcLon + dLon * 0.45 + 0.0018),
      LatLng(srcLat + dLat * 0.68 - 0.0014, srcLon + dLon * 0.70 + 0.0012),
      LatLng(srcLat + dLat * 0.88 + 0.0006, srcLon + dLon * 0.88 - 0.0005),
      LatLng(destLat, destLon),
    ];
  }

  Map<String, dynamic> _computeNavState(List<LatLng> waypoints, double progress) {
    if (waypoints.isEmpty) {
      return {
        'currentPos': const LatLng(21.1458, 79.0882),
        'bearingRad': 0.0,
        'traversed': <LatLng>[],
        'remaining': <LatLng>[],
        'segmentIndex': 0,
      };
    }

    if (waypoints.length == 1) {
      return {
        'currentPos': waypoints.first,
        'bearingRad': 0.0,
        'traversed': waypoints,
        'remaining': waypoints,
        'segmentIndex': 0,
      };
    }

    final List<double> segDists = [];
    double totalDist = 0.0;
    for (int i = 0; i < waypoints.length - 1; i++) {
      final p1 = waypoints[i];
      final p2 = waypoints[i + 1];
      final dist = math.sqrt(math.pow(p2.latitude - p1.latitude, 2) + math.pow(p2.longitude - p1.longitude, 2));
      segDists.add(dist);
      totalDist += dist;
    }

    if (totalDist == 0.0) {
      return {
        'currentPos': waypoints.first,
        'bearingRad': 0.0,
        'traversed': waypoints,
        'remaining': waypoints,
        'segmentIndex': 0,
      };
    }

    final targetDist = progress.clamp(0.0, 1.0) * totalDist;
    double accumulated = 0.0;
    int segIdx = 0;
    double segFrac = 0.0;

    for (int i = 0; i < segDists.length; i++) {
      if (accumulated + segDists[i] >= targetDist || i == segDists.length - 1) {
        segIdx = i;
        final segLen = segDists[i] > 0 ? segDists[i] : 1.0;
        segFrac = ((targetDist - accumulated) / segLen).clamp(0.0, 1.0);
        break;
      }
      accumulated += segDists[i];
    }

    final pStart = waypoints[segIdx];
    final pEnd = waypoints[segIdx + 1];

    final curLat = pStart.latitude + (pEnd.latitude - pStart.latitude) * segFrac;
    final curLon = pStart.longitude + (pEnd.longitude - pStart.longitude) * segFrac;
    final currentPos = LatLng(curLat, curLon);

    final dLon = pEnd.longitude - pStart.longitude;
    final dLat = pEnd.latitude - pStart.latitude;
    final bearingRad = math.atan2(dLon, dLat);

    final List<LatLng> traversed = [];
    for (int i = 0; i <= segIdx; i++) {
      traversed.add(waypoints[i]);
    }
    traversed.add(currentPos);

    final List<LatLng> remaining = [currentPos];
    for (int i = segIdx + 1; i < waypoints.length; i++) {
      remaining.add(waypoints[i]);
    }

    return {
      'currentPos': currentPos,
      'bearingRad': bearingRad,
      'traversed': traversed,
      'remaining': remaining,
      'segmentIndex': segIdx,
    };
  }

  void _startInAppNavigation() {
    setState(() {
      _isNavigating = true;
      _isNavPaused = false;
      _navProgressFraction = 0.0;
      _isInMidRouteDangerZone = false;
      _hasArrivedAtDestination = false;
    });

    if (_routeComparison != null) {
      _checkRouteLowestSafetyZone(_routeComparison!);
    }

    final activeRoute = _useSafestRoute
        ? _routeComparison?.safestRoute
        : _routeComparison?.fastestRoute;

    final srcCoord = _getSourceCoordinates();
    final sourceLat = srcCoord.latitude;
    final sourceLon = srcCoord.longitude;

    final destLoc = _routeComparison?.destination;
    final targetLat = destLoc?.lat ?? 21.155;
    final targetLon = destLoc?.lon ?? 79.082;

    final srcScore = _routeComparison?.source.safetyScore ?? 75.0;
    final destScore = _routeComparison?.destination.safetyScore ?? 75.0;

    _currentTraversingAreaName = _routeComparison?.source.place ?? 'Origin Area';
    _currentTraversingAreaScore = srcScore;

    final waypoints = _generateGoogleMapsWaypoints(sourceLat, sourceLon, targetLat, targetLon);

    // Trigger 2-second Red Alert ONLY if Source or Destination has a 30-50 score
    if (srcScore >= 30.0 && srcScore <= 50.0) {
      _trigger2sRedBlinkingAlert(
        "🚨 RISKY SOURCE AREA (30-50 SCORE)!",
        "Starting in ${_routeComparison?.source.place} (${srcScore.toStringAsFixed(1)}/100)",
      );
    } else if (destScore >= 30.0 && destScore <= 50.0) {
      _trigger2sRedBlinkingAlert(
        "🚨 RISKY DESTINATION (30-50 SCORE)!",
        "Destination ${_routeComparison?.destination.place} (${destScore.toStringAsFixed(1)}/100)",
      );
    }

    // Center map on starting position
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        _navMapController.move(LatLng(sourceLat, sourceLon), 16.8);
      } catch (_) {}
    });

    _navTimer?.cancel();
    // Ultra-smooth 50ms fluid Google Maps GPS simulation loop
    _navTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted || _isNavPaused) return;
      setState(() {
        _navProgressFraction += 0.0018;

        final navState = _computeNavState(waypoints, _navProgressFraction);
        final LatLng curPos = navState['currentPos'] as LatLng;

        // Smoothly follow vehicle/arrow with map camera
        try {
          _navMapController.move(curPos, 16.8);
        } catch (_) {}

        // Dynamic Area-wise Traversing Score Tracker:
        if (_navProgressFraction < 0.30) {
          _currentTraversingAreaName = _routeComparison?.source.place ?? 'Source Zone';
          _currentTraversingAreaScore = srcScore;
        } else if (_navProgressFraction >= 0.30 && _navProgressFraction <= 0.70) {
          _currentTraversingAreaName = activeRoute?.midRouteDangerName ?? 'Mid-Route Corridor';
          _currentTraversingAreaScore = activeRoute?.midRouteSafetyScore ?? 46.5;

          // Trigger 2-second Red Alert ONLY if traversing intermediate area has 30-50 score
          if (_currentTraversingAreaScore >= 30.0 && _currentTraversingAreaScore <= 50.0) {
            if (!_isInMidRouteDangerZone) {
              _isInMidRouteDangerZone = true;
              _trigger2sRedBlinkingAlert(
                "🚨 RISKY MID-ROUTE AREA (30-50 SCORE)!",
                "Entering $_currentTraversingAreaName (${_currentTraversingAreaScore.toStringAsFixed(1)}/100)",
              );
            }
          }
        } else {
          _currentTraversingAreaName = _routeComparison?.destination.place ?? 'Destination Zone';
          _currentTraversingAreaScore = destScore;
          if (_isInMidRouteDangerZone) {
            _isInMidRouteDangerZone = false;
          }
        }

        if (_navProgressFraction >= 1.0) {
          _navProgressFraction = 1.0;
          _isInMidRouteDangerZone = false;
          _hasArrivedAtDestination = true;
          _navTimer?.cancel();
          Fluttertoast.showToast(
            msg: "🎉 You've Arrived at Your Destination!",
            toastLength: Toast.LENGTH_LONG,
          );
        }
      });
    });

    Fluttertoast.showToast(msg: "🟢 Live In-App Safe Navigation Engine Active");
  }

  void _toggleNavPause() {
    setState(() {
      _isNavPaused = !_isNavPaused;
    });
    if (_isNavPaused) {
      Fluttertoast.showToast(msg: "⏸️ Navigation Paused - Performing Safety Check");
      _showPauseSafetyCheckDialog();
    } else {
      _pauseEscalationTimer?.cancel();
      _isPauseSafetyActive = false;
      Fluttertoast.showToast(msg: "▶️ Resuming Safe Navigation");
    }
  }

  void _showPauseSafetyCheckDialog() {
    if (!mounted || _isPauseSafetyActive) return;
    _isPauseSafetyActive = true;
    _pauseEscalationAttempt = 1;
    _pauseSecondsRemaining = 5;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            _pauseEscalationTimer?.cancel();
            _pauseEscalationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
              if (_pauseSecondsRemaining > 1) {
                if (mounted) setDialogState(() => _pauseSecondsRemaining--);
              } else {
                timer.cancel();
                if (_pauseEscalationAttempt < 2) {
                  if (mounted) {
                    setDialogState(() {
                      _pauseEscalationAttempt++;
                      _pauseSecondsRemaining = 5;
                    });
                  }
                } else {
                  Navigator.of(dialogCtx, rootNavigator: true).pop();
                  _isPauseSafetyActive = false;
                  _fireQuickNavigationSOS('Auto Quick SOS: Navigation Paused & No response to safety check.');
                }
              }
            });

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF991B1B),
                      Color(0xFF7F1D1D),
                      Color(0xFF450A0A),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: Colors.redAccent, width: 2.5),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.redAccent,
                      blurRadius: 30,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white54),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.pause_circle_filled_rounded, color: Colors.yellowAccent, size: 20),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '⏸️ SAFE NAVIGATION PAUSED',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                letterSpacing: 0.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 90,
                          height: 90,
                          child: CircularProgressIndicator(
                            value: _pauseSecondsRemaining / 5.0,
                            strokeWidth: 6,
                            backgroundColor: Colors.white24,
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.yellowAccent),
                          ),
                        ),
                        Container(
                          width: 70,
                          height: 70,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '$_pauseSecondsRemaining',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Text(
                      'ARE YOU SAFE?',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 6),

                    Text(
                      'Navigation paused along $_currentTraversingAreaName',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        color: Colors.yellowAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),

                    Text(
                      'Attempt $_pauseEscalationAttempt of 2 (Auto Quick SOS in ${_pauseSecondsRemaining + (2 - _pauseEscalationAttempt) * 5}s)',
                      style: GoogleFonts.outfit(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 24),

                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              _pauseEscalationTimer?.cancel();
                              Navigator.of(dialogCtx, rootNavigator: true).pop();
                              _isPauseSafetyActive = false;
                              Fluttertoast.showToast(
                                msg: "🟢 Safe Navigation Paused Safely.",
                                backgroundColor: const Color(0xFF10B981),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
                            label: Text(
                              'YES, Safe',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              _pauseEscalationTimer?.cancel();
                              Navigator.of(dialogCtx, rootNavigator: true).pop();
                              _isPauseSafetyActive = false;
                              _fireQuickNavigationSOS('User pressed NO (Need Help) while Navigation was Paused!');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFDC2626),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            icon: const Icon(Icons.sos_rounded, color: Colors.white),
                            label: Text(
                              'NO, Help!',
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
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _fireQuickNavigationSOS(String reason) async {
    const phone = '9109750185';
    final targetLat = lat ?? 21.1458;
    final targetLon = long ?? 79.0882;
    final mapLink = "https://www.google.com/maps/search/?api=1&query=$targetLat,$targetLon";
    final message = '🚨 QUICK EMERGENCY SOS ALERT! $reason Live GPS Location: $mapLink';

    // 1. Send Direct Cellular Background SMS
    final sentDirect = await WomenSafetyMeshSosService.sendDirectSms(phone, message);
    if (sentDirect) {
      Fluttertoast.showToast(
        msg: "✅ Quick SOS Direct SMS sent to $phone!",
        toastLength: Toast.LENGTH_SHORT,
        backgroundColor: const Color(0xFF10B981),
        textColor: Colors.white,
      );
    }

    // 2. Broadcast BLE Mesh Beacon
    try {
      await WomenSafetyMeshSosService.triggerEmergencySos(
        latitude: targetLat,
        longitude: targetLon,
        batteryLevel: 95,
        message: message,
      );
    } catch (_) {}

    // 3. Launch SOS Screen
    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AlertMessageScreen(
            initialLat: targetLat,
            initialLon: targetLon,
            initialRecentCallVector: phone,
          ),
        ),
      );
    }
  }

  void _endInAppNavigation() {
    _navTimer?.cancel();
    _pauseEscalationTimer?.cancel();
    _isPauseSafetyActive = false;
    setState(() {
      _isNavigating = false;
      _isNavPaused = false;
      _navProgressFraction = 0.0;
    });
    Fluttertoast.showToast(msg: "In-App Navigation Ended");
  }

  Future<void> _sendSMS(String number, String message) async {
    final sentDirect = await WomenSafetyMeshSosService.sendDirectSms(number, message);
    if (sentDirect) {
      Fluttertoast.showToast(
        msg: "✅ Auto SMS directly sent to $number!",
        toastLength: Toast.LENGTH_SHORT,
        backgroundColor: const Color(0xFF10B981),
        textColor: Colors.white,
      );
    } else {
      final Uri url = Uri.parse("sms:$number?body=${Uri.encodeComponent(message)}");
      try {
        await launchUrl(url);
      } catch (_) {}
    }
  }

  Color _getScoreColor(double score) {
    if (score >= 8.0 || score >= 80) return const Color(0xFF10B981);
    if (score >= 6.0 || score >= 60) return const Color(0xFF3B82F6);
    if (score >= 4.5 || score >= 45) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  void _swapSourceAndDestination() {
    setState(() {
      final temp = _sourceController.text;
      _sourceController.text = _destController.text;
      _destController.text = temp.isEmpty ? "Sitabuldi" : temp;
      _sourceLocalityName = _sourceController.text;
      _destLocalityName = _destController.text;
      _updateRouteComparison();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isNavigating) {
      return _buildInAppNavigationHUD();
    }

    final routeDetail = _useSafestRoute
        ? _routeComparison?.safestRoute
        : _routeComparison?.fastestRoute;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Header
                  Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Route Safety Finder',
                          style: GoogleFonts.outfit(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textDark,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'AI Dynamic Lighting & Crime Engine',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            color: AppTheme.primaryPurple,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => const NagpurSafetyScreen(),
                        ),
                      );
                    },
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: AppTheme.glassCardDecoration(borderRadius: 14),
                      child: const Icon(
                        Icons.analytics_rounded,
                        color: AppTheme.primaryPurple,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 10-Second Auto-Dismissing Route Danger Zone Alert Card
              if (_show10sRouteBanner) _build10sRouteBannerCard(),

              // Dynamic Time of Day Status Pill
              if (_routeComparison != null) _buildTimeOfDayBanner(_routeComparison!),
              const SizedBox(height: 10),

              // Travel Mode Selector (Driving vs Walking)
              _buildTravelModeSelector(),
              const SizedBox(height: 14),

              // 1. Source & Destination Card with Custom Dropdown Selectors
              _buildSourceDestinationCard(),
              const SizedBox(height: 16),

              // 2. Route Type Choice Selector (Safest vs Fastest)
              _buildRouteSelectorTabs(),
              const SizedBox(height: 16),

              // 3. Interactive Map View with Route Polyline
              _buildMapView(routeDetail),
              const SizedBox(height: 16),

              // 4. Region Safety Conditions Breakdown Grid (Matching Photo 1)
              if (routeDetail != null) _buildSafetyConditionCards(routeDetail),
              const SizedBox(height: 16),

              // 5. Action Buttons
              _buildActionButtons(),
            ],
          ),
        ),
      ),

      // 10-Second Blinking Red Screen Flash Overlay Effect
      if (_isBlinkingRedFlashActive && _redBlinkAnimation != null)
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _redBlinkAnimation!,
              builder: (context, child) {
                return Container(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.38 * _redBlinkAnimation!.value),
                );
              },
            ),
          ),
        ),

      // 10-Second High-Risk Red Alert Pop-Up Banner
      if (_isBlinkingRedFlashActive)
        Positioned(
          top: 50,
          left: 16,
          right: 16,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF991B1B),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFFCA5A5), width: 2),
                boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 20, offset: Offset(0, 6))],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: Colors.white24,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _redAlertTitle,
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _redAlertSubtitle,
                          style: GoogleFonts.outfit(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '🔴 Blinking 10s Flash Active • ${_soundService.soundDisplayName}',
                          style: GoogleFonts.outfit(
                            color: const Color(0xFFFECACA),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                    onPressed: () {
                      _redBlink10sTimer?.cancel();
                      _redBlinkController?.stop();
                      setState(() => _isBlinkingRedFlashActive = false);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
    ],
  ),
);
  }

  // --- UI COMPONENTS ---

  Widget _build10sRouteBannerCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.6)),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        '⚠️ Route Alert (10s Auto-Dismiss)',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFFEF4444),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      'Auto-closing',
                      style: GoogleFonts.outfit(
                        color: Colors.white54,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Lowest Safety Zone: $_bannerLocalityName (${_bannerSafetyScore.toStringAsFixed(1)}/100)',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  'Exercise caution in this segment. ${_soundService.soundDisplayName}',
                  style: GoogleFonts.outfit(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
            onPressed: () {
              _route10sBannerTimer?.cancel();
              setState(() => _show10sRouteBanner = false);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTimeOfDayBanner(RouteSafetyComparison comparison) {
    final label = comparison.timeOfDayLabel;
    final isNight = label.contains("Night");
    final color = isNight ? const Color(0xFF6366F1) : const Color(0xFFF59E0B);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(isNight ? Icons.nightlight_round : Icons.wb_sunny_rounded, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Dynamic Safety Mode: $label',
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTravelModeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildModeChip(
              mode: TravelMode.car,
              icon: Icons.directions_car_rounded,
              label: '🚗 Driving (Car)',
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _buildModeChip(
              mode: TravelMode.walk,
              icon: Icons.directions_walk_rounded,
              label: '🚶 Walking (Pedestrian)',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeChip({
    required TravelMode mode,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _selectedTravelMode == mode;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTravelMode = mode;
          _updateRouteComparison();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryPurple : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: isSelected ? Colors.white : AppTheme.textMuted),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : AppTheme.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceDestinationCard() {
    final popularLocations = [
      gpsSourceLabel,
      'Sitabuldi',
      'Civil Lines',
      'VNIT Campus',
      'Ramdaspeth',
      'Mihan IT Hub',
      'Khamla',
      'Manewada',
      'Airport Road',
      'Sadar',
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Route Visual Indicator
              Column(
                children: [
                  const Icon(Icons.circle, color: Color(0xFF3B82F6), size: 14),
                  Container(
                    width: 2,
                    height: 48,
                    color: const Color(0xFFCBD5E1),
                  ),
                  const Icon(Icons.location_on_rounded, color: AppTheme.accentRose, size: 20),
                ],
              ),
              const SizedBox(width: 14),

              // Inputs Column
              Expanded(
                child: Column(
                  children: [
                    // SOURCE FREEFORM TEXT INPUT
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.my_location_rounded, size: 18, color: Color(0xFF3B82F6)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _sourceController,
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppTheme.textDark,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Type starting location...',
                                hintStyle: GoogleFonts.outfit(color: AppTheme.textMuted, fontSize: 13),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              onChanged: (val) {
                                setState(() {
                                  _sourceLocalityName = val.trim().isEmpty ? gpsSourceLabel : val.trim();
                                });
                                _updateRouteComparison();
                              },
                            ),
                          ),
                          if (_sourceController.text.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                _sourceController.clear();
                                setState(() => _sourceLocalityName = gpsSourceLabel);
                                _updateRouteComparison();
                              },
                              child: const Icon(Icons.close_rounded, size: 16, color: Colors.grey),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // DESTINATION FREEFORM TEXT INPUT
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on_rounded, size: 18, color: AppTheme.accentRose),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _destController,
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppTheme.textDark,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Type destination location...',
                                hintStyle: GoogleFonts.outfit(color: AppTheme.textMuted, fontSize: 13),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              onChanged: (val) {
                                setState(() {
                                  _destLocalityName = val.trim().isEmpty ? 'Sitabuldi' : val.trim();
                                });
                                _updateRouteComparison();
                              },
                            ),
                          ),
                          if (_destController.text.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                _destController.clear();
                                setState(() => _destLocalityName = 'Sitabuldi');
                                _updateRouteComparison();
                              },
                              child: const Icon(Icons.close_rounded, size: 16, color: Colors.grey),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Swap Button
              GestureDetector(
                onTap: _swapSourceAndDestination,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryPurple.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.swap_vert_rounded,
                    color: AppTheme.primaryPurple,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Autocomplete Suggestions Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: popularLocations.map((loc) {
                final locObj = _nagpurService.getOrCreateLocality(loc, DateTime.now().hour);
                final chipColor = _getScoreColor(locObj.safetyScore);
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ActionChip(
                    avatar: Icon(Icons.near_me_rounded, size: 12, color: chipColor),
                    label: Text(loc, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold)),
                    backgroundColor: const Color(0xFFF8FAFC),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onPressed: () {
                      setState(() {
                        _destController.text = loc;
                        _destLocalityName = loc;
                      });
                      _updateRouteComparison();
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteSelectorTabs() {
    final safest = _routeComparison?.safestRoute;
    final fastest = _routeComparison?.fastestRoute;

    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _useSafestRoute = true),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
              decoration: BoxDecoration(
                gradient: _useSafestRoute ? AppTheme.purpleHeroGradient : null,
                color: _useSafestRoute ? null : Colors.white.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _useSafestRoute ? Colors.transparent : const Color(0xFFCBD5E1),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.shield_rounded,
                        size: 16,
                        color: _useSafestRoute ? Colors.white : AppTheme.primaryPurple,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Optimized Safest',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: _useSafestRoute ? Colors.white : AppTheme.textDark,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_formatDuration(safest?.durationMinutes ?? 42)} | 🛡️ ${safest?.safetyIndex ?? 8.8}/10',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _useSafestRoute ? Colors.white.withValues(alpha: 0.9) : AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _useSafestRoute = false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
              decoration: BoxDecoration(
                gradient: !_useSafestRoute ? AppTheme.purpleHeroGradient : null,
                color: !_useSafestRoute ? null : Colors.white.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: !_useSafestRoute ? Colors.transparent : const Color(0xFFCBD5E1),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.bolt_rounded,
                        size: 16,
                        color: !_useSafestRoute ? Colors.white : const Color(0xFF3B82F6),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Fastest Direct',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: !_useSafestRoute ? Colors.white : AppTheme.textDark,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_formatDuration(fastest?.durationMinutes ?? 35)} | 🛡️ ${fastest?.safetyIndex ?? 6.4}/10',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: !_useSafestRoute ? Colors.white.withValues(alpha: 0.9) : AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMapView(RouteSafetyDetail? detail) {
    // Dynamic Exact Coordinates for Source (Custom Locality or Live GPS)
    final srcCoord = _getSourceCoordinates();
    final sourceLat = srcCoord.latitude;
    final sourceLon = srcCoord.longitude;

    final destCoord = _getDestinationCoordinates();
    final targetLat = destCoord.latitude;
    final targetLon = destCoord.longitude;

    final midLat = (sourceLat + targetLat) / 2;
    final midLon = (sourceLon + targetLon) / 2;

    final polylinePoints = _liveRouteWaypoints.length >= 2
        ? _liveRouteWaypoints
        : (_useSafestRoute
            ? [
                LatLng(sourceLat, sourceLon),
                LatLng(midLat + 0.012, midLon - 0.008),
                LatLng(midLat - 0.004, midLon + 0.012),
                LatLng(targetLat, targetLon),
              ]
            : [
                LatLng(sourceLat, sourceLon),
                LatLng(midLat, midLon),
                LatLng(targetLat, targetLon),
              ]);

    return Container(
      height: 320,
      decoration: AppTheme.glassCardDecoration(borderRadius: 28),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: LatLng(midLat, midLon),
              initialZoom: 12.5,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                userAgentPackageName: 'com.bsafe.app',
              ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: polylinePoints,
                    strokeWidth: 5.5,
                    color: _useSafestRoute ? AppTheme.primaryPurple : const Color(0xFF3B82F6),
                  ),
                ],
              ),
              SafetyMarkerLayer(
                locations: _safetyLocations,
                onMarkerTapped: (loc) {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (ctx) => LocationDetailSheet(locationId: loc.id),
                  );
                },
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(sourceLat, sourceLon),
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFF3B82F6),
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6)],
                      ),
                      child: const Icon(Icons.my_location_rounded, color: Colors.white, size: 22),
                    ),
                  ),
                  Marker(
                    point: LatLng(targetLat, targetLon),
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: AppTheme.accentRose,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6)],
                      ),
                      child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 24),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Floating Route Badge
          Positioned(
            top: 14,
            left: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
              ),
              child: Row(
                children: [
                  const Icon(Icons.directions_car_rounded, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    '${detail?.durationMinutes ?? 45} min (${detail?.distanceKm ?? 12.4} km)',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyConditionCards(RouteSafetyDetail detail) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            "Route Safety & Dynamic Time Conditions",
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textDark,
            ),
          ),
        ),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 1.6,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: [
            _buildConditionTile(
              icon: Icons.lightbulb_rounded,
              title: 'Street Lighting',
              value: '${detail.lightingScorePercent}% Lit',
              subtitle: detail.lightingScorePercent >= 90 ? 'LED Arterial Coverage' : 'Reduced Night Lighting',
              color: detail.lightingScorePercent >= 80 ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
            ),
            _buildConditionTile(
              icon: Icons.people_rounded,
              title: 'Crowd Density',
              value: detail.crowdDensity.split(' / ').first,
              subtitle: detail.crowdDensity.split(' / ').last,
              color: const Color(0xFF3B82F6),
            ),
            _buildConditionTile(
              icon: Icons.shield_rounded,
              title: 'Historical Crime',
              value: '${detail.crimeRateIndex} / sq.km',
              subtitle: detail.crimeRateIndex < 0.3 ? 'Low Incident Risk' : 'Elevated Night Risk',
              color: detail.crimeRateIndex < 0.3 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
            ),
            _buildConditionTile(
              icon: Icons.auto_graph_rounded,
              title: 'AI Dynamic Safety',
              value: '${detail.safetyIndex} / 10',
              subtitle: detail.riskTier,
              color: AppTheme.primaryPurple,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildConditionTile({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textDark,
            ),
          ),
          Text(
            subtitle,
            style: GoogleFonts.outfit(
              fontSize: 11,
              color: AppTheme.textMuted,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _startInAppNavigation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                icon: Icon(
                  _selectedTravelMode == TravelMode.walk
                      ? Icons.directions_walk_rounded
                      : Icons.navigation_rounded,
                  size: 20,
                ),
                label: Text(
                  _selectedTravelMode == TravelMode.walk
                      ? "Start Safe Walk"
                      : "Start Safe Navigation",
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  final dest = _destLocalityName;
                  mapLink = 'https://www.google.com/maps/dir/?api=1&origin=${lat ?? 21.1458},${long ?? 79.0882}&destination=$dest';
                  _sendSMS("9109750185", "RakshaSetu Live Navigation Alert: Heading from $_sourceLocalityName to $dest. Live link: $mapLink");
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentRose,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                icon: const Icon(Icons.share_location_rounded, size: 20),
                label: Text(
                  "Share Live Route",
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatDuration(int minutes) {
    if (minutes >= 60) {
      final hrs = minutes ~/ 60;
      final mins = minutes % 60;
      return mins > 0 ? '$hrs hrs $mins mins' : '$hrs hrs';
    }
    return '$minutes min';
  }

  // --- IN-APP TURN-BY-TURN NAVIGATION MODE HUD VIEW ---

  Widget _buildInAppNavigationHUD() {
    final routeDetail = _useSafestRoute
        ? _routeComparison?.safestRoute
        : _routeComparison?.fastestRoute;

    final srcCoord = _getSourceCoordinates();
    final sourceLat = srcCoord.latitude;
    final sourceLon = srcCoord.longitude;

    final destLoc = _routeComparison?.destination;
    final targetLat = destLoc?.lat ?? 21.155;
    final targetLon = destLoc?.lon ?? 79.082;

    final waypoints = _generateGoogleMapsWaypoints(sourceLat, sourceLon, targetLat, targetLon);
    final navState = _computeNavState(waypoints, _navProgressFraction);

    final LatLng currentVehPos = navState['currentPos'] as LatLng;
    final double bearingRad = navState['bearingRad'] as double;
    final List<LatLng> traversedPoints = navState['traversed'] as List<LatLng>;
    final List<LatLng> remainingPoints = navState['remaining'] as List<LatLng>;
    final int segIdx = navState['segmentIndex'] as int;

    // Realistic Google Maps Maneuver Turn Cards
    final List<Map<String, dynamic>> turnSteps = [
      {
        'dist': 'In 350 m',
        'text': 'Head straight along Lit Arterial Corridor',
        'icon': Icons.straight_rounded,
      },
      {
        'dist': 'In 180 m',
        'text': 'Turn right onto Wardha Main Corridor',
        'icon': Icons.turn_right_rounded,
      },
      {
        'dist': 'In 1.6 km',
        'text': 'Continue straight on High Safety Highway (96% Lit)',
        'icon': Icons.straight_rounded,
      },
      {
        'dist': 'In 450 m',
        'text': 'Turn slightly left towards Destination',
        'icon': Icons.turn_slight_left_rounded,
      },
      {
        'dist': 'In 60 m',
        'text': 'Arriving safely at Destination',
        'icon': Icons.flag_rounded,
      },
    ];

    final currentManeuver = turnSteps[segIdx.clamp(0, turnSteps.length - 1)];

    final remainingKm = (detailKm(routeDetail) * (1.0 - _navProgressFraction)).clamp(0.0, 99.0).toStringAsFixed(1);
    final remainingMin = ((detailMin(routeDetail)) * (1.0 - _navProgressFraction)).round().clamp(0, 999);

    return Scaffold(
      body: Stack(
        children: [
          // 1. Fullscreen Google Maps Styled Navigation Map with Live Camera Tracking
          FlutterMap(
            mapController: _navMapController,
            options: MapOptions(
              initialCenter: currentVehPos,
              initialZoom: 16.8,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                userAgentPackageName: 'com.bsafe.app',
              ),
              PolylineLayer(
                polylines: [
                  // 1. Traversed Route Polyline (soft grayed out behind vehicle, exactly like Google Maps)
                  if (traversedPoints.length >= 2)
                    Polyline(
                      points: traversedPoints,
                      strokeWidth: 5.5,
                      color: const Color(0xFF94A3B8).withValues(alpha: 0.5),
                    ),

                  // 2. Active Remaining Route Outline (Deep Google Navigation Blue)
                  if (remainingPoints.length >= 2)
                    Polyline(
                      points: remainingPoints,
                      strokeWidth: 8.5,
                      color: const Color(0xFF1E40AF),
                    ),

                  // 3. Active Remaining Route Main Body
                  if (remainingPoints.length >= 2)
                    Polyline(
                      points: remainingPoints,
                      strokeWidth: 6.5,
                      color: const Color(0xFF2563EB),
                    ),

                  // 4. Active Remaining Route Inner Cyan Core Line
                  if (remainingPoints.length >= 2)
                    Polyline(
                      points: remainingPoints,
                      strokeWidth: 2.2,
                      color: const Color(0xFF93C5FD),
                    ),
                ],
              ),
              MarkerLayer(
                markers: [
                  // Source Origin Dot
                  Marker(
                    point: LatLng(sourceLat, sourceLon),
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                      ),
                    ),
                  ),

                  // Destination Target Marker
                  Marker(
                    point: LatLng(targetLat, targetLon),
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    child: const Icon(Icons.location_on_rounded, color: Color(0xFFEF4444), size: 44),
                  ),

                  // Live Google Maps Navigation Arrow & Directional Light Cone Puck
                  Marker(
                    point: currentVehPos,
                    width: 82,
                    height: 82,
                    alignment: Alignment.center,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // A. Google Maps GPS Forward Directional Flashlight Cone
                        Transform.rotate(
                          angle: bearingRad,
                          alignment: Alignment.center,
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                center: Alignment.topCenter,
                                radius: 0.85,
                                colors: [
                                  const Color(0xFF3B82F6).withValues(alpha: 0.55),
                                  const Color(0xFF3B82F6).withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // B. Outer Pulsing Accuracy Halo Ring
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF3B82F6).withValues(alpha: 0.22),
                            border: Border.all(
                              color: const Color(0xFF3B82F6).withValues(alpha: 0.6),
                              width: 1.5,
                            ),
                          ),
                        ),

                        // C. 3D Google Navigation Chevron Puck
                        Transform.rotate(
                          angle: bearingRad,
                          alignment: Alignment.center,
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2.8),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black45,
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.navigation_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // 1b. Floating Camera Recenter Button
          Positioned(
            top: 135,
            right: 16,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  _navMapController.move(currentVehPos, 16.8);
                  Fluttertoast.showToast(msg: "🎯 Camera centered on navigation arrow");
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white24),
                    boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 10)],
                  ),
                  child: const Icon(Icons.my_location_rounded, color: Colors.white, size: 22),
                ),
              ),
            ),
          ),

          // 2. Google Maps Navigation Top Direction Card
          Positioned(
            top: 50,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 16, offset: Offset(0, 6))],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      currentManeuver['icon'] as IconData,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          currentManeuver['dist'] as String,
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF60A5FA),
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          currentManeuver['text'] as String,
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '📍 Area: ${_currentTraversingAreaName.isNotEmpty ? _currentTraversingAreaName : "Nagpur Corridor"} (${_currentTraversingAreaScore.toStringAsFixed(1)}/100) • Safety: 🛡️ ${routeDetail?.safetyIndex ?? 9.1}/10',
                          style: GoogleFonts.outfit(
                            color: _currentTraversingAreaScore <= 50.0 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2b. 10-Second Blinking Red Screen Flash Overlay Effect
          if (_isBlinkingRedFlashActive && _redBlinkAnimation != null)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _redBlinkAnimation!,
                  builder: (context, child) {
                    return Container(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.38 * _redBlinkAnimation!.value),
                    );
                  },
                ),
              ),
            ),

          // 2c. 10-Second High-Risk Red Alert Pop-Up Banner
          if (_isBlinkingRedFlashActive)
            Positioned(
              top: 50,
              left: 16,
              right: 16,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF991B1B),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFFCA5A5), width: 2),
                    boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 20, offset: Offset(0, 6))],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          color: Colors.white24,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _redAlertTitle,
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _redAlertSubtitle,
                              style: GoogleFonts.outfit(
                                color: Colors.white70,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '🔴 Blinking 10s Flash Active • ${_soundService.soundDisplayName}',
                              style: GoogleFonts.outfit(
                                color: const Color(0xFFFECACA),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                        onPressed: () {
                          _redBlink10sTimer?.cancel();
                          _redBlinkController?.stop();
                          setState(() => _isBlinkingRedFlashActive = false);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 2b. Mid-Route Danger Alert Banner (Overlay when passing through risky stretch)
          if (_isInMidRouteDangerZone)
            Positioned(
              top: 145,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, 4))],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '⚠️ DANGER AHEAD: Passing Unsafe Stretch',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            '${routeDetail?.midRouteDangerName ?? "Itwari Unlit Stretch"} (${routeDetail?.midRouteSafetyScore ?? 46.5}/100)',
                            style: GoogleFonts.outfit(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 3. Bottom Navigation HUD Panel with Play/Pause Control
          Positioned(
            bottom: 30,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, -4))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatDuration(remainingMin),
                            style: GoogleFonts.outfit(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primaryPurple,
                            ),
                          ),
                          Text(
                            '$remainingKm km remaining',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              color: AppTheme.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            onPressed: _toggleNavPause,
                            icon: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _isNavPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                                color: AppTheme.primaryPurple,
                                size: 24,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _selectedTravelMode == TravelMode.walk ? Icons.directions_walk_rounded : Icons.speed_rounded,
                                  size: 16,
                                  color: const Color(0xFF10B981),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _isNavPaused
                                      ? 'Paused'
                                      : (_selectedTravelMode == TravelMode.walk ? '4.0 km/h (Walk)' : '40 km/h (Car)'),
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF10B981),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Fluttertoast.showToast(msg: "Voice guidance muted");
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          icon: const Icon(Icons.volume_up_rounded, size: 18),
                          label: const Text('Voice ON'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _endInAppNavigation,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentRose,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                          label: const Text('End Navigation', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 3b. Floating Emergency SOS Button during Live Navigation
          Positioned(
            bottom: 165,
            right: 20,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (ctx) => AlertMessageScreen(
                        initialLat: currentVehPos.latitude,
                        initialLon: currentVehPos.longitude,
                        initialRecentCallVector: '9109750185',
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black45,
                        blurRadius: 14,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.sos_rounded, color: Colors.white, size: 26),
                      const SizedBox(width: 6),
                      Text(
                        'SOS (9109750185)',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 4. Google Maps Style Destination Arrival Celebration Sheet
          if (_hasArrivedAtDestination)
            _buildGoogleMapsArrivalSheet(routeDetail),
        ],
      ),
    );
  }

  Widget _buildGoogleMapsArrivalSheet(RouteSafetyDetail? routeDetail) {
    final destName = _routeComparison?.destination.place ?? _destLocalityName;
    final distStr = "${detailKm(routeDetail)} km";
    final totalMins = detailMin(routeDetail);
    final timeStr = totalMins >= 60
        ? "${totalMins ~/ 60}h ${totalMins % 60}m"
        : "$totalMins mins";
    final safetyStr = "${routeDetail?.safetyIndex ?? 8.8}/10";

    return Positioned(
      bottom: 24,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutBack,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFF10B981), width: 2.5),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF10B981),
                  size: 48,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "You've Arrived!",
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                destName,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 18),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildArrivalStatItem("⏱️ Time", timeStr),
                  Container(width: 1, height: 32, color: Colors.white24),
                  _buildArrivalStatItem("📏 Distance", distStr),
                  Container(width: 1, height: 32, color: Colors.white24),
                  _buildArrivalStatItem("🛡️ Safety", safetyStr),
                ],
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isNavigating = false;
                      _hasArrivedAtDestination = false;
                      _navProgressFraction = 0.0;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                  ),
                  child: Text(
                    "Done",
                    style: GoogleFonts.outfit(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArrivalStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            color: Colors.white60,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 16,
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  double detailKm(RouteSafetyDetail? detail) => detail?.distanceKm ?? 12.4;
  int detailMin(RouteSafetyDetail? detail) => detail?.durationMinutes ?? 42;
}
