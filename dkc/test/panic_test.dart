import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protiti/domain/use_cases/trigger_panic.dart';
import 'package:protiti/ui/core/theme/app_theme.dart';
import 'package:protiti/ui/features/panic/panic_screen.dart';

import 'helpers/app_harness.dart';
import 'helpers/fakes.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (la > lb ? la + 0.05 : lb + 0.05) / (la > lb ? lb + 0.05 : la + 0.05);
}

Future<void> _holdSos(WidgetTester tester) async {
  final gesture = await tester.startGesture(tester.getCenter(find.text('SOS')));
  for (var i = 0; i < 35; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await gesture.up();
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final ayesha = contact('Ayesha', '+8801711111111');
  final rina = contact('Rina', '+8801822222222');

  group('TriggerPanicUseCase', () {
    test('sends the SMS at once with the cached location, to her contacts only', () async {
      final sms = FakeSms();
      final clock = Stopwatch()..start();
      final result = await panicUseCase(sms: sms, contacts: [ayesha, rina], at: position(23.81, 90.41)).execute();

      expect(clock.elapsed, lessThan(const Duration(milliseconds: 500)), reason: 'no waits before the SMS');
      expect(sms.sent.single.$1, [ayesha.phone, rina.phone]);
      expect(sms.sent.single.$2, contains('maps.google.com/?q=23.810000,90.410000'));
      expect(sms.sent.single.$2, contains('last known at 09:30'));
      expect(result.success, isTrue);
      expect(result.dispatch.statuses, {ayesha.phone: SmsStatus.sent, rina.phone: SmsStatus.sent});
    });

    test('with no contacts nothing is texted to 999 or 109', () async {
      final result = await panicUseCase(sms: FakeSms()).execute();
      expect(result.dispatchMethod, 'no_contacts');
      expect(result.recipients, isEmpty);
      expect(result.success, isFalse);
      expect((await dispatchSms(const [], 'x')).method, 'no_contacts');
    });

    test('a refused message is reported as failed, never as success', () async {
      final sms = FakeSms()..answer = SmsStatus.failed;
      final result = await panicUseCase(sms: sms, contacts: [ayesha]).execute();
      expect(result.success, isFalse);
      expect(result.dispatch.statuses[ayesha.phone], SmsStatus.failed);
      expect(result.locationDisplay, 'GPS location unavailable');
    });
  });

  group('PanicScreen', () {
    // A full send dims the screen; answer that platform call so the test does not wait on it.
    const brightness = MethodChannel('github.com/aaassseee/screen_brightness');
    final dimmed = <Object?>[];
    setUp(() {
      dimmed.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(brightness, (call) async => dimmed.add(call.arguments));
    });
    tearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(brightness, null));

    Future<void> pumpPanic(WidgetTester tester, FakeSms sms, List<dynamic> contacts) async {
      await tester.binding.setSurfaceSize(const Size(420, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(harness(Scaffold(
        body: PanicScreen(useCase: panicUseCase(sms: sms, contacts: List.of(contacts.cast()))),
      )));
      await tester.pump();
    }

    testWidgets('a failed send shows the failure per recipient next to a big Call 999', (tester) async {
      await pumpPanic(tester, FakeSms()..answer = SmsStatus.failed, [ayesha]);
      await _holdSos(tester);
      expect(find.textContaining('failed'), findsWidgets);
      expect(find.text('${ayesha.phone}: Failed'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Call 999'), findsOneWidget);
      expect(find.textContaining('Successfully'), findsNothing);
      expect(dimmed, isEmpty, reason: 'she must be able to read the error');
    });

    testWidgets('a full send says so and needs no Call 999 button', (tester) async {
      await pumpPanic(tester, FakeSms(), [ayesha]);
      await _holdSos(tester);
      expect(find.text('SOS text sent to every contact.'), findsOneWidget);
      expect(find.text('${ayesha.phone}: Sent'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Call 999'), findsNothing);
      expect(dimmed, isNotEmpty);
    });

    testWidgets('no contacts: says so, offers Call 999', (tester) async {
      await pumpPanic(tester, FakeSms(), []);
      await _holdSos(tester);
      expect(find.textContaining('no trusted contacts'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Call 999'), findsOneWidget);
    });

    testWidgets('instruction and result text are readable (WCAG AA 4.5:1)', (tester) async {
      await pumpPanic(tester, FakeSms(), [ayesha]);
      final instruction = tester.widget<Text>(find.text('Press & Hold for 3 seconds to broadcast SOS'));
      expect(_contrast(instruction.style!.color!, AppTheme.surfaceLight), greaterThanOrEqualTo(4.5));

      await _holdSos(tester);
      final recipient = tester.widget<Text>(find.text('${ayesha.phone}: Sent'));
      expect(_contrast(recipient.style!.color!, AppTheme.primaryWhite), greaterThanOrEqualTo(4.5));
      // Only verified hotlines are listed.
      expect(find.text('10921'), findsNothing);
      expect(find.text('01700000000'), findsNothing);
    });
  });
}
