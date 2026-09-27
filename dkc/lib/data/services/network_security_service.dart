import 'package:http_certificate_pinning/http_certificate_pinning.dart';

class NetworkSecurityService {
  /// Validates the SSL certificates of our critical endpoints against hardcoded SHA-256 fingerprints.
  /// If this fails, the local network is actively compromised by a Man-in-the-Middle attack.
  static Future<bool> isNetworkSecure() async {
    try {
      // Pinning the Twilio API endpoint (and you should do this for the Cloud Backup too)
      final secureConnection = await HttpCertificatePinning.check(
        serverURL: 'https://api.twilio.com',
        headerHttp: {},
        sha: SHA.SHA256,
        // Replace with the actual real-time SHA-256 fingerprint for Twilio's SSL cert
        allowedSHAFingerprints: ['82:13:95:25:A8:12:00:23:44...'], 
        timeout: 50,
      );
      
      return secureConnection.contains('CONNECTION_SECURE');
    } catch (e) {
      // Certificate rejected! The network is being wiretapped.
      return false;
    }
  }
}
