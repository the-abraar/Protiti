import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'biometric_service.dart';
import 'secure_store.dart';

enum AuthStatus { authenticatedReal, authenticatedDuress, wiped, failed, lockedOut }

class AuthService {
  final FlutterSecureStorage _secureStorage;
  final BiometricService _biometricService;
  final Stopwatch _sinceLastFailure;

  /// Monotonic, so changing the device clock cannot shorten a lockout. After a
  /// restart it starts at zero, which only makes a guesser wait the full delay again.
  static final Stopwatch _sharedClock = Stopwatch()..start();

  AuthService({
    FlutterSecureStorage? secureStorage,
    BiometricService? biometricService,
    Stopwatch? failureClock,
  }) : _secureStorage = secureStorage ?? secureStore,
       _biometricService = biometricService ?? BiometricService(),
       _sinceLastFailure = failureClock ?? _sharedClock;

  // Storage errors propagate on purpose (fail closed): a PIN kept only in
  // memory would silently vanish at the next restart.
  Future<String?> _read(String key) => _secureStorage.read(key: key);
  Future<void> _write(String key, String value) => _secureStorage.write(key: key, value: value);
  Future<void> _delete(String key) => _secureStorage.delete(key: key);

  /// Stored as `salt:sha256(salt+pin)`. shortcut: a single SHA-256 round is
  /// brute-forceable offline if secure storage is extracted; upgrade to a slow KDF (PBKDF2/Argon2).
  String _hash(String pin, [String? salt]) {
    salt ??= base64UrlEncode(List<int>.generate(16, (_) => Random.secure().nextInt(256)));
    return '$salt:${sha256.convert(utf8.encode('$salt$pin')).toString()}';
  }

  bool _matches(String? stored, String pin) =>
      stored != null && stored.contains(':') && _hash(pin, stored.split(':').first) == stored;

  /// False until the user has chosen their own PINs; no PIN is valid before that.
  /// The wipe code is optional here so installs from before it existed keep working.
  Future<bool> isSetupComplete() async =>
      await _read(StoreKeys.realPin) != null && await _read(StoreKeys.duressPin) != null;

  static final _codeFormat = RegExp(r'^\d{6,10}$');

  /// Bangla digits ০-৯ count as 0-9, so a code typed on a Bangla keyboard is the same code.
  static String asciiDigits(String code) =>
      code.replaceAllMapped(RegExp('[০-৯]'), (m) => '${m[0]!.codeUnitAt(0) - 0x09E6}');

  /// Returns an error message, or null if the three codes are acceptable.
  /// 10 digits is the most the calculator display can hold.
  static String? validatePins(String realPin, String duressPin, String wipeCode) {
    final codes = [realPin, duressPin, wipeCode].map(asciiDigits).toList();
    if (!codes.every(_codeFormat.hasMatch)) return 'Each code must be 6 to 10 digits.';
    if (codes.toSet().length < 3) return 'All three codes must be different.';
    if (RegExp(r'^0+$').hasMatch(codes[2])) return 'The wipe code cannot be all zeros.';
    return null;
  }

  Future<void> setPins({
    required String realPin,
    required String duressPin,
    required String wipeCode,
  }) async {
    final err = validatePins(realPin, duressPin, wipeCode);
    if (err != null) throw ArgumentError(err);
    await _write(StoreKeys.realPin, _hash(asciiDigits(realPin)));
    await _write(StoreKeys.duressPin, _hash(asciiDigits(duressPin)));
    await _write(StoreKeys.wipeCode, _hash(asciiDigits(wipeCode)));
  }

  /// Replaces all three codes, but only for someone who knows the current real PIN.
  Future<bool> changePins({
    required String currentPin,
    required String realPin,
    required String duressPin,
    required String wipeCode,
  }) async {
    if (!_matches(await _read(StoreKeys.realPin), asciiDigits(currentPin))) return false;
    await setPins(realPin: realPin, duressPin: duressPin, wipeCode: wipeCode);
    return true;
  }

  /// No delay for the first four misses, then 30 s, 1, 5, 15 and 60 minutes.
  static Duration lockoutDelay(int failures) {
    const steps = [
      Duration(seconds: 30),
      Duration(minutes: 1),
      Duration(minutes: 5),
      Duration(minutes: 15),
      Duration(hours: 1),
    ];
    if (failures < 5) return Duration.zero;
    return steps[min(failures - 5, steps.length - 1)];
  }

  Future<int> _failures() async => int.tryParse(await _read(StoreKeys.failedAttempts) ?? '') ?? 0;

  /// The only way to check a code. Every miss is counted, in every mode.
  Future<AuthStatus> verifyPin(String enteredPin) async {
    enteredPin = asciiDigits(enteredPin);
    final failures = await _failures();
    if (_sinceLastFailure.elapsed < lockoutDelay(failures)) return AuthStatus.lockedOut;
    if (!await isSetupComplete()) return AuthStatus.failed;

    final AuthStatus match;
    if (_matches(await _read(StoreKeys.realPin), enteredPin)) {
      match = AuthStatus.authenticatedReal;
    } else if (_matches(await _read(StoreKeys.duressPin), enteredPin)) {
      match = AuthStatus.authenticatedDuress;
    } else if (_matches(await _read(StoreKeys.wipeCode), enteredPin)) {
      match = AuthStatus.wiped;
    } else {
      await _write(StoreKeys.failedAttempts, '${failures + 1}');
      _sinceLastFailure.reset();
      return lockoutDelay(failures + 1) > Duration.zero ? AuthStatus.lockedOut : AuthStatus.failed;
    }
    await _delete(StoreKeys.failedAttempts);
    return match;
  }

  /// Off by default: anyone who can force her finger onto the sensor gets in.
  Future<bool> isBiometricEnabled() async => await _read(StoreKeys.biometricOptIn) == 'true';

  /// Turning it on asks for a fingerprint or face first, so it only sticks if it works.
  Future<bool> setBiometricEnabled(bool enabled) async {
    if (!enabled) {
      await _delete(StoreKeys.biometricOptIn);
      return true;
    }
    if (!await _biometricService.authenticate()) return false;
    await _write(StoreKeys.biometricOptIn, 'true');
    return true;
  }

  Future<AuthStatus> authenticateBiometric() async {
    if (!await isBiometricEnabled()) return AuthStatus.failed;
    return await _biometricService.authenticate() ? AuthStatus.authenticatedReal : AuthStatus.failed;
  }
}
