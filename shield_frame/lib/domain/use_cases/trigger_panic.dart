import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/services/location_service.dart';
import '../../data/repositories/contact_repository.dart';

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

  TriggerPanicUseCase(
    this.locationService, {
    this.contactRepository,
  });

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
        locationStr = 'https://maps.google.com/?q=${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)} (${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)})';
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
        recipientNumbers = contacts.map((c) => c.phone).where((p) => p.isNotEmpty).toList();
      } catch (_) {}
    }

    // Default recipient fallback if no personal contact configured
    if (recipientNumbers.isEmpty) {
      recipientNumbers = ['999', '109'];
    }

    // 3. Construct High-Priority SMS Payload
    final message = 'EMERGENCY SOS [Protiti]: I need urgent help! My location: $locationStr at ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')} (BD Time). Please send assistance immediately.';

    // 4. Dispatch via SMS URI Scheme (operates on 2G/GSM control channel, zero mobile data required)
    String dispatchMethod = 'sms';
    bool dispatchSuccess = false;

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
        await SharePlus.instance.share(ShareParams(text: message, subject: 'EMERGENCY SOS [Protiti]'));
        dispatchSuccess = true;
        dispatchMethod = 'share_fallback';
      }
    } catch (_) {
      // Last-resort fallback to SharePlus
      try {
        await SharePlus.instance.share(ShareParams(text: message, subject: 'EMERGENCY SOS [Protiti]'));
        dispatchSuccess = true;
        dispatchMethod = 'share_fallback';
      } catch (_) {
        dispatchSuccess = false;
        dispatchMethod = 'failed';
      }
    }

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
}
