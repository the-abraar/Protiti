import 'package:flutter_dynamic_icon/flutter_dynamic_icon.dart';
import 'package:flutter_dynamic_icon/flutter_dynamic_icon.dart';

class CamouflageService {
  /// Rewrites the native OS manifest mapping to swap the home screen icon 
  /// and application name to a generic calculator.
  static Future<void> enableCalculatorDisguise() async {
    try {
      if (await FlutterDynamicIcon.supportsAlternateIcons) {
        // "calculator_icon" must match the alternate asset declared in the iOS Info.plist 
        // and Android AndroidManifest.xml activity-aliases.
        await FlutterDynamicIcon.setAlternateIconName("calculator_icon");
      }
    } catch (e) {
      // Gracefully ignore if the host launcher restricts icon swapping
    }
  }

  /// Restores the original Protiti brand identity.
  static Future<void> restoreOriginalIdentity() async {
    try {
      if (await FlutterDynamicIcon.supportsAlternateIcons) {
        await FlutterDynamicIcon.setAlternateIconName(null);
      }
    } catch (e) {
      // Fallback
    }
  }
}
