import 'dart:io';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/repositories/contact_repository.dart';
import '../../data/repositories/evidence_repository.dart';
import '../../data/services/location_service.dart';
import '../../data/services/native_sms_service.dart';
import '../../data/services/secure_audio_service.dart';

/// What is known about one recipient's message.
enum SmsStatus {
  /// The phone network accepted it.
  sent,

  /// The network refused it: no SIM, no credit, no signal, airplane mode.
  failed,

  /// Handed to the Messages app or share sheet; she still has to press Send.
  unconfirmed,
}

class SmsDispatch {
  /// 'sms', 'sms_app', 'share_sheet', 'failed' or 'no_contacts'.
  final String method;
  final Map<String, SmsStatus> statuses;

  const SmsDispatch(this.method, this.statuses);

  bool get allSent =>
      statuses.isNotEmpty && statuses.values.every((s) => s == SmsStatus.sent);
}

typedef SmsDispatcher =
    Future<SmsDispatch> Function(List<String> recipients, String message);

/// Silent SmsManager only, for when nobody may see anything: the background
/// triggers and the second PIN. Where silent sending is impossible (iOS, no
/// permission) every recipient is failed; it never opens Messages.
Future<SmsDispatch> dispatchSilentSms(
  List<String> recipients,
  String message,
) async {
  if (recipients.isEmpty) return const SmsDispatch('no_contacts', {});
  final results = Platform.isAndroid
      ? await NativeSmsService.sendSilently(
          recipients: recipients,
          message: message,
        )
      : const <String, bool>{};
  return SmsDispatch(results.isEmpty ? 'failed' : 'sms', {
    for (final r in recipients)
      r: results[r] == true ? SmsStatus.sent : SmsStatus.failed,
  });
}

/// The foreground SMS path, shared by the SOS and the contact test message:
/// silent SmsManager with per-recipient results on Android, else the visible
/// Messages app, else the share sheet.
Future<SmsDispatch> dispatchSms(List<String> recipients, String message) async {
  if (recipients.isEmpty) return const SmsDispatch('no_contacts', {});
  if (Platform.isAndroid) {
    final silent = await dispatchSilentSms(recipients, message);
    if (silent.method == 'sms') return silent;
  }
  final unconfirmed = {for (final r in recipients) r: SmsStatus.unconfirmed};
  try {
    final smsUri = Uri(
      scheme: 'sms',
      path: recipients.join(','),
      queryParameters: {'body': message},
    );
    if (await canLaunchUrl(smsUri) && await launchUrl(smsUri)) {
      return SmsDispatch('sms_app', unconfirmed);
    }
  } catch (_) {}
  try {
    await SharePlus.instance.share(ShareParams(text: message));
    return SmsDispatch('share_sheet', unconfirmed);
  } catch (_) {
    return SmsDispatch('failed', {
      for (final r in recipients) r: SmsStatus.failed,
    });
  }
}

class PanicResult {
  final String formattedMessage;
  final String locationDisplay;
  final double? latitude;
  final double? longitude;
  final DateTime timestamp;
  final SmsDispatch dispatch;

  PanicResult({
    required this.formattedMessage,
    required this.locationDisplay,
    this.latitude,
    this.longitude,
    required this.timestamp,
    required this.dispatch,
  });

  List<String> get recipients => dispatch.statuses.keys.toList();
  String get dispatchMethod => dispatch.method;
  bool get success => dispatch.allSent;
}

class TriggerPanicUseCase {
  final LocationService locationService;
  final ContactRepository? contactRepository;
  final SecureAudioService audioService;
  final EvidenceRepository evidenceRepository;
  final SmsDispatcher sendSms;

  TriggerPanicUseCase(
    this.locationService, {
    this.contactRepository,
    required this.audioService,
    required this.evidenceRepository,
    this.sendSms = dispatchSms,
  });

