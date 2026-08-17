import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:safe/theme/app_theme.dart';
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

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
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
        lat = 28.6139;
        long = 77.2090;
        address = "New Delhi, India";
      });
    }
  }

  void _updateLocation(Position position) {
    setState(() {
      lat = position.latitude;
      long = position.longitude;
      locationMessage = "Lat: ${lat?.toStringAsFixed(4)} | Lon: ${long?.toStringAsFixed(4)}";
      _getAddress(lat!, long!);
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
        address = "${place.name}, ${place.subLocality}, ${place.locality}, "
            "${place.administrativeArea}, ${place.country}";
      });
    } catch (e) {
      setState(() {
        address = "Address not resolved.";
      });
    }
  }

  Future<void> _openMap() async {
    if (lat != null && long != null) {
      final Uri url = Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=$lat,$long');
      if (!await launchUrl(url)) {
        Fluttertoast.showToast(msg: "Could not open map.");
      }
    }
  }

  Future<void> _sendSMS(String number, String message) async {
    final Uri url = Uri.parse("sms:+91$number?body=$message");
    if (!await launchUrl(url)) {
      Fluttertoast.showToast(msg: "Could not send SMS. Try Again.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Live Location',
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textDark,
                ),
              ),
              Text(
                'Real-Time Spatial Coordinate Tracking',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: AppTheme.primaryPurple,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              _buildLocationCard(context),
              const SizedBox(height: 16),
              _buildActionButtons(),
              const SizedBox(height: 16),
              if (lat != null && long != null) _buildMap(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.purpleHeroGradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryPurple.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.my_location_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                'GPS Active',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            locationMessage,
            style: GoogleFonts.outfit(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            address,
            style: GoogleFonts.outfit(
              color: Colors.white.withValues(alpha: 0.95),
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _openMap,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            icon: const Icon(Icons.map_rounded, size: 20),
            label: Text(
              "Open Map",
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              if (lat != null && long != null) {
                mapLink =
                    'https://www.google.com/maps/search/?api=1&query=$lat,$long';
                _sendSMS("+9975202001", mapLink);
              }
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
              "Share Location",
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMap() {
    return Container(
      height: 320,
      decoration: AppTheme.glassCardDecoration(borderRadius: 28),
      clipBehavior: Clip.antiAlias,
      child: FlutterMap(
        options: MapOptions(
          initialCenter: LatLng(lat!, long!),
          initialZoom: 15,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.app',
          ),
          MarkerLayer(markers: [
            Marker(
              point: LatLng(lat!, long!),
              width: 50,
              height: 50,
              alignment: Alignment.center,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.accentRose.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppTheme.accentRose,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.location_on_rounded,
                    size: 26,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ])
        ],
      ),
    );
  }
}
