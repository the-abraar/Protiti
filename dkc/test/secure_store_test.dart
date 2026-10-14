import 'package:flutter_test/flutter_test.dart';
import 'package:protiti/data/services/secure_store.dart';

import 'helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final storage = FakeSecureStorage();

  setUp(() {
    storage
      ..store.clear()
      ..install();
  });
  tearDown(storage.uninstall);

  test('old revealing key names move to neutral ones, once', () async {
    storage.store.addAll({
      'protiti_real_pin': 'salt:real',
      'protiti_duress_pin': 'salt:duress',
      'protiti_aes_key': 'aes',
      'decoy_draft_title': 'notes',
      'pin_lockout_expiry': '2026-01-01',
      'always_launch_as_calculator': 'true',
      'p1': 'true',
    });
    await migrateStoreKeys();
    await migrateStoreKeys();

    expect(storage.store, {
      StoreKeys.realPin: 'salt:real',
      StoreKeys.duressPin: 'salt:duress',
      StoreKeys.evidenceKey: 'aes',
      StoreKeys.notesDraftTitle: 'notes',
    });
    for (final key in storage.store.keys) {
      expect(key, isNot(matches(RegExp('pin|duress|decoy|protiti|vault', caseSensitive: false))));
    }
  });

  test('a value already under the new name wins', () async {
    storage.store.addAll({'protiti_real_pin': 'old', StoreKeys.realPin: 'new'});
    await migrateStoreKeys();
    expect(storage.store, {StoreKeys.realPin: 'new'});
  });
}
