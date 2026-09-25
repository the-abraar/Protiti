import 'package:flutter_test/flutter_test.dart';
import 'package:protiti/data/services/encryption_service.dart';

void main() {
  group('EncryptionService Tests', () {
    late EncryptionService encryptionService;

    setUp(() {
      encryptionService = EncryptionService();
    });

    test('Plaintext is properly encrypted and decrypted', () async {
      const originalText = 'Highly sensitive cyber tribunal evidence.';
      
      final encryptedText = await encryptionService.encrypt(originalText);
      expect(encryptedText, isNot(originalText));
      expect(encryptedText.contains(':'), isTrue); // Ensures IV is appended
      
      final decryptedText = await encryptionService.decrypt(encryptedText);
      expect(decryptedText, originalText);
    });
    
    test('Old plaintext fallback is handled gracefully', () async {
      const oldText = 'legacy_plaintext_evidence';
      final decryptedText = await encryptionService.decrypt(oldText);
      expect(decryptedText, oldText); // Should return itself if no IV delimiter is found
    });
  });
}
