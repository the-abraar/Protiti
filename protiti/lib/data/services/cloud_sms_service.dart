import 'dart:convert';
import 'package:http/http.dart' as http;
import 'network_security_service.dart';

class CloudSmsService {
  // TODO: Securely inject these via FlutterSecureStorage or a backend proxy later
  final String accountSid = 'DKC_TWILIO_SID';
  final String authToken = 'DKC_TWILIO_TOKEN';
  final String virtualNumber = '+1234567890'; // Your dedicated SOS Virtual Number

  /// Dispatches the SOS via an external cloud gateway.
  /// This guarantees that absolutely zero trace of the outgoing message 
  /// will ever appear in the victim's local "Sent" SMS folder.
  Future<bool> dispatchZeroTraceSos(String recipient, String payload) async {
    try {
      // 1. TACTICAL NETWORK AUDIT: Ensure the abuser isn't wiretapping the HTTPS tunnel
      final isSecure = await NetworkSecurityService.isNetworkSecure();
      if (!isSecure) {
        // Network is compromised! Abort cloud transmission so the SOS payload isn't intercepted.
        // Returning false triggers your existing TriggerPanicUseCase offline SMS fallback!
        return false; 
      }

      final url = Uri.parse('https://api.twilio.com/2010-04-01/Accounts/$accountSid/Messages.json');
      
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Basic ${base64Encode(utf8.encode('$accountSid:$authToken'))}',
        },
        body: {
          'From': virtualNumber,
          'To': recipient,
          'Body': payload,
        },
      );
      
      return response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }
}
