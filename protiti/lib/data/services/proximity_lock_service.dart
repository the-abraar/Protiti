import 'package:proximity_sensor/proximity_sensor.dart';
import 'dart:async';
import 'package:proximity_sensor/proximity_sensor.dart';

class ProximityLockService {
  StreamSubscription<int>? _subscription;

  /// Listens to the hardware proximity sensor (usually located next to the front camera).
  void startListening(Function onProximityTriggered) {
    _subscription = ProximitySensor.events.listen((int event) {
      // event > 0 usually indicates the sensor is actively covered 
      // (e.g., the device is placed face-down on a surface, or covered by a hand)
      if (event > 0) {
        onProximityTriggered();
      }
    });
  }

  void stopListening() {
    _subscription?.cancel();
  }
}
