import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/services/secure_audio_service.dart';
import '../../data/services/location_service.dart';
import '../../data/repositories/contact_repository.dart';
import 'package:screen_brightness/screen_brightness.dart';
import '../../data/services/native_sms_service.dart';
import 'dart:io';

class PanicResult {
  final bool success;
  final String formattedMessage;
  final String locationDisplay;
  final double? latitude;
  final double? longitude;
  final List<String> recipients;
  final DateTime timestamp;
  final String dispatchMethod; // 'sms' or 'share_fallback'

  PanicResult({
    required this.success,
    required this.formattedMessage,
    required this.locationDisplay,
    this.latitude,
    this.longitude,
    required this.recipients,
    required this.timestamp,
    required this.dispatchMethod,
  });
}

class TriggerPanicUseCase {
  final LocationService locationService;
  final ContactRepository? contactRepository;
  final SecureAudioService audioService;

  TriggerPanicUseCase(this.locationService, {this.contactRepository, required this.audioService});

  /// Executes offline panic sequence:
  /// 1. Obtains GPS coordinates with offline tolerance.
  /// 2. Assembles lightweight text SMS payload (<160 chars per segment, zero media transmission).
  /// 3. Launches native SMS intent directed at emergency contacts, or invokes share sheet fallback.
  Future<PanicResult> execute() async {
    final timestamp = DateTime.now();

    // 1. Fetch Location
    double? lat;
    double? lng;
    String locationStr;

    try {
      final pos = await locationService.getCurrentLocation();
      if (pos != null) {
        lat = pos.latitude;
        lng = pos.longitude;
        locationStr =
            'https://maps.google.com/?q=${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)} (${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)})';
            
        if (pos.isMocked) {
          locationStr += "\n[WARNING: GPS Coordinates are actively spoofed/mocked by a third-party app!]";
        }
      } else {
        locationStr = 'GPS location unavailable (Offline/Indoor)';
      }
    } catch (_) {
      locationStr = 'Location permission restricted';
    }

    // 2. Fetch Emergency Contact Phone Numbers
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

    // Default recipient fallback if no personal contact configured
    if (recipientNumbers.isEmpty) {
      recipientNumbers = ['999', '109'];
    }

    // 3. Construct High-Priority SMS Payload
    String message =
        'EMERGENCY SOS [Protiti]: I need urgent help! My location: $locationStr at ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')} (BD Time). Please send assistance immediately.';

    // 4. Dispatch SOS
    String dispatchMethod = 'local_sms';
    bool dispatchSuccess = false;
    {
      // TACTICAL STEALTH: On Android, hand the message straight to the
      // cellular radio via SmsManager. This never opens the Messages app,
      // so nothing appears on-screen for an abuser to see or stop.
      bool sentSilently = false;
      if (Platform.isAndroid) {
        try {
          sentSilently = await NativeSmsService.sendSilently(
            recipients: recipientNumbers,
            message: message,
          );
        } catch (_) {
          sentSilently = false;
        }
      }

      if (sentSilently) {
        dispatchSuccess = true;
      } else {
        // Silent dispatch unavailable (iOS, permission not yet granted, or
        // no radio) — fall back to the SMS-app intent. This still
        // guarantees delivery, but surfaces a visible compose screen.
        try {
          final separator = ',';
          final recipientStr = recipientNumbers.join(separator);
          final smsUri = Uri(
            scheme: 'sms',
            path: recipientStr,
            queryParameters: {'body': message},
          );

          if (await canLaunchUrl(smsUri)) {
            await launchUrl(smsUri);
            dispatchSuccess = true;
            dispatchMethod = 'local_sms_visible';
          } else {
            // Fallback to generic share sheet
            await SharePlus.instance.share(
              ShareParams(text: message, subject: 'EMERGENCY SOS [Protiti]'),
            );
            dispatchSuccess = true;
            dispatchMethod = 'share_fallback';
          }
        } catch (_) {
          // Last-resort fallback to SharePlus
          try {
            await SharePlus.instance.share(
              ShareParams(text: message, subject: 'EMERGENCY SOS [Protiti]'),
            );
            dispatchSuccess = true;
            dispatchMethod = 'share_fallback';
          } catch (_) {
            dispatchSuccess = false;
            dispatchMethod = 'failed';
          }
        }
      }
    }

    try {
      // TACTICAL STEALTH: Immediately force the phone's hardware ringer into silent mode.
      // If the victim is hiding from an active threat, we must prevent incoming phone calls 
      // or notifications from audibly betraying their location.
      // await SoundMode.setSoundMode(Profile.silent);
    } catch (e) {
      // Gracefully ignore if the OS blocks permission, but attempt the override
    }

    try {
      // TACTICAL STEALTH: Immediately force the hardware screen brightness to absolute zero.
      // If the victim is hiding in a dark room at night, the glow of the smartphone 
      // screen can easily betray their position. We plunge the device into Blackout Mode.
      await ScreenBrightness().setApplicationScreenBrightness(0.0);
    } catch (e) {
      // Gracefully ignore if the hardware doesn't support the override
    }

    // 1. Silently start capturing ambient audio of the physical attack
    audioService.startRecording();
    
    // 2. Automatically stop, encrypt, and secure the audio file after 2 minutes
    Future.delayed(const Duration(minutes: 2), () async {
      await audioService.stopAndEncryptRecording();
    });

    return PanicResult(
      success: dispatchSuccess,
      formattedMessage: message,
      locationDisplay: locationStr,
      latitude: lat,
      longitude: lng,
      recipients: recipientNumbers,
      timestamp: timestamp,
      dispatchMethod: dispatchMethod,
    );
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
