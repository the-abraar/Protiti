import 'package:flutter_jailbreak_detection/flutter_jailbreak_detection.dart';

class ThreatDetectionService {
  /// Scans the host OS for root access, jailbreaks, or active developer debugging modes
  /// which stalkerware typically requires to operate.
  static Future<bool> isDeviceCompromised() async {
    bool isJailbroken = false;
    bool isDeveloperModeActive = false;
    
    try {
      isJailbroken = await FlutterJailbreakDetection.jailbroken;
      isDeveloperModeActive = await FlutterJailbreakDetection.developerMode;
    } catch (e) {
      // Graceful fallback if the native plugin fails
      return false;
    }
    
    return isJailbroken || isDeveloperModeActive;
  }
}
