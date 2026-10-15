import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';

/// Hard, deliberate shaking only. What each threshold guards against (all
/// to be field-tested on real phones; owner TODO):
/// - rickshaw and CNG vibration, potholes: single jolts pass 2 g, so a peak
///   must pass [threshold] and [peaks] of them must fall within [window];
/// - a phone swinging in a bag or pocket while walking: about 1-2 g, under
///   [threshold];
/// - one jolt read as several: peaks closer than [minGap] count once.
/// Every trigger still waits [sosCancelWindow] before anything sends.
class ShakeDetector {
  static const threshold = 3.0; // g, gravity removed
  static const peaks = 4;
  static const minGap = Duration(milliseconds: 400);
  static const window = Duration(seconds: 3);

  final _times = <int>[];

  /// True when this sample completes a shake; counting then starts afresh.
  bool add(double gForce, int nowMs) {
    if (gForce < threshold) return false;
    if (_times.isNotEmpty && nowMs - _times.last < minGap.inMilliseconds) {
      return false;
    }
    _times
      ..add(nowMs)
      ..removeWhere((t) => nowMs - t > window.inMilliseconds);
    if (_times.length < peaks) return false;
    _times.clear();
    return true;
  }
}

class ShakeToSosService {
  final void Function() onShake;
  final _detector = ShakeDetector();
  final _clock = Stopwatch()..start();
  StreamSubscription? _accelerometerSubscription;

  ShakeToSosService(this.onShake);

  bool get listening => _accelerometerSubscription != null;

  void startListening() {
    _accelerometerSubscription ??=
        // ~15 Hz: the default 5 Hz misses most peaks of a hard shake.
        userAccelerometerEventStream(
          samplingPeriod: SensorInterval.uiInterval,
        ).listen((e) {
          final g = sqrt(e.x * e.x + e.y * e.y + e.z * e.z) / 9.80665;
          if (_detector.add(g, _clock.elapsedMilliseconds)) onShake();
        });
  }

  void stopListening() {
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;
  }
}
