import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protiti/data/services/auth_service.dart';
import 'package:protiti/data/services/secure_store.dart';
import 'package:protiti/ui/features/auth/lock_screen.dart';
import 'package:protiti/ui/features/vault/vault_screen.dart';

import 'helpers/app_harness.dart';
import 'helpers/fakes.dart';

const _real = '246813';
const _duress = '135792';
const _wipe = '975310';

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

  Future<void> openCalculator(WidgetTester tester) async {
    await tester.pumpWidget(harness(const LockScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Enable Calculator Stealth Disguise'));
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

  testWidgets('% and ± are calculator operations, not typed text', (tester) async {
    await openCalculator(tester);
    await calc(tester, '5%');
    expect(display(tester), '0.05');
    await calc(tester, 'C5±');
    expect(display(tester), '-5');
    await calc(tester, '±');
    expect(display(tester), '5');
  });

  testWidgets('a wrong code on the calculator is counted but shows nothing', (tester) async {
    await openCalculator(tester);
    await calc(tester, '111111=');
    expect(storage.store[StoreKeys.failedAttempts], '1');
    expect(display(tester), '111111');
    expect(find.textContaining('Incorrect'), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
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

  testWidgets('the wipe code destroys the data and lands on a blank calculator', (tester) async {
    File('${root.path}/docs/photo.enc').writeAsStringSync('x');
    await tester.binding.setSurfaceSize(const Size(420, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(harness(const LockScreen()));
    await tester.pumpAndSettle();

    for (final d in _wipe.split('')) {
      await tester.tap(find.widgetWithText(InkWell, d));
      await tester.pump();
    }
    await tester.tap(find.byTooltip('Enter'));
    // The wipe does real file I/O, which only runs outside the fake clock.
    for (var i = 0; i < 40 && !storage.store.containsKey(StoreKeys.launchAsCalculator); i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();

    expect(File('${root.path}/docs/photo.enc').existsSync(), isFalse);
    expect(storage.store, {StoreKeys.launchAsCalculator: 'true'});
    expect(display(tester), '0');
    expect(find.textContaining('Set up'), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
  });
}
