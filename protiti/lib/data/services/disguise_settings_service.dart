import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the survivor's choice of whether the app should always open
/// straight into the calculator disguise, rather than the branded Protiti
/// lock screen. Left off by default (matching prior behavior); once turned
/// on, LockScreen skips the reveal entirely, which matters most for anyone
/// on a shared or monitored device who can't rely on remembering to tap the
/// disguise toggle every single time the phone is opened.
class DisguiseSettingsService {
  static const _storage = FlutterSecureStorage();
  static const _alwaysLaunchAsCalculatorKey = 'always_launch_as_calculator';

  static Future<bool> getAlwaysLaunchAsCalculator() async {
    try {
      final value = await _storage.read(key: _alwaysLaunchAsCalculatorKey);
      return value == 'true';
    } catch (_) {
      return false;
    }
  }

  static Future<void> setAlwaysLaunchAsCalculator(bool value) async {
    try {
      await _storage.write(
        key: _alwaysLaunchAsCalculatorKey,
        value: value.toString(),
      );
    } catch (_) {}
  }
}
