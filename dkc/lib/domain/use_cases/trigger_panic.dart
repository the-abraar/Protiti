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

  bool get allSent => statuses.isNotEmpty && statuses.values.every((s) => s == SmsStatus.sent);
}

typedef SmsDispatcher = Future<SmsDispatch> Function(List<String> recipients, String message);

/// The foreground SMS path, shared by the SOS and the contact test message:
/// silent SmsManager with per-recipient results on Android, else the visible
/// Messages app, else the share sheet.
Future<SmsDispatch> dispatchSms(List<String> recipients, String message) async {
  if (recipients.isEmpty) return const SmsDispatch('no_contacts', {});
  if (Platform.isAndroid) {
    final results = await NativeSmsService.sendSilently(recipients: recipients, message: message);
    if (results.isNotEmpty) {
      return SmsDispatch('sms', {
        for (final r in recipients) r: results[r] == true ? SmsStatus.sent : SmsStatus.failed,
      });
    }
  }
  final unconfirmed = {for (final r in recipients) r: SmsStatus.unconfirmed};
  try {
    final smsUri = Uri(scheme: 'sms', path: recipients.join(','), queryParameters: {'body': message});
    if (await canLaunchUrl(smsUri) && await launchUrl(smsUri)) {
      return SmsDispatch('sms_app', unconfirmed);
    }
  } catch (_) {}
  try {
    await SharePlus.instance.share(ShareParams(text: message));
    return SmsDispatch('share_sheet', unconfirmed);
  } catch (_) {
    return SmsDispatch('failed', {for (final r in recipients) r: SmsStatus.failed});
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
  /// message leaves. Screen dimming and the audio recording come after.
  Future<PanicResult> execute() async {
    final timestamp = DateTime.now();

    double? lat;
    double? lng;
    String locationStr = 'GPS location unavailable';
    final pos = await locationService.getLastKnownLocation();
    if (pos != null) {
      lat = pos.latitude;
      lng = pos.longitude;
      final at = pos.timestamp.toLocal();
      locationStr =
          'https://maps.google.com/?q=${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)} '
          '(last known at ${_hhmm(at)})';
      if (pos.isMocked) {
        locationStr += "\n[WARNING: GPS Coordinates are actively spoofed/mocked by a third-party app!]";
      }
    }

    List<String> recipientNumbers = [];
    if (contactRepository != null) {
      try {
        final contacts = await contactRepository!.getEmergencyContacts();
        recipientNumbers = contacts.map((c) => c.phone).where((p) => p.isNotEmpty).toList();
      } catch (_) {}
    }
    // No hotline fallback: 999 and 109 take calls, not texts. With no contact
    // set, the screen says so and offers the call button instead.

    final message =
        'EMERGENCY SOS [Protiti]: I need urgent help! My location: $locationStr at ${_hhmm(timestamp)} (BD Time). Please send assistance immediately.';

    final dispatch = await sendSms(recipientNumbers, message);

    if (dispatch.allSent) {
      try {
        // Blackout so the screen glow does not give her away. Skipped when
        // anything failed: she must be able to read the error and call 999.
        await ScreenBrightness().setApplicationScreenBrightness(0.0);
      } catch (_) {}
    }
    _recordAmbientAudio();

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

  /// Two minutes of ambient audio, saved as an evidence row. If the app dies
  /// first, the next launch recovers the file.
  Future<void> _recordAmbientAudio() async {
    try {
      if (!await audioService.startRecording(askPermission: false)) return;
      await Future.delayed(const Duration(minutes: 2));
      await audioService.stopAndSave(evidenceRepository, description: 'Emergency recording');
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
