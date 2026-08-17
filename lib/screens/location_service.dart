import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  Future<Position> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
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

    return await Geolocator.getCurrentPosition();
  }

  Future<String> getAddressFromCoordinates(double latitude, double longitude) async {
    List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);
    Placemark place = placemarks[0];

    return "${place.name}, ${place.subLocality}, ${place.locality}, ${place.administrativeArea}, ${place.country}, ${place.postalCode}";
  }
}