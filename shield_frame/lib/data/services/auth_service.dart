import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'biometric_service.dart';

enum AuthStatus {
  authenticatedReal,
  authenticatedDuress,
  failed,
}

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

  AuthService({
    FlutterSecureStorage? secureStorage,
    BiometricService? biometricService,
  })  : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
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

  /// Verifies entered PIN against stored Real and Duress PINs
  Future<AuthStatus> verifyPin(String enteredPin) async {
    final real = await getRealPin();
    final duress = await getDuressPin();

    if (enteredPin == real) {
      return AuthStatus.authenticatedReal;
    } else if (enteredPin == duress) {
      return AuthStatus.authenticatedDuress;
    } else {
      return AuthStatus.failed;
    }
  }

  /// Verifies biometrics. Biometrics always authenticates into the Real Vault
  Future<AuthStatus> authenticateBiometric() async {
    final success = await _biometricService.authenticate();
    if (success) {
      return AuthStatus.authenticatedReal;
    }
    return AuthStatus.failed;
  }
}
