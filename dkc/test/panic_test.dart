import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protiti/data/services/acoustic_deterrent_service.dart';
import 'package:protiti/data/services/secure_store.dart';
import 'package:protiti/domain/use_cases/trigger_panic.dart';
import 'package:protiti/ui/core/theme/app_theme.dart';
import 'package:protiti/ui/features/panic/panic_screen.dart';
import 'package:protiti/ui/features/support/support_screen.dart';

import 'helpers/app_harness.dart';
import 'helpers/fakes.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (la > lb ? la + 0.05 : lb + 0.05) / (la > lb ? lb + 0.05 : la + 0.05);
}

/// Holds the button for 3.5 s; with [waitOut], also lets the cancel window run out.
Future<void> _holdSos(WidgetTester tester, {bool waitOut = true}) async {
  final gesture = await tester.startGesture(tester.getCenter(find.text('SOS')));
  for (var i = 0; i < 35; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await gesture.up();
  await tester.pump();
  if (!waitOut) return;
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(seconds: 1));
  }
}

/// SMS parts the network needs: UCS-2 as soon as one character is outside
/// ASCII (true of every Bangla letter), else GSM 7-bit.
int _smsParts(String text) {
  final ucs2 = text.codeUnits.any((c) => c > 0x7F);
  final single = ucs2 ? 70 : 160, part = ucs2 ? 67 : 153;
  return text.length <= single ? 1 : (text.length / part).ceil();
}

