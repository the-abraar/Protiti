import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protiti/main.dart';
import 'package:secure_application/secure_application.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('secure_application');
  final nativeCalls = <String>[];

  setUp(() {
    nativeCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (call) async => nativeCalls.add(call.method),
        );
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  testWidgets('pushed and replaced routes sit under the secured protection', (
    tester,
  ) async {
    appSecurity.secure();
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        builder: protectApp,
        home: const Text('home'),
      ),
    );

    navigator.currentState!.push(
      MaterialPageRoute(builder: (_) => const Text('pushed')),
    );
    await tester.pumpAndSettle();
    expect(
      SecureApplicationProvider.of(
        tester.element(find.text('pushed')),
        listen: false,
      )?.secured,
      isTrue,
    );

    navigator.currentState!.pushReplacement(
      MaterialPageRoute(builder: (_) => const Text('replaced')),
    );
    await tester.pumpAndSettle();
    expect(
      SecureApplicationProvider.of(
        tester.element(find.text('replaced')),
        listen: false,
      )?.secured,
      isTrue,
    );
    expect(nativeCalls, contains('secure'));
    expect(nativeCalls, isNot(contains('open')));
  });

  test('native config: FLAG_SECURE for the whole app, no Android backup', () {
    final activity = File(
      'android/app/src/main/kotlin/com/protiti/protiti/MainActivity.kt',
    ).readAsStringSync();
    expect(activity, contains('WindowManager.LayoutParams.FLAG_SECURE'));
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(manifest, contains('android:allowBackup="false"'));
    expect(
      manifest,
      contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
    );
  });
}
