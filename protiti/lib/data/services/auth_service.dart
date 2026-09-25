import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'biometric_service.dart';
import 'time_service.dart';

enum AuthStatus { authenticatedReal, authenticatedDuress, wiped, failed, lockedOut }

class AuthService {
  final FlutterSecureStorage _secureStorage;
  final BiometricService _biometricService;

  static const String _realPinKey = 'protiti_real_pin';
  static const String _duressPinKey = 'protiti_duress_pin';

  // Default demonstration PINs:
  // Real PIN: '1234' -> Displays confidential forensic vault
  // Duress PIN: '9999' -> Displays innocent decoy vault under coercive duress
  static const String defaultRealPin = '1234';
  static const String defaultDuressPin = '9999';
  static const String defaultWipePin = '0000';

  AuthService({
    FlutterSecureStorage? secureStorage,
    BiometricService? biometricService,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _biometricService = biometricService ?? BiometricService();

  Future<String> getRealPin() async {
    final pin = await _secureStorage.read(key: _realPinKey);
    return pin ?? defaultRealPin;
  }

  Future<String> getDuressPin() async {
    final pin = await _secureStorage.read(key: _duressPinKey);
    return pin ?? defaultDuressPin;
  }

  Future<void> setPins({
    required String realPin,
    required String duressPin,
  }) async {
    await _secureStorage.write(key: _realPinKey, value: realPin);
    await _secureStorage.write(key: _duressPinKey, value: duressPin);
  }

  static const _attemptsKey = 'pin_failed_attempts';
  static const _lockoutExpiryKey = 'pin_lockout_expiry';
  static const _biometricLockKey = 'require_pin_next_time';
  static const int maxAttempts = 5;
  static const int lockoutDurationMinutes = 15;

  /// Activating this instantly disables FaceID/TouchID for the next session,
  /// forcing the user to type a PIN (allowing them to use the Duress/Wipe PINs).
  Future<void> enforcePinHardLock() async {
    await _secureStorage.write(key: _biometricLockKey, value: 'true');
  }

  Future<bool> isBiometricHardLocked() async {
    final value = await _secureStorage.read(key: _biometricLockKey);
    return value == 'true';
  }

  /// Checks if the device is currently serving a cryptographic time-lock
  Future<bool> isLockedOut() async {
    final expiryStr = await _secureStorage.read(key: _lockoutExpiryKey);
    if (expiryStr != null) {
      final expiryTime = DateTime.parse(expiryStr);
      final secureNow = await SecureTimeService.getSecureTime();
      
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
    final attemptsStr = await _secureStorage.read(key: _attemptsKey) ?? '0';
    int attempts = int.parse(attemptsStr) + 1;
    
    if (attempts >= maxAttempts) {
      // Maximum guesses exceeded! Engage the 15-minute cryptographic time-lock.
      final secureNow = await SecureTimeService.getSecureTime();
      final expiryTime = secureNow.add(const Duration(minutes: lockoutDurationMinutes));
      await _secureStorage.write(key: _lockoutExpiryKey, value: expiryTime.toIso8601String());
    } else {
      await _secureStorage.write(key: _attemptsKey, value: attempts.toString());
    }
  }

  Future<void> _resetAttempts() async {
    await _secureStorage.delete(key: _attemptsKey);
    await _secureStorage.delete(key: _lockoutExpiryKey);
  }

  /// Verifies entered PIN against stored Real and Duress PINs
  Future<AuthStatus> verifyPin(String enteredPin) async {
    // 1. Immediately block if actively locked out
    if (await isLockedOut()) return AuthStatus.lockedOut;

    final real = await getRealPin();
    final duress = await getDuressPin();

    if (enteredPin == defaultWipePin) {
      await _resetAttempts();
      return AuthStatus.wiped;
    }

    if (enteredPin == real) {
      await _resetAttempts();
      await _secureStorage.delete(key: _biometricLockKey);
      return AuthStatus.authenticatedReal;
    } else if (enteredPin == duress) {
      await _resetAttempts();
      await _secureStorage.delete(key: _biometricLockKey);
      return AuthStatus.authenticatedDuress;
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
      final biometricMode = await _secureStorage.read(key: 'biometric_mode');
      if (biometricMode == 'decoy') {
        // App was configured to route biometrics to the decoy vault for safety
        return AuthStatus.authenticatedDuress;
      }
      return AuthStatus.authenticatedReal;
    }
    return AuthStatus.failed;
  }
}
