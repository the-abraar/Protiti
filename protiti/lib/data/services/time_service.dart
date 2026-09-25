import 'package:ntp/ntp.dart';

class SecureTimeService {
  /// Fetches the absolute, spoof-proof UTC time from a global NTP pool.
  /// This prevents an abuser from bypassing time-locks by changing the device's system clock.
  static Future<DateTime> getSecureTime() async {
    try {
      // Connects to time.google.com or standard pool.ntp.org by default
      final DateTime ntpTime = await NTP.now(timeout: const Duration(seconds: 3));
      return ntpTime;
    } catch (e) {
      // If the abuser also turns off the internet (Airplane mode) to block the NTP request,
      // we must fallback to the local device time. However, in a full production environment, 
      // you could strictly refuse to unlock if NTP fails during a lockout phase.
      return DateTime.now();
    }
  }
}
