import 'package:flutter/services.dart';

/// Sends SMS silently via the native Android `SmsManager`, without ever
/// opening the Messages app UI — no visible compose screen, no "Send" tap
/// an abuser standing over the victim could witness or intercept.
///
/// iOS has no equivalent private API for silent SMS dispatch. On iOS this
/// always returns an empty map so callers fall back to the visible SMS-intent /
/// share-sheet path, which still guarantees delivery.
class NativeSmsService {
  static const MethodChannel _channel =
      MethodChannel('com.protiti.protiti/sms');

  static Future<bool> hasPermission() async {
    try {
      return await _channel.invokeMethod<bool>('hasSmsPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Prompts for SEND_SMS permission. Call this ahead of time (e.g. when the
  /// survivor opens the Panic screen) rather than at the moment of an actual
  /// trigger — the OS permission dialog is itself visible on-screen, so
  /// surfacing it mid-emergency would defeat the point of a silent alert.
  static Future<bool> requestPermission() async {
    try {
      return await _channel.invokeMethod<bool>('requestSmsPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Per recipient: true only when the network accepted the message
  /// (Android sentIntent). Empty when silent sending is unavailable here (iOS,
  /// no permission, no channel on this engine). Never throws, and never
  /// requests permission itself.
  static Future<Map<String, bool>> sendSilently({
    required List<String> recipients,
    required String message,
  }) async {
    if (recipients.isEmpty) return const {};
    try {
      if (!await hasPermission()) return const {};
      return await _channel.invokeMapMethod<String, bool>('sendSilentSms', {
            'recipients': recipients,
            'message': message,
          }) ??
          const {};
    } catch (_) {
      return const {};
    }
  }
}
