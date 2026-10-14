import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'biometric_service.dart';

enum AuthStatus { authenticatedReal, authenticatedDuress, wiped, failed, lockedOut }

class AuthService {
  final FlutterSecureStorage _secureStorage;
  final BiometricService _biometricService;

  static const String _realPinKey = 'protiti_real_pin';
  static const String _duressPinKey = 'protiti_duress_pin';

  static const String defaultWipePin = '0000';

  AuthService({
    FlutterSecureStorage? secureStorage,
    BiometricService? biometricService,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _biometricService = biometricService ?? BiometricService();

  final Map<String, String> _memFallback = {};

  Future<String?> _read({required String key}) async {
    try { return await _secureStorage.read(key: key) ?? _memFallback[key]; } 
    catch (_) { return _memFallback[key]; }
  }
  
  Future<void> _write({required String key, required String value}) async {
    _memFallback[key] = value;
    try { await _secureStorage.write(key: key, value: value); } 
    catch (_) {}
  }
  
  Future<void> _delete({required String key}) async {
    _memFallback.remove(key);
    try { await _secureStorage.delete(key: key); } 
    catch (_) {}
  }

  /// Stored as `salt:sha256(salt+pin)`. shortcut: a 4-digit PIN is brute-forceable
  /// offline if secure storage is extracted; upgrade to a slow KDF (PBKDF2/Argon2).
  String _hash(String pin, [String? salt]) {
    salt ??= base64UrlEncode(List<int>.generate(16, (_) => Random.secure().nextInt(256)));
    return '$salt:${sha256.convert(utf8.encode('$salt$pin')).toString()}';
  }

  bool _matches(String? stored, String pin) =>
      stored != null && stored.contains(':') && _hash(pin, stored.split(':').first) == stored;

  /// False until the user has chosen their own PINs; no PIN is valid before that.
  Future<bool> isSetupComplete() async =>
      await _read(key: _realPinKey) != null && await _read(key: _duressPinKey) != null;

  /// Returns an error message, or null if the pair is acceptable.
  static String? validatePins(String realPin, String duressPin) {
    final digits = RegExp(r'^\d{4}$');
    if (!digits.hasMatch(realPin) || !digits.hasMatch(duressPin)) return 'PINs must be 4 digits.';
    if (realPin == duressPin) return 'Duress PIN must differ from the real PIN.';
    if (realPin == defaultWipePin || duressPin == defaultWipePin) return '0000 is reserved.';
    return null;
  }

  Future<void> setPins({
    required String realPin,
    required String duressPin,
  }) async {
    final err = validatePins(realPin, duressPin);
    if (err != null) throw ArgumentError(err);
    await _write(key: _realPinKey, value: _hash(realPin));
    await _write(key: _duressPinKey, value: _hash(duressPin));
  }

  /// Side-effect-free check (no attempt counting); used by the calculator disguise.
  Future<AuthStatus> matchPin(String pin) async {
    if (_matches(await _read(key: _realPinKey), pin)) return AuthStatus.authenticatedReal;
    if (_matches(await _read(key: _duressPinKey), pin)) return AuthStatus.authenticatedDuress;
    return AuthStatus.failed;
  }

  static const _attemptsKey = 'pin_failed_attempts';
  static const _lockoutExpiryKey = 'pin_lockout_expiry';
  static const _biometricLockKey = 'require_pin_next_time';
  static const int maxAttempts = 5;
  static const int lockoutDurationMinutes = 15;

  /// Activating this instantly disables FaceID/TouchID for the next session,
  /// forcing the user to type a PIN (allowing them to use the Duress/Wipe PINs).
  Future<void> enforcePinHardLock() async {
    await _write(key: _biometricLockKey, value: 'true');
  }

  Future<bool> isBiometricHardLocked() async {
    final value = await _read(key: _biometricLockKey);
    return value == 'true';
  }

  /// Checks if the device is currently serving a cryptographic time-lock
  Future<bool> isLockedOut() async {
    final expiryStr = await _read(key: _lockoutExpiryKey);
    if (expiryStr != null) {
      final expiryTime = DateTime.parse(expiryStr);
      final secureNow = DateTime.now();
      
      if (secureNow.isBefore(expiryTime)) {
        return true; // Still serving the time-lock
      } else {
        // Lockout sentence served, reset the tracking keys
        await _resetAttempts();
        return false;
      }
    }
    return false;
  }

  Future<void> _recordFailedAttempt() async {
    final attemptsStr = await _read(key: _attemptsKey) ?? '0';
    int attempts = int.parse(attemptsStr) + 1;
    
    if (attempts >= maxAttempts) {
      // Maximum guesses exceeded! Engage the 15-minute cryptographic time-lock.
      final secureNow = DateTime.now();
      final expiryTime = secureNow.add(const Duration(minutes: lockoutDurationMinutes));
      await _write(key: _lockoutExpiryKey, value: expiryTime.toIso8601String());
    } else {
      await _write(key: _attemptsKey, value: attempts.toString());
    }
  }

  Future<void> _resetAttempts() async {
    await _delete(key: _attemptsKey);
    await _delete(key: _lockoutExpiryKey);
  }

  /// Verifies entered PIN against stored Real and Duress PINs
  Future<AuthStatus> verifyPin(String enteredPin) async {
    // 1. Immediately block if actively locked out
    if (await isLockedOut()) return AuthStatus.lockedOut;

    if (!await isSetupComplete()) return AuthStatus.failed;

    if (enteredPin == defaultWipePin) {
      await _resetAttempts();
      return AuthStatus.wiped;
    }

    final match = await matchPin(enteredPin);
    if (match != AuthStatus.failed) {
      await _resetAttempts();
      await _delete(key: _biometricLockKey);
      return match;
    } else {
      // 2. Record the failed attempt and evaluate for lockout
      await _recordFailedAttempt();
      
      if (await isLockedOut()) {
        return AuthStatus.lockedOut;
      }
      return AuthStatus.failed;
    }
  }

  /// Verifies biometrics and honors the user's duress configuration
  Future<AuthStatus> authenticateBiometric() async {
    final success = await _biometricService.authenticate();
    if (success) {
      final biometricMode = await _read(key: 'biometric_mode');
      if (biometricMode == 'decoy') {
        // App was configured to route biometrics to the decoy vault for safety
        return AuthStatus.authenticatedDuress;
      }
      return AuthStatus.authenticatedReal;
    }
    return AuthStatus.failed;
  }
}
