import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import '../../domain/use_cases/trigger_panic.dart';
import 'notification_service.dart';

class ShakeToSosService {
  final TriggerPanicUseCase _triggerPanicUseCase;
  StreamSubscription? _accelerometerSubscription;
  
  // Requires roughly 2.7 Gs of force (an aggressive, intentional shake)
  static const double _shakeThresholdGravity = 2.7;
  static const int _shakeSlopTimeMs = 500;
  static const int _shakeCountResetTimeMs = 3000;
  
  int _shakeCount = 0;
  int _lastShakeTime = 0;

  ShakeToSosService(this._triggerPanicUseCase);

  void startListening() {
    _accelerometerSubscription = userAccelerometerEventStream().listen((UserAccelerometerEvent event) {
      double x = event.x;
      double y = event.y;
      double z = event.z;

      // Normalize to g-force
      double gX = x / 9.80665;
      double gY = y / 9.80665;
      double gZ = z / 9.80665;

      // Calculate the g-force vector magnitude
      double gForce = sqrt(gX * gX + gY * gY + gZ * gZ);

      if (gForce > _shakeThresholdGravity) {
        final now = DateTime.now().millisecondsSinceEpoch;
        
        // Ignore shake events that are too close to each other
        if (_lastShakeTime + _shakeSlopTimeMs > now) {
          return;
        }

        // Reset the shake count if the last shake was more than 3 seconds ago
        if (_lastShakeTime + _shakeCountResetTimeMs < now) {
          _shakeCount = 0;
        }

        _lastShakeTime = now;
        _shakeCount++;

        // If we register 3 distinct, aggressive shakes -> Trigger SOS!
        if (_shakeCount >= 3) {
          _shakeCount = 0; // Reset
          _triggerPanicUseCase.execute().then((_) async {
             final notifier = StealthNotificationService();
             await notifier.init();
             await notifier.showStealthNotification(event: 'sos_sent');
          });
        }
      }
    });
  }

  void stopListening() {
    _accelerometerSubscription?.cancel();
  }
}
