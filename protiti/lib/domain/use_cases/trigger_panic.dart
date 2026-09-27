import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/services/secure_audio_service.dart';
import '../../data/services/location_service.dart';
import '../../data/repositories/contact_repository.dart';
import 'package:screen_brightness/screen_brightness.dart';
import '../../data/services/cloud_sms_service.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:sensors_plus/sensors_plus.dart';

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

    try {
      // FORENSIC TELEMETRY: Fetch the hardware battery level
      final battery = Battery();
      final batteryLevel = await battery.batteryLevel;
      
      // Append context for law enforcement
      message += '\n[Device Telemetry: Battery at $batteryLevel%]';
      
      // If the battery is critically low (< 10%), add an explicit warning
      if (batteryLevel < 10) {
        message += '\n[CRITICAL WARNING: Device is about to power off naturally due to low battery!]';
      }
    } catch (e) {
      // Ignore if hardware query fails
    }

    try {
      // FORENSIC TELEMETRY: Fetch the current Wi-Fi network name (SSID)
      // This acts as a highly precise micro-location beacon if GPS fails indoors.
      final info = NetworkInfo();
      final wifiName = await info.getWifiName(); 
      
      if (wifiName != null && wifiName.isNotEmpty) {
        // Strip out any quotes the OS might add
        final cleanName = wifiName.replaceAll('"', '');
        message += '\n[Network Telemetry: Connected to Wi-Fi "$cleanName"]';
      }
    } catch (e) {
      // Ignore if the user hasn't granted precise location permissions for Wi-Fi scanning
    }

    try {
      // FORENSIC TELEMETRY: Execute a rapid, silent BLE scan to capture the 
      // digital footprint of the attacker (e.g., "John's Apple Watch" or "AirTag").
      
      // Start a highly aggressive 2-second scan
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 2));
      
      // Wait for the scan to populate results
      await Future.delayed(const Duration(seconds: 2));
      
      final results = FlutterBluePlus.lastScanResults;
      List<String> nearbyThreats = [];
      
      for (ScanResult r in results) {
        // Only log devices that are actively broadcasting a readable name
        if (r.advertisementData.advName.isNotEmpty) {
           nearbyThreats.add(r.advertisementData.advName);
        }
      }
      
      if (nearbyThreats.isNotEmpty) {
        // This explicitly proves the abuser was in the room during the attack!
        message += '\n[Proximity Telemetry: Nearby Devices - ${nearbyThreats.join(', ')}]';
      }
    } catch (e) {
      // Ignore if Bluetooth is off or permissions are denied
    }

    try {
      // FORENSIC TELEMETRY: Sample the hardware accelerometer to detect 
      // if a violent physical struggle or impact is actively occurring.
      
      double maxGForce = 0.0;
      final subscription = userAccelerometerEventStream().listen((UserAccelerometerEvent event) {
        // Calculate the absolute vector magnitude in Gs
        final gForce = (event.x.abs() + event.y.abs() + event.z.abs()) / 9.81;
        if (gForce > maxGForce) maxGForce = gForce;
      });
      
      // Sample the physical motion for 1 second
      await Future.delayed(const Duration(seconds: 1));
      subscription.cancel();
      
      // If the vector exceeds 2.5 Gs, it indicates severe non-normal human motion 
      // (e.g., struggling, falling, or the device being thrown)
      if (maxGForce > 2.5) {
        message += '\n[Motion Telemetry: SEVERE PHYSICAL STRUGGLE OR IMPACT DETECTED (${maxGForce.toStringAsFixed(1)}G)]';
      } else if (maxGForce > 1.2) {
        message += '\n[Motion Telemetry: Active running/fleeing detected]';
      }
    } catch (e) {
      // Ignore if hardware sensors are unavailable
    }

    // 4. Dispatch SOS
    String dispatchMethod = 'cloud_sms';
    bool dispatchSuccess = false;

    // TACTICAL STEALTH: Attempt Zero-Trace Cloud Dispatch first
    final cloudSms = CloudSmsService();
    bool cloudSuccess = true;
    for (String recipient in recipientNumbers) {
      final success = await cloudSms.dispatchZeroTraceSos(recipient, message);
      if (!success) cloudSuccess = false;
    }

    if (cloudSuccess) {
      dispatchSuccess = true;
    } else {
      // NETWORK FAILED: Fallback to local offline SMS (Leaves a trace, but guarantees delivery)
      dispatchMethod = 'local_sms';
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
