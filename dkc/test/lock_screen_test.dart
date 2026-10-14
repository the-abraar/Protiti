import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protiti/data/services/auth_service.dart';
import 'package:protiti/data/services/biometric_service.dart';
import 'package:protiti/data/services/secure_store.dart';
import 'package:protiti/data/services/wipe_service.dart';
import 'package:protiti/main.dart';
import 'package:protiti/ui/features/auth/lock_screen.dart';
import 'package:protiti/ui/features/vault/vault_screen.dart';

import 'helpers/app_harness.dart';
import 'helpers/fakes.dart';

const _real = '246813';
const _duress = '135792';
const _wipe = '975310';

/// Always says yes, and counts how often it was asked.
class _FakeBiometric extends BiometricService {
  int calls = 0;
  @override
  Future<bool> authenticate() async {
    calls++;
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final storage = FakeSecureStorage();
  late Directory root;

  setUp(() async {
    storage
      ..store.clear()
      ..failing = false
      ..install();
    root = installTempPaths();
    await AuthService().setPins(realPin: _real, duressPin: _duress, wipeCode: _wipe);
  });
  tearDown(() {
    storage.uninstall();
    root.deleteSync(recursive: true);
  });

  Future<void> openCalculator(WidgetTester tester, {AuthService? auth}) async {
    await tester.pumpWidget(harness(LockScreen(authService: auth)));
    await tester.pumpAndSettle();
  }

  Future<void> calc(WidgetTester tester, String keys, {bool settle = true}) async {
    for (final k in keys.split('')) {
      await tester.tap(find.widgetWithText(ElevatedButton, k));
      await tester.pump();
    }
    // The vault's loading spinner never settles, so after an unlock just pump.
    settle ? await tester.pumpAndSettle() : await tester.pump(const Duration(seconds: 1));
  }

  String display(WidgetTester tester) =>
      tester.widget<Text>(find.byWidgetPredicate((w) => w is Text && w.style?.fontSize == 54)).data!;

  /// Real file I/O (the wipe, the wiped marker) only runs outside the fake clock.
  Future<void> letIoFinish(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
  }

  testWidgets('% and ± are calculator operations, not typed text', (tester) async {
    await openCalculator(tester);
    await calc(tester, '5%');
    expect(display(tester), '0.05');
    await calc(tester, 'C5±');
    expect(display(tester), '-5');
    await calc(tester, '±');
    expect(display(tester), '5');
  });

  testWidgets('it does real arithmetic: chaining, decimals, Error and clear', (tester) async {
    await openCalculator(tester);
    final cases = {
      '2+3+4=': '9',
      '2+3×4=': '20', // left to right, like a pocket calculator
      '9−4=': '5',
      '6÷4=': '1.5',
      '.5+.25=': '0.75',
      '1..2': '1.2',
      '0.1+0.2=': '0.3',
      '1÷3=': '0.333333333',
      '5+×2=': '10', // a second operator replaces the first
      '5÷0=': 'Error',
      '12+3C': '0',
    };
    for (final MapEntry(key: keys, value: shown) in cases.entries) {
      await calc(tester, 'C$keys');
      expect(display(tester), shown, reason: keys);
    }
    await calc(tester, 'C5÷0=±%+');
    expect(display(tester), 'Error', reason: 'only a new number leaves Error');
    await calc(tester, '7');
    expect(display(tester), '7');
    await calc(tester, 'C4=');
    expect(display(tester), '4', reason: 'clear drops the pending operation');
  });

  testWidgets('a wrong code on the calculator is counted but shows nothing', (tester) async {
    await openCalculator(tester);
    await calc(tester, '111111=');
    expect(storage.store[StoreKeys.failedAttempts], '1');
    expect(display(tester), '111111');
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('a short number and = is plain arithmetic, never a miss (N22)', (tester) async {
    await openCalculator(tester);
    await calc(tester, '2500=');
    expect(storage.store.containsKey(StoreKeys.failedAttempts), isFalse);
  });

  testWidgets('the calculator respects the lockout, then the real PIN works', (tester) async {
    await openCalculator(tester);
    for (var i = 0; i < 5; i++) {
      await calc(tester, 'C111111=');
    }
    await calc(tester, 'C$_real=');
    expect(find.byType(VaultScreen), findsNothing);
    expect(find.textContaining('attempts'), findsNothing, reason: 'silent while disguised');

    storage.store.remove(StoreKeys.failedAttempts);
    await calc(tester, 'C$_real=', settle: false);
    expect(find.byType(VaultScreen), findsOneWidget);
  });

  testWidgets('holding = asks for a fingerprint only if she turned it on', (tester) async {
    final biometric = _FakeBiometric();
    await openCalculator(tester, auth: AuthService(biometricService: biometric));
    await calc(tester, '12');
    await tester.longPress(find.widgetWithText(ElevatedButton, '='));
    await tester.pumpAndSettle();
    expect(biometric.calls, 0);
    expect(display(tester), '12', reason: 'an ordinary press');
    expect(find.byType(VaultScreen), findsNothing);

    storage.store[StoreKeys.biometricOptIn] = 'true';
    await tester.pumpWidget(const SizedBox());
    await openCalculator(tester, auth: AuthService(biometricService: biometric));
    await tester.longPress(find.widgetWithText(ElevatedButton, '='));
    await tester.pump(const Duration(seconds: 1));
    expect(biometric.calls, 1);
    expect(find.byType(VaultScreen), findsOneWidget);
  });

  testWidgets('the wipe code lands on a blank calculator, and it stays one after a restart', (tester) async {
    File('${root.path}/docs/photo.enc').writeAsStringSync('x');
    await openCalculator(tester);
    await calc(tester, '$_wipe=', settle: false);
    final photo = File('${root.path}/docs/photo.enc');
    // Done when the wipe has replaced the screen with a fresh calculator.
    for (var i = 0; i < 40 && display(tester) != '0'; i++) {
      await letIoFinish(tester);
    }

    expect(photo.existsSync(), isFalse);
    expect(storage.store, isEmpty);
    expect(await tester.runAsync(WipeService.hasWiped), isTrue);
    expect(display(tester), '0');
    expect(find.textContaining('Set up'), findsNothing);
    expect(find.byType(SnackBar), findsNothing);

    // A fresh start with no codes at all: still only a calculator, never setup.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(const ProtitiApp());
    await letIoFinish(tester);
    await letIoFinish(tester);
    expect(display(tester), '0');
    expect(find.textContaining('Set up'), findsNothing);
  });

  group('nothing in the calculator gives the app away', () {
    final giveaway = RegExp(
      r'protiti|vault|duress|decoy|evidence|wipe|disguise|stealth|sos|panic|lock'
      r'|প্রতীতি|ভল্ট|প্রমাণ|ছদ্মবেশ|জরুরি|জরুরী|নিরাপদ',
      caseSensitive: false,
    );

    for (final (locale, title) in [('en', 'Calculator'), ('bn', 'ক্যালকুলেটর')]) {
      testWidgets(locale, (tester) async {
        tester.platformDispatcher.localesTestValue = [Locale(locale)];
        addTearDown(tester.platformDispatcher.clearLocalesTestValue);
        await tester.pumpWidget(const ProtitiApp());
        await tester.pumpAndSettle();

        final strings = [
          for (final w in tester.allWidgets)
            if (w is RichText)
              w.text.toPlainText()
            else if (w is Tooltip)
              w.message ?? ''
            else if (w is Semantics)
              w.properties.label ?? ''
            else if (w is Title)
              w.title,
        ];
        expect(strings, containsAll(['=', '÷', title]), reason: 'Recents shows the title');
        for (final s in strings) {
          expect(s, isNot(matches(giveaway)));
        }
        expect(find.byType(AppBar), findsNothing);
        expect(find.byType(IconButton), findsNothing, reason: 'no lock icon, no reveal button');
      });
    }
  });
}
