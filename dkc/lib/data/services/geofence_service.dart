import 'package:geolocator/geolocator.dart';
import 'dart:async';
import '../../domain/use_cases/trigger_panic.dart';

class GeofenceService {
  final TriggerPanicUseCase _triggerPanicUseCase;
  
  // Example coordinates of a highly dangerous zone (e.g. an abuser's address)
  final double dangerLat = 23.8103; 
  final double dangerLng = 90.4125;
  
  // Trigger if the victim comes within 500 meters of the danger zone
  final double dangerRadiusMeters = 500.0;

  StreamSubscription<Position>? _positionSubscription;

  GeofenceService(this._triggerPanicUseCase);

  void startGeofenceMonitoring() {
    // Listen to location changes with a 100-meter filter to save battery
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 100, 
      ),
    ).listen((Position position) {
      
      // FORENSIC ANTI-TAMPER: Check if the GPS coordinates are being maliciously spoofed 
      // by a third-party application or developer tools.
      if (position.isMocked) {
        // TACTICAL ESCALATION: The device's location is being actively manipulated!
        // Instantly trigger the SOS broadcast, because the restraining order perimeter 
        // defense is under active attack.
        _triggerPanicUseCase.execute();
        return; // Halt further processing
      }

      // Calculate distance between current location and the danger zone
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        dangerLat,
        dangerLng,
      );

      // If the perimeter is breached, trigger the SOS automatically!
      if (distance < dangerRadiusMeters) {
        _triggerPanicUseCase.execute();
      }
    });
  }

  void stopGeofenceMonitoring() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }
}
