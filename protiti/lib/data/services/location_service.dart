import 'package:geolocator/geolocator.dart';

class LocationService {
  Future<Position?> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return null;
    }

    try {
      // Enforce a strict 4-second timeout for emergency scenarios
      return await Geolocator.getCurrentPosition().timeout(
        const Duration(seconds: 4),
        onTimeout: () {
          throw Exception('Location fetch timed out');
        },
      );
    } catch (e) {
      // Gracefully return null if GPS hangs, allowing the SOS SMS to 
      // dispatch immediately with a "Location unavailable" fallback string.
      return null;
    }
  }
}
