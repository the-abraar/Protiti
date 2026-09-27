import 'package:encrypt/encrypt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'dart:math';

class EncryptionService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const String _keyKey = 'protiti_aes_key';

  Future<Key> _getKey() async {
    String? base64Key = await _storage.read(key: _keyKey);
    if (base64Key == null) {
      final secureRandom = Random.secure();
      final keyBytes = List<int>.generate(32, (_) => secureRandom.nextInt(256));
      base64Key = base64UrlEncode(keyBytes);
      await _storage.write(key: _keyKey, value: base64Key);
    }
    return Key.fromBase64(base64Key);
  }

  Future<String> encrypt(String plainText) async {
    final key = await _getKey();
    final iv = IV.fromSecureRandom(16);
    final encrypter = Encrypter(AES(key));
    
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    return '${iv.base64}:${encrypted.base64}';
  }

  Future<String> decrypt(String cipherText) async {
    final parts = cipherText.split(':');
    if (parts.length != 2) return cipherText; // Fallback for old plaintext evidence

    final key = await _getKey();
    final iv = IV.fromBase64(parts[0]);
    final encrypter = Encrypter(AES(key));
    
    final encrypted = Encrypted.fromBase64(parts[1]);
    return encrypter.decrypt(encrypted, iv: iv);
  }
}
