import 'package:flutter_test/flutter_test.dart';
import 'package:protiti/data/services/auth_service.dart';
import 'package:protiti/data/services/secure_store.dart';

import 'helpers/fakes.dart';

/// A monotonic clock the test moves by hand.
class FakeStopwatch implements Stopwatch {
  Duration now = Duration.zero;
  @override
  Duration get elapsed => now;
  @override
  void reset() => now = Duration.zero;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final storage = FakeSecureStorage();
  late FakeStopwatch clock;
  late AuthService auth;

  setUp(() {
    storage
      ..store.clear()
      ..failing = false
      ..install();
    clock = FakeStopwatch();
    auth = AuthService(failureClock: clock);
  });
  tearDown(storage.uninstall);

  Future<void> setUpCodes() =>
      auth.setPins(realPin: '246813', duressPin: '135792', wipeCode: '975310');

  test('no PIN works before setup, including the old defaults', () async {
    expect(await auth.isSetupComplete(), isFalse);
    for (final pin in ['1234', '9999', '0000']) {
      expect(await auth.verifyPin(pin), AuthStatus.failed);
    }
  });

  test(
    'codes must be 6-10 digits, all different, and the wipe code not all zeros',
    () {
      expect(AuthService.validatePins('1234', '135792', '975310'), isNotNull);
      expect(AuthService.validatePins('246813', '246813', '975310'), isNotNull);
      expect(AuthService.validatePins('246813', '135792', '246813'), isNotNull);
      expect(AuthService.validatePins('246813', '135792', '000000'), isNotNull);
      expect(
        AuthService.validatePins('246813', '135792', '12345678901'),
        isNotNull,
      );
      expect(AuthService.validatePins('246813', '135792', '975310'), isNull);
      expect(
        () =>
            auth.setPins(realPin: '2468', duressPin: '1357', wipeCode: '9753'),
        throwsArgumentError,
      );
    },
  );

  test(
    'the chosen codes open real, second and wipe; nothing else does',
    () async {
      await setUpCodes();
      expect(await auth.verifyPin('246813'), AuthStatus.authenticatedReal);
      expect(await auth.verifyPin('135792'), AuthStatus.authenticatedDuress);
      expect(await auth.verifyPin('975310'), AuthStatus.wiped);
      expect(await auth.verifyPin('0000'), AuthStatus.failed);
    },
  );

  test(
    'five misses lock out even the right PIN, across instances, until the delay passes',
    () async {
      await setUpCodes();
      for (var i = 0; i < 4; i++) {
        expect(await auth.verifyPin('111111'), AuthStatus.failed);
      }
      expect(await auth.verifyPin('111111'), AuthStatus.lockedOut);
      expect(await auth.verifyPin('246813'), AuthStatus.lockedOut);
      // A new instance (e.g. after a restart) still sees the persisted count.
      expect(
        await AuthService(failureClock: clock).verifyPin('246813'),
        AuthStatus.lockedOut,
      );
      expect(storage.store[StoreKeys.failedAttempts], '5');

      clock.now = const Duration(seconds: 31);
      expect(await auth.verifyPin('246813'), AuthStatus.authenticatedReal);
      expect(storage.store.containsKey(StoreKeys.failedAttempts), isFalse);
    },
  );

  test(
    'the second PIN never clears the miss counter, so guesses still lock out (N1)',
    () async {
      await setUpCodes();
      var lockouts = 0;
      for (var i = 0; i < 40; i++) {
        if (await auth.verifyPin('${111111 + i}') == AuthStatus.lockedOut) {
          lockouts++;
        }
        if (i % 4 == 3) {
          expect(
            await auth.verifyPin('135792'),
            AuthStatus.authenticatedDuress,
          );
        }
      }
      expect(lockouts, greaterThan(30));
      expect(
        storage.store[StoreKeys.failedAttempts],
        '5',
        reason: 'misses during a lockout are not tried',
      );
      expect(await auth.verifyPin('246813'), AuthStatus.lockedOut);
    },
  );

  test(
    'during a lockout the second PIN and the wipe code still work; the real PIN waits (N5)',
    () async {
      await setUpCodes();
      for (var i = 0; i < 5; i++) {
        await auth.verifyPin('111111');
      }
      expect(await auth.verifyPin('246813'), AuthStatus.lockedOut);
      expect(await auth.verifyPin('135792'), AuthStatus.authenticatedDuress);
      expect(
        await auth.verifyPin('246813'),
        AuthStatus.lockedOut,
        reason: 'the second PIN did not lift it',
      );
      expect(await auth.verifyPin('975310'), AuthStatus.wiped);
    },
  );

