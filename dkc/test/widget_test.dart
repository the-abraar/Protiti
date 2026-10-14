import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protiti/data/services/auth_service.dart';
import 'package:protiti/main.dart';

import 'helpers/fakes.dart';

void main() {
  final storage = FakeSecureStorage();
  setUp(() => storage
    ..store.clear()
    ..install());
  tearDown(storage.uninstall);

  testWidgets('first launch asks for codes, typed twice, before anything else', (tester) async {
    await tester.pumpWidget(const ProtitiApp());
    await tester.pumpAndSettle();
    expect(find.text('Set up your codes'), findsOneWidget);
    expect(find.text('Real PIN again'), findsOneWidget);
    await tester.dragUntilVisible(find.text('Wipe code again'), find.byType(ListView), const Offset(0, -200));
    expect(find.text('Wipe code again'), findsOneWidget);
  });

  testWidgets('after setup the lock screen shows the keypad', (tester) async {
    await AuthService().setPins(realPin: '246813', duressPin: '135792', wipeCode: '975310');
    await tester.pumpWidget(const ProtitiApp());
    await tester.pumpAndSettle();

    // The brand name renders twice (AppBar title + body heading).
    expect(find.text('Protiti (প্রতীতি)'), findsWidgets);
    expect(find.text('My Notes'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('9'), findsOneWidget);
    expect(find.byTooltip('Enter'), findsOneWidget);
    expect(find.byTooltip('Biometric Unlock'), findsNothing, reason: 'biometrics are opt-in');
  });
}
