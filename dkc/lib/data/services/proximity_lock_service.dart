import 'package:proximity_sensor/proximity_sensor.dart';
import 'dart:async';

class ProximityLockService {
  StreamSubscription<int>? _subscription;
  Timer? _debounceTimer;

  /// How long the "covered" reading must persist before we treat it as a
  /// real face-down/pocketed placement rather than sensor jitter (a brief
  /// hand pass, ambient IR noise) — firing on every flicker is what was
  /// bouncing survivors back to the lock screen during normal use.
  static const _sustainedCoverage = Duration(milliseconds: 1200);

  /// Listens to the hardware proximity sensor (usually located next to the front camera).
  void startListening(Function onProximityTriggered) {
    _subscription = ProximitySensor.events.listen((int event) {
      // event > 0 usually indicates the sensor is actively covered
      // (e.g., the device is placed face-down on a surface, or covered by a hand)
      if (event > 0) {
        _debounceTimer ??= Timer(_sustainedCoverage, () {
          _debounceTimer = null;
          onProximityTriggered();
        });
      } else {
        _debounceTimer?.cancel();
        _debounceTimer = null;
      }
    });
  }

  void stopListening() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _subscription?.cancel();
  }
}
