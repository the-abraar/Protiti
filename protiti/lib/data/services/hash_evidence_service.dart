import 'dart:io';
import 'package:crypto/crypto.dart';

class HashEvidenceService {
  /// Generates a SHA-256 cryptographic hash of the encrypted evidence blob.
  /// This proves to law enforcement that the file has not been tampered with
  /// since the exact second it was captured and encrypted by Protiti.
  static Future<String> generateFileHash(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) return 'NO_FILE';
    
    final bytes = await file.readAsBytes();
    final digest = sha256.convert(bytes);
    
    return digest.toString();
  }
}
