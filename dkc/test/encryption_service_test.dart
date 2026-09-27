import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protiti/data/services/encryption_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EncryptionService Tests', () {
    late EncryptionService encryptionService;
    const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    final store = <String, String>{};

    setUp(() {
      store.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        switch (call.method) {
          case 'read':
            return store[call.arguments['key']];
          case 'write':
            store[call.arguments['key']] = call.arguments['value'];
            return null;
          case 'delete':
            store.remove(call.arguments['key']);
            return null;
          case 'deleteAll':
            store.clear();
            return null;
          case 'readAll':
            return store;
          case 'containsKey':
            return store.containsKey(call.arguments['key']);
          default:
            return null;
        }
      });
      encryptionService = EncryptionService();
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
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