  test('parallel guesses are each counted (N7)', () async {
    await setUpCodes();
    final results = await Future.wait([
      for (var i = 0; i < 12; i++) auth.verifyPin('111111'),
    ]);
    expect(storage.store[StoreKeys.failedAttempts], '5');
    expect(results.where((r) => r == AuthStatus.lockedOut), hasLength(8));
  });

  test('no slip can turn one code into another (N6)', () {
    const real = '123456';
    for (final close in [
      '123457', // one key wrong
      '1234567', // one key extra
      '124356', // two neighbours swapped
      '1234990', // same first 4 digits
      '023456', // one key wrong at the start
      '1123456', // first key doubled
    ]) {
      expect(
        AuthService.validatePins(real, '864209', close),
        isNotNull,
        reason: 'wipe $close',
      );
      expect(
        AuthService.validatePins(real, close, '864209'),
        isNotNull,
        reason: 'second $close',
      );
    }
    expect(
      AuthService.validatePins(real, real, '864209'),
      isNotNull,
      reason: 'second equals real',
    );
    expect(
      AuthService.validatePins(real, '864209', '864219'),
      isNotNull,
      reason: 'wipe one off the second',
    );
    expect(AuthService.validatePins(real, '864209', '975310'), isNull);
  });

  test('the wipe code is optional; without one, nothing wipes', () async {
    expect(AuthService.validatePins('246813', '135792', ''), isNull);
    await auth.setPins(
      realPin: '246813',
      duressPin: '135792',
      wipeCode: '975310',
    );
    await auth.setPins(realPin: '246813', duressPin: '135792', wipeCode: '');
    expect(storage.store.containsKey(StoreKeys.wipeCode), isFalse);
    expect(await auth.verifyPin('975310'), AuthStatus.failed);
    expect(await auth.verifyPin('246813'), AuthStatus.authenticatedReal);
  });

  test('each further miss waits longer', () {
    expect(AuthService.lockoutDelay(4), Duration.zero);
    expect(AuthService.lockoutDelay(5), const Duration(seconds: 30));
    expect(AuthService.lockoutDelay(6), const Duration(minutes: 1));
    expect(AuthService.lockoutDelay(8), const Duration(minutes: 15));
    expect(AuthService.lockoutDelay(50), const Duration(hours: 1));
  });

  test('changing codes needs the current real PIN', () async {
    await setUpCodes();
    expect(
      await auth.changePins(
        currentPin: '135792',
        realPin: '111222',
        duressPin: '333444',
        wipeCode: '555666',
      ),
      isFalse,
    );
    expect(
      await auth.changePins(
        currentPin: '246813',
        realPin: '111222',
        duressPin: '333444',
        wipeCode: '555666',
      ),
      isTrue,
    );
    expect(await auth.verifyPin('111222'), AuthStatus.authenticatedReal);
    expect(await auth.verifyPin('246813'), AuthStatus.failed);
  });

  test(
    'Bangla digits ০-৯ are the same code as 0-9, everywhere a code is typed',
    () async {
      expect(AuthService.asciiDigits('০১২৩৪৫৬৭৮৯'), '0123456789');
      expect(
        AuthService.validatePins('২৪৬৮১৩', '246813', '975310'),
        'All the codes must be different.',
      );
      await auth.setPins(
        realPin: '২৪৬৮১৩',
        duressPin: '135792',
        wipeCode: '৯৭৫৩১০',
      );
      expect(await auth.verifyPin('246813'), AuthStatus.authenticatedReal);
      expect(await auth.verifyPin('১৩৫৭৯২'), AuthStatus.authenticatedDuress);
      expect(await auth.verifyPin('975310'), AuthStatus.wiped);
      expect(
        await auth.changePins(
          currentPin: '২৪৬৮১৩',
          realPin: '111222',
          duressPin: '333444',
          wipeCode: '555666',
        ),
        isTrue,
      );
    },
  );

  test('a broken keystore fails closed: nothing is kept in memory', () async {
    storage.failing = true;
    await expectLater(setUpCodes(), throwsA(anything));
    storage.failing = false;
    expect(await auth.isSetupComplete(), isFalse);
  });
}
