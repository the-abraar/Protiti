import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protiti/data/services/auth_service.dart';
import 'package:protiti/main.dart';

import 'helpers/fakes.dart';

void main() {
  final storage = FakeSecureStorage();
  late Directory root;
  setUp(() {
    storage
      ..store.clear()
      ..install();
    root = installTempPaths();
  });
  tearDown(() {
    storage.uninstall();
    root.deleteSync(recursive: true);
  });

  /// The setup check reads a file, which only runs outside the fake clock.
  Future<void> launch(WidgetTester tester) async {
    await tester.pumpWidget(const ProtitiApp());
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
  }

  testWidgets('first launch asks for codes, typed twice, before anything else', (tester) async {
    await launch(tester);
    expect(find.text('Set up your codes'), findsOneWidget);
    expect(find.text('Real PIN again'), findsOneWidget);
    await tester.dragUntilVisible(find.text('Wipe code again'), find.byType(ListView), const Offset(0, -200));
    expect(find.text('Wipe code again'), findsOneWidget);
  });

  testWidgets('after setup the app opens as the calculator, never a branded screen', (tester) async {
    await AuthService().setPins(realPin: '246813', duressPin: '135792', wipeCode: '975310');
    await launch(tester);

    expect(find.text('Set up your codes'), findsNothing);
    for (final key in ['C', '±', '%', '÷', '×', '−', '+', '=', '.', '0', '9']) {
      expect(find.widgetWithText(ElevatedButton, key), findsOneWidget, reason: key);
    }
    expect(find.byType(AppBar), findsNothing);
  });
}
