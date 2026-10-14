import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protiti/data/services/auth_service.dart';
import 'package:protiti/data/services/background_sos_service.dart';
import 'package:protiti/data/services/secure_store.dart';
import 'package:protiti/data/services/shake_to_sos_service.dart';
import 'package:protiti/data/services/silent_alert_service.dart';
import 'package:protiti/domain/use_cases/trigger_panic.dart';
import 'package:protiti/ui/features/settings/battery_guide_screen.dart';
import 'package:protiti/ui/features/settings/settings_screen.dart';

import 'helpers/app_harness.dart';
import 'helpers/fakes.dart';

/// Records buzzes and notices instead of calling the plugin.
class FakeAlerts extends SosAlerts {
  final List<String> log = [];

  @override
  Future<void> vibrate(List<int> pattern) async => log.add(
      'buzz:${identical(pattern, Buzz.armed) ? 'armed' : identical(pattern, Buzz.sent) ? 'sent' : 'failed'}');

  @override
  Future<void> notify(String text, {bool cancel = false, bool call999 = false}) async =>
      log.add('notice:$text${cancel ? ' [Cancel]' : ''}${call999 ? ' [Call 999]' : ''}');

  @override
  Future<void> clear() async => log.add('clear');
}

PanicResult _result(Map<String, SmsStatus> statuses) => PanicResult(
      formattedMessage: 'm',
      locationDisplay: 'l',
      timestamp: DateTime(2026, 10, 14, 14, 2),
      dispatch: SmsDispatch(statuses.isEmpty ? 'no_contacts' : 'sms', statuses),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const a = '+8801711111111', b = '+8801822222222';

  group('ShakeDetector', () {
    test('four hard shakes within 3 s trigger', () {
      final d = ShakeDetector();
      expect([for (var i = 0; i < 4; i++) d.add(3.5, i * 450)], [false, false, false, true]);
    });

    test('rickshaw and bag movement under 3 g never trigger', () {
      final d = ShakeDetector();
      for (var i = 0; i < 200; i++) {
        expect(d.add(2.9, i * 450), isFalse);
      }
    });

    test('three hard jolts are not enough; spread-out jolts never add up', () {
      final d = ShakeDetector();
      expect([d.add(4, 0), d.add(4, 500), d.add(4, 1000)], everyElement(isFalse));
      final spread = ShakeDetector();
      for (var i = 0; i < 20; i++) {
        expect(spread.add(4, i * 1100), isFalse, reason: 'one jolt every 1.1 s');
      }
    });

    test('peaks closer than the minimum gap count once', () {
      final d = ShakeDetector();
      for (var t = 0; t < 1000; t += 50) {
        expect(d.add(5, t), isFalse);
      }
    });
  });

  group('SosTriggerHandler', () {
    const window = Duration(milliseconds: 40);

    test('buzz and Cancel notice first, then the send, then the real result', () async {
      final alerts = FakeAlerts();
      var sends = 0;
      final h = SosTriggerHandler(
        send: () async {
          sends++;
          return _result({a: SmsStatus.sent, b: SmsStatus.sent});
        },
        alerts: alerts,
        deliveries: const Stream.empty(),
        window: window,
      );
      final run = h.trigger();
      await Future<void>.delayed(Duration.zero);
      expect(alerts.log, ['buzz:armed', 'notice:$sosCountdownNotice [Cancel]']);
      expect(sends, 0, reason: 'nothing goes out inside the window');
      await run;
      expect(sends, 1);
      expect(alerts.log.skip(2), ['buzz:sent', 'notice:Done: 2 of 2.']);
    });

    test('Cancel inside the window sends nothing', () async {
      final alerts = FakeAlerts();
      var sends = 0;
      final h = SosTriggerHandler(
        send: () async {
          sends++;
          return _result({a: SmsStatus.sent});
        },
        alerts: alerts,
        deliveries: const Stream.empty(),
        window: window,
      );
      final run = h.trigger();
      await Future<void>.delayed(Duration.zero);
      h.cancel();
      await run;
      await Future<void>.delayed(window * 2);
      expect(sends, 0);
      expect(alerts.log.last, 'clear');
    });

    test('pressing again while one runs still sends once', () async {
      var sends = 0;
      final h = SosTriggerHandler(
        send: () async {
          sends++;
          return _result({a: SmsStatus.sent});
        },
        alerts: FakeAlerts(),
        deliveries: const Stream.empty(),
        window: window,
      );
      final first = h.trigger();
      await h.trigger();
      await h.trigger();
      await first;
      expect(sends, 1);
      await h.trigger();
      expect(sends, 2, reason: 'a new trigger after the first finished is a new alert');
    });

    test('a failure or a crash says not sent and offers Call 999', () async {
      final alerts = FakeAlerts();
      await SosTriggerHandler(
        send: () async => _result({a: SmsStatus.failed}),
        alerts: alerts,
        deliveries: const Stream.empty(),
        window: window,
      ).trigger();
      expect(alerts.log.skip(2), ['buzz:failed', 'notice:$sosNotSentNotice [Call 999]']);

      final crashed = FakeAlerts();
      await SosTriggerHandler(
        send: () async => throw StateError('db'),
        alerts: crashed,
        deliveries: const Stream.empty(),
        window: window,
      ).trigger();
      expect(crashed.log.skip(2), ['buzz:failed', 'notice:$sosNotSentNotice [Call 999]']);
    });

    test('delivery reports update the notice', () async {
      final alerts = FakeAlerts();
      final reports = StreamController<(String, bool)>();
      final h = SosTriggerHandler(
        send: () async => _result({a: SmsStatus.sent, b: SmsStatus.sent}),
        alerts: alerts,
        deliveries: reports.stream,
        window: window,
      );
      await h.trigger();
      reports
        ..add((a, true))
        ..add(('+8801999999999', true)) // not one of hers: ignored
        ..add((b, false));
      await Future<void>.delayed(Duration.zero);
      expect(alerts.log.skip(4), [
        'notice:Done: 2 of 2. 1 confirmed.',
        'notice:Done: 2 of 2. 1 confirmed. 1 not confirmed. [Call 999]',
      ]);
      h.dispose();
      await reports.close();
    });
  });

  test('result notices never claim more than happened', () {
    String n(Map<String, SmsStatus> s) => sosResultNotice(SmsDispatch('sms', s));
    expect(sosResultNotice(const SmsDispatch('no_contacts', {})), contains('nothing set up'));
    expect(n({a: SmsStatus.failed, b: SmsStatus.failed}), sosNotSentNotice);
    expect(n({a: SmsStatus.sent, b: SmsStatus.failed}), 'Done: 1 of 2.');
    expect(n({a: SmsStatus.sent}), 'Done: 1 of 1.');
    expect(sosServiceNotice.toLowerCase(), isNot(anyOf(contains('system'), contains('google'))));
  });

  test('no notice tells someone holding the phone what happened (N4)', () {
    final giveaway = RegExp(r'sos|alert|message|sms|text|999|help|emergency|contact|deliver|shortcut',
        caseSensitive: false);
    final notices = [
      sosServiceNotice,
      sosCountdownNotice,
      sosNotSentNotice,
      sosResultNotice(const SmsDispatch('no_contacts', {})),
      sosResultNotice(SmsDispatch('sms', {a: SmsStatus.sent, b: SmsStatus.failed}), delivered: 1, undelivered: 1),
    ];
    for (final n in notices) {
      expect(n, isNot(matches(giveaway)));
    }
  });

  group('gating and the second-PIN alert', () {
    late FakeSecureStorage storage;
    setUp(() {
      storage = FakeSecureStorage()..install();
      BackgroundSosService.permissions = ({required bool ask}) async => true;
    });
    tearDown(() {
      storage.uninstall();
      debugDefaultTargetPlatformOverride = null;
    });

    test('both triggers and the alert are off by default; each turns on alone', () async {
      for (final t in SosTrigger.values) {
        expect(await BackgroundSosService.isOn(t), isFalse);
      }
      expect(await DuressAlert.isOn(), isFalse);

      BackgroundSosService.permissions = ({required bool ask}) async => false;
      expect(await BackgroundSosService.enable(SosTrigger.power), isFalse);
      expect(await BackgroundSosService.isOn(SosTrigger.power), isFalse, reason: 'a refused permission keeps it off');

      BackgroundSosService.permissions = ({required bool ask}) async => true;
      expect(await BackgroundSosService.enable(SosTrigger.power), isTrue);
      expect(await BackgroundSosService.isOn(SosTrigger.power), isTrue);
      expect(await BackgroundSosService.isOn(SosTrigger.shake), isFalse);
      await BackgroundSosService.disable(SosTrigger.power);
      expect(storage.store, isNot(contains(StoreKeys.powerSosOn)));
    });

    test('the second PIN sends nothing unless she turned the alert on', () async {
      final sms = FakeSms();
      await DuressAlert.sendIfOn(useCase: panicUseCase(sms: sms, contacts: [contact('A', a)]));
      expect(sms.sent, isEmpty);
      expect(await AlertLog.summary(), isNull);

      await DuressAlert.setOn(true);
      await DuressAlert.sendIfOn(useCase: panicUseCase(sms: sms, contacts: [contact('A', a)]));
      expect(sms.sent.single.$1, [a]);
      expect(await AlertLog.summary(), matches(RegExp(r'^Alert at \d+/\d+ \d\d:\d\d: sent to 1 of 1 contacts\.$')));
      await AlertLog.clear();
      expect(await AlertLog.summary(), isNull);
    });

    test('a broken store or send never throws out of the second-PIN path', () async {
      storage.failing = true;
      await DuressAlert.sendIfOn();
    });

    Future<void> pumpSettings(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(harness(SettingsScreen(authService: AuthService())));
      await tester.pumpAndSettle();
    }

    testWidgets('Settings: off by default, on only after the explanation, then the battery guide',
        (tester) async {
      await pumpSettings(tester);
      final power = find.widgetWithText(SwitchListTile, 'Power button SOS');
      expect(tester.widget<SwitchListTile>(power).value, isFalse);
      expect(tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Shake SOS')).value, isFalse);
      expect(
          tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Silent alert with your second PIN')).value,
          isFalse);

      await tester.tap(power);
      await tester.pumpAndSettle();
      expect(find.textContaining('Press the power button 4 times quickly'), findsWidgets);
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(power).value, isFalse);
      expect(storage.store, isNot(contains(StoreKeys.powerSosOn)));

      await tester.tap(power);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.byType(BatteryGuideScreen), findsOneWidget);
      expect(storage.store[StoreKeys.powerSosOn], 'true');
      expect(storage.store, isNot(contains(StoreKeys.shakeSosOn)));
    });

    testWidgets('Settings: the second-PIN alert needs SMS permission', (tester) async {
      const plugin = MethodChannel('hardware_sos');
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(plugin, (call) async => call.method == 'hasSmsPermission');
      addTearDown(() => messenger.setMockMethodCallHandler(plugin, null));
      await pumpSettings(tester);
      await tester.tap(find.widgetWithText(SwitchListTile, 'Silent alert with your second PIN'));
      await tester.pumpAndSettle();
      expect(find.textContaining('nothing on screen changes'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(storage.store[StoreKeys.duressAlertOn], 'true');
    });

    testWidgets('Settings on iPhone: no trigger toggles, a plain note instead', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await pumpSettings(tester);
      expect(find.text('Power button SOS'), findsNothing);
      expect(find.text('Shake SOS'), findsNothing);
      expect(find.text('Silent alert with your second PIN'), findsNothing);
      expect(find.textContaining('iPhone does not allow'), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('a trigger left on without its permissions says it is not working', (tester) async {
      storage.store[StoreKeys.shakeSosOn] = 'true';
      BackgroundSosService.permissions = ({required bool ask}) async => false;
      await pumpSettings(tester);
      expect(find.textContaining('Not working: a permission was turned off'), findsOneWidget);
    });
  });

  group('battery guide', () {
    test('maps maker names to the four brands', () {
      expect(batteryBrand('Xiaomi'), 'Xiaomi');
      expect(batteryBrand('POCO'), 'Xiaomi');
      expect(batteryBrand('OPPO'), 'Oppo');
      expect(batteryBrand('vivo'), 'Vivo');
      expect(batteryBrand('iQOO'), 'Vivo');
      expect(batteryBrand('realme'), 'Realme');
      expect(batteryBrand('samsung'), isNull);
      expect(batteryBrand(null), isNull);
    });

    testWidgets('shows her brand\'s steps and opens its settings', (tester) async {
      var opened = 0;
      await tester.pumpWidget(harness(BatteryGuideScreen(
        maker: () async => 'Xiaomi',
        openSettings: () async {
          opened++;
          return false;
        },
      )));
      await tester.pumpAndSettle();
      expect(find.text('On your Xiaomi phone'), findsOneWidget);
      expect(find.textContaining('Autostart'), findsOneWidget);
      await tester.tap(find.text('Open Xiaomi settings'));
      await tester.pumpAndSettle();
      expect(opened, 1);
      expect(find.textContaining('Opened this app\'s settings'), findsOneWidget);
    });

    testWidgets('other phones get the general steps and app settings', (tester) async {
      await tester.pumpWidget(harness(BatteryGuideScreen(maker: () async => 'samsung', openSettings: () async => false)));
      await tester.pumpAndSettle();
      expect(find.textContaining('On your'), findsNothing);
      expect(find.text('Open app settings'), findsOneWidget);
    });
  });
}
