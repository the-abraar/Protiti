import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The one secure store the app uses. "This device only" Keychain items are
/// left out of iCloud and iTunes backups and never move to another phone.
const secureStore = FlutterSecureStorage(
  iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
);

/// Secure-storage key names. They are deliberately meaningless: with backup
/// or forensic access, a name like "duress_pin" alone reveals the scheme.
abstract final class StoreKeys {
  static const realPin = 'u1';
  static const duressPin = 'u2';
  static const wipeCode = 'u3';
  static const failedAttempts = 'u4';
  static const biometricOptIn = 'u5';
  static const evidenceKey = 'k3';
  // SOS (pro-sos). p2 used to switch both triggers; it now means the power button only.
  static const powerSosOn = 'p2';
  static const shakeSosOn = 's1';
  static const duressAlertOn = 's2';
  static const lastAlert = 's3';
  static const draftTitle = 'd1';
  static const draftDescription = 'd2';
  static const draftStation = 'd3';
  static const notesDraftTitle = 'd4';
  static const notesDraftBody = 'd5';
}

/// Old revealing name -> new neutral name (null: no longer used, just delete).
const legacyStoreKeys = <String, String?>{
  'protiti_real_pin': StoreKeys.realPin,
  'protiti_duress_pin': StoreKeys.duressPin,
  'pin_failed_attempts': StoreKeys.failedAttempts,
  'protiti_aes_key': StoreKeys.evidenceKey,
  // The calculator is now the only mode, so its old switch is just deleted.
  'always_launch_as_calculator': null,
  'p1': null,
  'gd_draft_title': StoreKeys.draftTitle,
  'gd_draft_desc': StoreKeys.draftDescription,
  'gd_draft_station': StoreKeys.draftStation,
  'decoy_draft_title': StoreKeys.notesDraftTitle,
  'decoy_draft_desc': StoreKeys.notesDraftBody,
  'pin_lockout_expiry': null,
  'require_pin_next_time': null,
  'biometric_mode': null,
};

/// Moves values from the old key names once; later runs find nothing to move.
Future<void> migrateStoreKeys([FlutterSecureStorage store = secureStore]) async {
  for (final entry in legacyStoreKeys.entries) {
    final value = await store.read(key: entry.key);
    if (value == null) continue;
    final target = entry.value;
    if (target != null && await store.read(key: target) == null) {
      await store.write(key: target, value: value);
    }
    await store.delete(key: entry.key);
  }
}
