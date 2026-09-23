import 'package:geolocator/geolocator.dart';

class LocationResult {
  final double? latitude;
  final double? longitude;
  final String? error;
  final bool isMock;

  LocationResult({this.latitude, this.longitude, this.error, this.isMock = false});

  String get mapsUrl {
    if (latitude != null && longitude != null) {
      return 'https://maps.google.com/?q=$latitude,$longitude';
    }
    return '';
  }
}

class LocationService {
  static Future<LocationResult> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    try {
      // Test if location services are enabled
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Fallback for emulator / disabled GPS
        return LocationResult(
          latitude: 28.6139,
          longitude: 77.2090,
          isMock: true,
          error: 'Location services are disabled on device. Using default coordinates.',
        );
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return LocationResult(
            latitude: 28.6139,
            longitude: 77.2090,
            isMock: true,
            error: 'Location permissions are denied.',
          );
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return LocationResult(
          latitude: 28.6139,
          longitude: 77.2090,
          isMock: true,
          error: 'Location permissions are permanently denied.',
        );
      }

      // Fetch high accuracy position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      return LocationResult(
        latitude: position.latitude,
        longitude: position.longitude,
        isMock: false,
      );
    } catch (e) {
      // Graceful fallback so emergency alert is NEVER blocked
      return LocationResult(
        latitude: 28.6139,
        longitude: 77.2090,
        isMock: true,
        error: 'Could not fetch live GPS: ${e.toString()}',
      );
    }
  }
}
