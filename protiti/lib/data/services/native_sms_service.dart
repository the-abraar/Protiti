import 'package:flutter/services.dart';

/// Sends SMS silently via the native Android `SmsManager`, without ever
/// opening the Messages app UI — no visible compose screen, no "Send" tap
/// an abuser standing over the victim could witness or intercept.
///
/// iOS has no equivalent private API for silent SMS dispatch. On iOS this
/// always returns false so callers fall back to the visible SMS-intent /
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

  /// Returns true only if every recipient's SMS was handed to the radio
  /// silently. Never throws, and never requests permission itself.
  static Future<bool> sendSilently({
    required List<String> recipients,
    required String message,
  }) async {
    if (recipients.isEmpty) return false;
    try {
      if (!await hasPermission()) return false;
      return await _channel.invokeMethod<bool>('sendSilentSms', {
            'recipients': recipients,
            'message': message,
          }) ??
          false;
    } catch (_) {
      return false;
    }
  }
}