/// Records whether a recording was started.
class _CountingAudio extends SilentAudioService {
  int starts = 0;
  @override
  Future<bool> startRecording({bool askPermission = true}) async {
    starts++;
    return false;
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
      expect(sms.sent.single.$2, contains('https://maps.google.com/?q=23.81000,90.41000'));
      expect(sms.sent.single.$2, contains('অবস্থান/Location 09:30'));
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
      expect(result.locationDisplay, 'Location unknown');
    });

    test('the SOS text is Bangla and English, names no app, and fits in 2 SMS parts', () {
      // A fix from another day carries its date: the longest is 31/12.
      final worst = TriggerPanicUseCase.sosMessage(
        lat: -89.123456, lng: -179.123456, fixedAt: DateTime(2025, 12, 31, 23, 59), mocked: true);
      final cases = [
        worst,
        TriggerPanicUseCase.sosMessage(lat: 23.81, lng: 90.41, fixedAt: DateTime(2026, 1, 1, 9, 5)),
        TriggerPanicUseCase.sosMessage(),
      ];
      for (final m in cases) {
        expect(_smsParts(m), lessThanOrEqualTo(TriggerPanicUseCase.maxSmsParts), reason: m);
        expect(m, contains('সাহায্য'));
        expect(m, contains('help'));
        expect(m.toLowerCase(), isNot(contains('protiti')));
      }
      final practice = TriggerPanicUseCase.sosMessage(
        lat: -89.123456, lng: -179.123456, fixedAt: DateTime(2025, 12, 31, 23, 59), mocked: true, practice: true);
      expect(_smsParts(practice), lessThanOrEqualTo(TriggerPanicUseCase.maxSmsParts), reason: practice);
      expect(practice.toLowerCase(), allOf(contains('test'), isNot(contains('protiti'))));
      expect(worst, contains('https://maps.google.com/?q=-89.12346,-179.12346'));
      expect(worst, contains('Location 31/12,'), reason: 'an old fix must not look current (N11)');
      final now = DateTime.now();
      expect(TriggerPanicUseCase.sosMessage(lat: 1, lng: 2, fixedAt: DateTime(now.year, now.month, now.day, 9, 5)),
          contains('Location 09:05:'), reason: "today's fix needs no date");
      expect(worst, contains('may be wrong'));
      expect(cases.last, contains('Location unknown'));
      // The helper itself: one Bangla letter makes it UCS-2.
      expect(_smsParts('a' * 160), 1);
      expect(_smsParts('অ' * 70), 1);
      expect(_smsParts('অ' * 71), 2);
      expect(_smsParts('অ' * 134), 2);
      expect(_smsParts('অ' * 135), 3);
    });

    test('the quiet path neither dims nor records', () async {
      final audio = _CountingAudio();
      final quiet = TriggerPanicUseCase(
        FakeLocationService(),
        contactRepository: FakeContactRepository([ayesha]),
        audioService: audio,
        evidenceRepository: FakeEvidenceRepository(),
        sendSms: FakeSms().call,
      );
      await quiet.execute(dim: false, record: false);
      expect(audio.starts, 0);
      await quiet.execute();
      expect(audio.starts, 1);
    });

    test('silent dispatch never falls back to the visible Messages app', () async {
      // The test host is not Android, like iOS: no silent SMS.
      final d = await dispatchSilentSms([ayesha.phone], 'x');
      expect(d.method, 'failed');
      expect(d.statuses, {ayesha.phone: SmsStatus.failed});
      expect(d.allSent, isFalse);
    });
  });

  test('the siren button has a sound to play (N8)', () {
    final siren = File('assets/${AcousticDeterrentService.sirenAsset}');
    expect(siren.existsSync(), isTrue);
    final head = siren.openSync().readSync(12);
    expect(String.fromCharCodes(head.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(head.sublist(8, 12)), 'WAVE');
    expect(siren.lengthSync(), greaterThan(44 + 22050), reason: 'more than a header');
  });

  testWidgets('the support directory offers no number its organisation has not confirmed (N17)', (tester) async {
    await tester.pumpWidget(harness(const Scaffold(body: SupportScreen())));
    expect(find.text('Ain o Salish Kendra (ASK)'), findsOneWidget);
    expect(find.byIcon(Icons.call), findsNothing);
    expect(find.text('01726222222'), findsNothing);
    expect(find.textContaining('109'), findsOneWidget, reason: 'points her to a checked line instead');
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

    Future<void> pumpPanic(WidgetTester tester, FakeSms sms, List<dynamic> contacts,
        {Stream<(String, bool)>? deliveries}) async {
      await tester.binding.setSurfaceSize(const Size(420, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(harness(Scaffold(
        body: PanicScreen(
          useCase: panicUseCase(sms: sms, contacts: List.of(contacts.cast())),
          deliveries: deliveries ?? const Stream.empty(),
        ),
      )));
      await tester.pump();
    }

    testWidgets('the hold starts a 5 s cancel window; nothing is sent before it ends', (tester) async {
      final sms = FakeSms();
      await pumpPanic(tester, sms, [ayesha]);
      await _holdSos(tester, waitOut: false);
      expect(find.text('Sending in 5 s. Cancel if this was a mistake.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      expect(find.text('Sending in 1 s. Cancel if this was a mistake.'), findsOneWidget);
      expect(sms.sent, isEmpty);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(sms.sent, hasLength(1));
    });

    testWidgets('Cancel in the window sends nothing', (tester) async {
      final sms = FakeSms();
      await pumpPanic(tester, sms, [ayesha]);
      await _holdSos(tester, waitOut: false);
      await tester.pump(const Duration(seconds: 2));
      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
      await tester.pump(const Duration(seconds: 10));
      expect(sms.sent, isEmpty);
      expect(find.text('Press & Hold for 3 seconds to broadcast SOS'), findsOneWidget);
    });

    testWidgets('Send now skips the rest of the window', (tester) async {
      final sms = FakeSms();
      await pumpPanic(tester, sms, [ayesha]);
      await _holdSos(tester, waitOut: false);
      await tester.tap(find.text('Send now'));
      await tester.pump();
      expect(sms.sent, hasLength(1));
      await tester.pump(const Duration(seconds: 6));
      expect(sms.sent, hasLength(1), reason: 'the timer must not send again');
    });

    // She turns the screen off, switches app, changes tab, or the vault locks (N2).
    for (final (how, leave) in [
      ('the screen goes away', (WidgetTester t) => t.pumpWidget(const SizedBox())),
      ('the app is paused', (WidgetTester t) async {
        t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        addTearDown(() => t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed));
      }),
    ]) {
      testWidgets('leaving mid-countdown sends at once, silently, and logs it: $how', (tester) async {
        final storage = FakeSecureStorage()..install();
        addTearDown(storage.uninstall);
        final visible = FakeSms(), silent = FakeSms();
        PanicScreen.unattendedSms = silent.call;
        addTearDown(() => PanicScreen.unattendedSms = dispatchSilentSms);
        await pumpPanic(tester, visible, [ayesha]);
        await _holdSos(tester, waitOut: false);
        await tester.pump(const Duration(seconds: 2));

        await leave(tester);
        await tester.pump();
        expect(silent.sent, hasLength(1));
        expect(visible.sent, isEmpty, reason: 'nothing may pop up later for anyone to see');
        expect(storage.store[StoreKeys.lastAlert], endsWith('|1|1'), reason: 'the SOS tab tells her later');
        await tester.pump(const Duration(seconds: 10));
        expect(silent.sent, hasLength(1), reason: 'once only');
      });
    }

    testWidgets('delivery reports update each recipient', (tester) async {
      final reports = StreamController<(String, bool)>.broadcast();
      addTearDown(reports.close);
      await pumpPanic(tester, FakeSms(), [ayesha, rina], deliveries: reports.stream);
      await _holdSos(tester);
      reports.add((ayesha.phone, true));
      reports.add((rina.phone, false));
      await tester.pump();
      expect(find.text('${ayesha.phone}: Sent, delivered'), findsOneWidget);
      expect(find.text('${rina.phone}: Sent, not delivered'), findsOneWidget);
    });

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
