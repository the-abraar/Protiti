import 'dart:async';
import 'package:flutter/services.dart';

/// Sends SMS silently via Android's `SmsManager`, without opening the
/// Messages app: no visible compose screen, no "Send" tap for someone
/// standing over her to see. Android may still copy each text into the
/// Messages app's history, so the wording stays short and app-neutral.
///
/// iOS has no silent SMS. There this returns an empty map and callers fall
/// back to the visible Messages compose sheet.
class NativeSmsService {
  /// Served by the hardware_sos plugin, which Flutter registers on every
  /// engine, the background service's included, so power-button and shake
  /// SOS can send with the app closed (B8).
  static const MethodChannel channel = MethodChannel('hardware_sos');

  /// Permission prompts need the activity, so MainActivity serves these.
  static const MethodChannel _activity = MethodChannel('com.protiti.protiti/sms');

  static final _deliveries = StreamController<(String, bool)>.broadcast();

  /// (recipient, delivered) from the network's delivery reports. They come
  /// seconds to minutes after the send, or never; no report means unknown.
  static Stream<(String, bool)> get deliveries {
    _listen();
    return _deliveries.stream;
  }

  static void _listen() => channel.setMethodCallHandler((call) async {
        if (call.method != 'delivered') return;
        final args = call.arguments as Map;
        _deliveries.add((args['recipient'] as String, args['delivered'] == true));
      });

  static Future<bool> _ask(MethodChannel c, String method) async {
    try {
      return await c.invokeMethod<bool>(method) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> hasPermission() => _ask(channel, 'hasSmsPermission');

  /// Prompts for SEND_SMS. Call it from Settings after an explanation, never
  /// mid-emergency: the OS dialog is itself visible on screen.
  static Future<bool> requestPermission() => _ask(_activity, 'requestSmsPermission');

  static Future<bool> hasNotificationPermission() => _ask(channel, 'hasNotificationPermission');

  /// Android 13+ asks; older versions just report whether notices are on.
  static Future<bool> requestNotificationPermission() =>
      _ask(_activity, 'requestNotificationPermission');

  /// Per recipient: true only when the network accepted the message
  /// (Android sentIntent). Empty when silent sending is unavailable here (iOS,
  /// no permission, no plugin). Never throws, and never requests permission.
  static Future<Map<String, bool>> sendSilently({
    required List<String> recipients,
    required String message,
  }) async {
    if (recipients.isEmpty) return const {};
    try {
      if (!await hasPermission()) return const {};
      _listen();
      return await channel.invokeMapMethod<String, bool>('sendSms', {
            'recipients': recipients,
            'message': message,
          }) ??
          const {};
    } catch (_) {
      return const {};
    }
  }
}