  /// SMS first: the cached location only, nothing to wait for before the
  /// message leaves. Then, if asked, screen dimming and the audio recording.
  /// [dim] is for the app on screen; the second-PIN alert turns off both,
  /// since a dark screen or the microphone indicator would give it away.
  /// [sms] replaces [sendSms] for this one send. A [practice] run sends the
  /// practice text instead of the SOS, and never records.
  Future<PanicResult> execute({
    bool dim = true,
    bool record = true,
    SmsDispatcher? sms,
    bool practice = false,
  }) async {
    final timestamp = DateTime.now();

    double? lat;
    double? lng;
    String locationStr = 'Location unknown';
    final pos = await locationService.getLastKnownLocation();
    if (pos != null) {
      lat = pos.latitude;
      lng = pos.longitude;
      locationStr =
          '${mapsLink(lat, lng)} (at ${_when(pos.timestamp.toLocal())})';
    }

    List<String> recipientNumbers = [];
    if (contactRepository != null) {
      try {
        final contacts = await contactRepository!.getEmergencyContacts();
        recipientNumbers = contacts
            .map((c) => c.phone)
            .where((p) => p.isNotEmpty)
            .toList();
      } catch (_) {}
    }
    // No hotline fallback: 999 and 109 take calls, not texts. With no contact
    // set, the screen says so and offers the call button instead.

    final message = sosMessage(
      lat: lat,
      lng: lng,
      fixedAt: pos?.timestamp.toLocal(),
      mocked: pos?.isMocked ?? false,
      practice: practice,
    );

    final dispatch = await (sms ?? sendSms)(recipientNumbers, message);

    if (dim && dispatch.allSent) {
      try {
        // Blackout so the screen glow does not give her away. Skipped when
        // anything failed: she must be able to read the error and call 999.
        await ScreenBrightness().setApplicationScreenBrightness(0.0);
      } catch (_) {}
    }
    if (record && !practice) _recordAmbientAudio();

    return PanicResult(
      formattedMessage: message,
      locationDisplay: locationStr,
      latitude: lat,
      longitude: lng,
      timestamp: timestamp,
      dispatch: dispatch,
    );
  }

  static String _hhmm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  /// The fix time, with day/month unless it is from today, so an old fix
  /// never reads as current (N11). [dateOnly] keeps the SMS within 2 parts.
  static String _when(DateTime t, {bool dateOnly = false}) {
    final now = DateTime.now();
    if (t.year == now.year && t.month == now.month && t.day == now.day) {
      return _hhmm(t);
    }
    return dateOnly ? '${t.day}/${t.month}' : '${t.day}/${t.month} ${_hhmm(t)}';
  }

  static String mapsLink(double lat, double lng) =>
      'https://maps.google.com/?q=${lat.toStringAsFixed(5)},${lng.toStringAsFixed(5)}';

  /// Bangla forces UCS-2: 70 characters in one SMS, 67 per part beyond that.
  static const maxSmsParts = 2;

  /// Bangla and English, no app name (it may stay in her Sent messages), the
  /// time (and, if not today, the date) of the location fix and the map link. Every case, the longest
  /// coordinates included, fits in [maxSmsParts] parts (tested).
  static String sosMessage({
    double? lat,
    double? lng,
    DateTime? fixedAt,
    bool mocked = false,
    bool practice = false,
  }) {
    final head = practice
        ? practiceHead
        : 'জরুরি! সাহায্য দরকার। Urgent, help me!';
    if (lat == null || lng == null) {
      return '$head অবস্থান জানা নেই/Location unknown.';
    }
    final at = fixedAt == null ? '' : ' ${_when(fixedAt, dateOnly: true)}';
    final doubt = mocked ? ', হয়তো ভুল/may be wrong' : '';
    return '$head অবস্থান/Location$at$doubt: ${mapsLink(lat, lng)}';
  }

  /// Opens a practice text, so a contact knows to ignore it (N16).
  static const practiceHead = 'পরীক্ষা মাত্র। Just a test, ignore.';

  /// Two minutes of ambient audio, saved as an evidence row. If the app dies
  /// first, the next launch recovers the file.
  Future<void> _recordAmbientAudio() async {
    try {
      if (!await audioService.startRecording(askPermission: false)) return;
      await Future.delayed(const Duration(minutes: 2));
      await audioService.stopAndSave(
        evidenceRepository,
        description: 'Emergency recording',
      );
    } catch (_) {}
  }

  /// Forces the host OS to immediately open the phone dialer and call the
  /// national emergency hotline, bypassing the need for the victim to manually dial.
  Future<void> launchEmergencyCall() async {
    // 999 is the National Emergency Hotline in Bangladesh
    final Uri callUri = Uri.parse('tel:999');
    try {
      if (await canLaunchUrl(callUri)) {
        await launchUrl(callUri);
      }
    } catch (e) {
      // Graceful fallback if the device has no cellular hardware (e.g., a Wi-Fi only tablet)
    }
  }
}
