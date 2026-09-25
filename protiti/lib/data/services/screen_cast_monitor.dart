import 'package:screen_protector/screen_protector.dart';

class ScreenCastMonitor {
  /// Arms the active screen recording / casting detector, as well as screenshot detection.
  static Future<void> startMonitoring({
    required Function onCastDetected,
    required Function onScreenshotAttempted,
  }) async {
    try {
      // 1. Proactively check if the screen is ALREADY being recorded when the Vault opens
      bool isRecording = await ScreenProtector.isRecording();
      if (isRecording) {
        onCastDetected();
      }
      
      // 2. Set up a real-time listener in case the abuser starts a cast 
      // while the victim already has the app open, OR attempts a screenshot.
      ScreenProtector.addListener(
        () {
          onScreenshotAttempted();
        },
        (isRecording) {
          if (isRecording) onCastDetected();
        }
      );
    } catch (e) {
      // Graceful fallback
    }
  }

  static void stopMonitoring() {
    ScreenProtector.removeListener();
  }
}
