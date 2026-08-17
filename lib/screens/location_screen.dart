import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:safe/models/safety_audit_models.dart';
import 'package:safe/screens/nagpur_safety_screen.dart';
import 'package:safe/services/nagpur_safety_service.dart';
import 'package:safe/services/safety_audit_service.dart';
import 'package:safe/theme/app_theme.dart';
import 'package:safe/widgets/safety/add_audit_dialog.dart';
import 'package:safe/widgets/safety/location_detail_sheet.dart';
import 'package:safe/widgets/safety/safety_marker_layer.dart';
import 'package:url_launcher/url_launcher.dart';

class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  double? lat;
  double? long;
  String locationMessage = "Fetching GPS location...";
  String address = "Fetching reverse geocoded address...";
  String mapLink = "";
  StreamSubscription<Position>? _positionSubscription;

  final NagpurSafetyService _nagpurService = NagpurSafetyService();

  // Source & Destination Route State
  static const String gpsSourceLabel = "Your current GPS location";
  String _sourceLocalityName = gpsSourceLabel;
  String _destLocalityName = "Sitabuldi";
  bool _useSafestRoute = true;
  RouteSafetyComparison? _routeComparison;

  // In-App Turn-By-Turn Navigation Engine State
  bool _isNavigating = false;
  bool _isNavPaused = false;
  int _navStepIndex = 0;
  Timer? _navTimer;
  double _navProgressFraction = 0.0;

  final List<String> _navInstructions = const [
    "⬆️ Head north on Main Arterial Road (95% LED Lit)",
    "↗️ In 300m, turn right onto Wardha Highway (High Footfall Zone)",
    "⬆️ Continue straight for 1.8 km (Low Crime Zone)",
    "🏁 Arriving safely at your Destination",
  ];

  List<SafetyLocation> _safetyLocations = [];

  @override
  void initState() {
    super.initState();
    _initNagpurSafety();
    _fetchSafetyLocations();
    _getCurrentLocation();
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
      setState(() {
        _updateRouteComparison();
      });
    }
  }

  TravelMode _selectedTravelMode = TravelMode.car;

  void _updateRouteComparison() async {
    final comparison = await _nagpurService.calculateRouteSafetyAsync(
      sourceName: _sourceLocalityName,
      destName: _destLocalityName,
      userLat: lat,
      userLon: long,
      travelMode: _selectedTravelMode,
    );
    if (mounted) {
      setState(() {
        _routeComparison = comparison;
      });
    }
  }

  LatLng _getSourceCoordinates() {
    if (_sourceLocalityName != gpsSourceLabel) {
      final match = _nagpurService.searchLocalities(_sourceLocalityName).firstOrNull;
      if (match != null) {
        return LatLng(match.lat, match.lon);
      }
    }
    return LatLng(lat ?? 21.1458, long ?? 79.0882);
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _navTimer?.cancel();
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

      Position position = await Geolocator.getCurrentPosition();
      _updateLocation(position);
      _listenToLocationUpdates();
    } catch (e) {
      setState(() {
        locationMessage = e.toString();
        lat = 21.1458;
        long = 79.0882;
        address = "Nagpur, Maharashtra, India";
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
    _positionSubscription = Geolocator.getPositionStream(
            locationSettings: const LocationSettings(distanceFilter: 100))
        .listen(_updateLocation);
  }

  Future<void> _getAddress(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks =
          await placemarkFromCoordinates(latitude, longitude);
      setState(() {
        Placemark place = placemarks.reversed.last;
        address = "${place.name}, ${place.subLocality}, ${place.locality}";
      });
    } catch (e) {
      setState(() {
        address = "Nagpur Area, India";
      });
    }
  }

  void _startInAppNavigation() {
    setState(() {
      _isNavigating = true;
      _isNavPaused = false;
      _navStepIndex = 0;
      _navProgressFraction = 0.0;
    });

    _navTimer?.cancel();
    // Steady real-time motion simulation (0.02 step per 3s interval)
    _navTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted || _isNavPaused) return;
      setState(() {
        _navProgressFraction += 0.02;
        if (_navProgressFraction >= 0.3 && _navStepIndex < 1) {
          _navStepIndex = 1;
        } else if (_navProgressFraction >= 0.6 && _navStepIndex < 2) {
          _navStepIndex = 2;
        } else if (_navProgressFraction >= 0.9 && _navStepIndex < 3) {
          _navStepIndex = 3;
        }

        if (_navProgressFraction >= 1.0) {
          _navProgressFraction = 1.0;
          _navTimer?.cancel();
          Fluttertoast.showToast(
            msg: "🎉 Destination Reached Safely!",
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
    Fluttertoast.showToast(msg: _isNavPaused ? "⏸️ Navigation Paused" : "▶️ Resuming Navigation");
  }

  void _endInAppNavigation() {
    _navTimer?.cancel();
    setState(() {
      _isNavigating = false;
      _isNavPaused = false;
      _navProgressFraction = 0.0;
      _navStepIndex = 0;
    });
    Fluttertoast.showToast(msg: "In-App Navigation Ended");
  }

  Future<void> _sendSMS(String number, String message) async {
    final Uri url = Uri.parse("sms:+91$number?body=$message");
    if (!await launchUrl(url)) {
      Fluttertoast.showToast(msg: "Could not send SMS. Try Again.");
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
      final temp = _sourceLocalityName;
      _sourceLocalityName = _destLocalityName;
      _destLocalityName = temp == gpsSourceLabel ? "Sitabuldi" : temp;
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
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: FloatingActionButton.extended(
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (ctx) => AddAuditDialog(
                initialLat: lat ?? 21.1458,
                initialLng: long ?? 79.0882,
                onAuditSubmitted: () {
                  _fetchSafetyLocations();
                  if (mounted) setState(() {});
                },
              ),
            );
          },
          backgroundColor: AppTheme.primaryPurple,
          icon: const Icon(Icons.add_location_alt_rounded, color: Colors.white),
          label: Text(
            'Audit Safety (+50 Pts)',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
      body: SafeArea(
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Route Safety Finder',
                        style: GoogleFonts.outfit(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textDark,
                        ),
                      ),
                      Text(
                        'AI Dynamic Lighting & Crime Engine',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: AppTheme.primaryPurple,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
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
    );
  }

  // --- UI COMPONENTS ---

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
    final localities = _nagpurService.localities;

    final sourceItems = [
      gpsSourceLabel,
      ...localities.map((l) => l.place),
    ];

    final destItems = localities.map((l) => l.place).toList();

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
                    height: 38,
                    color: const Color(0xFFCBD5E1),
                  ),
                  const Icon(Icons.location_on_rounded, color: AppTheme.accentRose, size: 20),
                ],
              ),
              const SizedBox(width: 14),

              // Input Selectors
              Expanded(
                child: Column(
                  children: [
                    // SOURCE SELECTOR (GPS or Custom Nagpur Locality)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: sourceItems.contains(_sourceLocalityName)
                              ? _sourceLocalityName
                              : gpsSourceLabel,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF3B82F6)),
                          items: sourceItems.map((locName) {
                            final isGps = locName == gpsSourceLabel;
                            return DropdownMenuItem<String>(
                              value: locName,
                              child: Row(
                                children: [
                                  Icon(
                                    isGps ? Icons.my_location_rounded : Icons.location_city_rounded,
                                    size: 16,
                                    color: isGps ? const Color(0xFF3B82F6) : AppTheme.primaryPurple,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      locName,
                                      style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: AppTheme.textDark,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (newVal) {
                            if (newVal != null) {
                              setState(() {
                                _sourceLocalityName = newVal;
                                _updateRouteComparison();
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // DESTINATION SELECTOR
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: destItems.contains(_destLocalityName)
                              ? _destLocalityName
                              : (destItems.isNotEmpty ? destItems.first : 'Sitabuldi'),
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.accentRose),
                          items: destItems.map((locName) {
                            final locObj = _nagpurService.searchLocalities(locName).firstOrNull;
                            final score = locObj?.safetyScore ?? 70.0;
                            final color = _getScoreColor(score);
                            return DropdownMenuItem<String>(
                              value: locName,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on_rounded, size: 16, color: AppTheme.accentRose),
                                      const SizedBox(width: 8),
                                      Text(
                                        locName,
                                        style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: AppTheme.textDark,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${score.toStringAsFixed(0)} pts',
                                      style: GoogleFonts.outfit(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: color,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (newVal) {
                            if (newVal != null) {
                              setState(() {
                                _destLocalityName = newVal;
                                _updateRouteComparison();
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Swap Button (⇅)
              IconButton(
                onPressed: _swapSourceAndDestination,
                icon: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryPurple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
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
          const SizedBox(height: 10),

          // Quick GPS Reset Chip
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Start: ${_sourceLocalityName == gpsSourceLabel ? "Live GPS" : _sourceLocalityName}',
                style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
              ),
              if (_sourceLocalityName != gpsSourceLabel)
                InkWell(
                  onTap: () {
                    setState(() {
                      _sourceLocalityName = gpsSourceLabel;
                      _updateRouteComparison();
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.my_location_rounded, size: 13, color: Color(0xFF3B82F6)),
                        const SizedBox(width: 4),
                        Text(
                          'Use My GPS',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF3B82F6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
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
                      Text(
                        'Optimized Safest',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: _useSafestRoute ? Colors.white : AppTheme.textDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${safest?.durationMinutes ?? 42} min | 🛡️ ${safest?.safetyIndex ?? 8.8}/10',
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
                      Text(
                        'Fastest Direct',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: !_useSafestRoute ? Colors.white : AppTheme.textDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${fastest?.durationMinutes ?? 35} min | 🛡️ ${fastest?.safetyIndex ?? 6.4}/10',
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

    final destLoc = _routeComparison?.destination;
    final targetLat = destLoc?.lat ?? 21.155;
    final targetLon = destLoc?.lon ?? 79.082;

    final midLat = (sourceLat + targetLat) / 2;
    final midLon = (sourceLon + targetLon) / 2;

    final polylinePoints = _useSafestRoute
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
          ];

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
                icon: const Icon(Icons.navigation_rounded, size: 20),
                label: Text(
                  "Start Safe Navigation",
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
                  _sendSMS("9109750185", "bSafe Live Navigation Alert: Heading from $_sourceLocalityName to $dest. Live link: $mapLink");
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

    // Interpolate live animated navigation vehicle position
    final currentVehLat = sourceLat + (targetLat - sourceLat) * _navProgressFraction;
    final currentVehLon = sourceLon + (targetLon - sourceLon) * _navProgressFraction;

    final currentInstruction = _navInstructions[_navStepIndex];
    final remainingKm = (detailKm(routeDetail) * (1.0 - _navProgressFraction)).toStringAsFixed(1);
    final remainingMin = ((detailMin(routeDetail)) * (1.0 - _navProgressFraction)).round();

    return Scaffold(
      body: Stack(
        children: [
          // 1. Fullscreen Navigation Map
          FlutterMap(
            options: MapOptions(
              initialCenter: LatLng(currentVehLat, currentVehLon),
              initialZoom: 15.5,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                userAgentPackageName: 'com.bsafe.app',
              ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: [
                      LatLng(sourceLat, sourceLon),
                      LatLng(targetLat, targetLon),
                    ],
                    strokeWidth: 6.0,
                    color: AppTheme.primaryPurple,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  // Live Vehicle / User Position Marker
                  Marker(
                    point: LatLng(currentVehLat, currentVehLon),
                    width: 54,
                    height: 54,
                    alignment: Alignment.center,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Color(0xFF8B5CF6),
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 10)],
                      ),
                      child: const Icon(
                        Icons.navigation_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                  Marker(
                    point: LatLng(targetLat, targetLon),
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    child: const Icon(Icons.location_on_rounded, color: AppTheme.accentRose, size: 40),
                  ),
                ],
              ),
            ],
          ),

          // 2. Top Turn-By-Turn Guidance Banner
          Positioned(
            top: 50,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 16, offset: Offset(0, 4))],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryPurple,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.turn_right_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          currentInstruction,
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Safety Corridor: 🛡️ ${routeDetail?.safetyIndex ?? 8.8}/10 (${routeDetail?.lightingScorePercent ?? 92}% Lit)',
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF10B981),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
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
                            '$remainingMin min',
                            style: GoogleFonts.outfit(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primaryPurple,
                            ),
                          ),
                          Text(
                            '$remainingKm km remaining | ETA 10:45 AM',
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
                                const Icon(Icons.speed_rounded, size: 16, color: Color(0xFF10B981)),
                                const SizedBox(width: 4),
                                Text(
                                  _isNavPaused ? 'Paused' : '32 km/h',
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
        ],
      ),
    );
  }

  double detailKm(RouteSafetyDetail? detail) => detail?.distanceKm ?? 12.4;
  int detailMin(RouteSafetyDetail? detail) => detail?.durationMinutes ?? 42;
}
