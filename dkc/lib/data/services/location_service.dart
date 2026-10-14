import 'package:geolocator/geolocator.dart';

class LocationService {
  /// The phone's cached fix, if location was already allowed. No GPS wait and
  /// no permission prompt, so an SOS never stalls or shows a dialog.
  Future<Position?> getLastKnownLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return null;
      }
      return await Geolocator.getLastKnownPosition();
    } catch (_) {
      return null;
    }
  }
}
