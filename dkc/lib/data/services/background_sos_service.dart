import 'dart:async';
import 'dart:io';
import 'dart:ui' show DartPluginRegistrant;
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hardware_sos/hardware_sos.dart' as hardware_sos;
import 'package:record/record.dart';
import '../../domain/use_cases/trigger_panic.dart';
import '../repositories/contact_repository.dart';
import '../repositories/evidence_repository.dart';
import 'database_service.dart';
import 'location_service.dart';
import 'native_sms_service.dart';
import 'secure_audio_service.dart';
import 'secure_store.dart';
import 'shake_to_sos_service.dart';
import 'silent_alert_service.dart';

/// About 5 s between any trigger and the first text, to cancel a mistake.
const sosCancelWindow = Duration(seconds: 5);

/// Each one off by default; she turns it on in Settings after an explanation.
enum SosTrigger {
  power(StoreKeys.powerSosOn),
  shake(StoreKeys.shakeSosOn);

  const SosTrigger(this.storeKey);
  final String storeKey;
}

/// A practice run (N16): for [window] after she arms it in Settings, the next
/// shortcut texts [TriggerPanicUseCase.practiceHead] instead of the SOS.
abstract final class SosPractice {
  static const window = Duration(minutes: 10);

  static Future<void> arm() => secureStore.write(
    key: StoreKeys.practiceUntil,
    value: DateTime.now().add(window).toIso8601String(),
  );

  /// True once while armed; disarms either way. Never throws.
  static Future<bool> take() async {
    try {
      final until = DateTime.tryParse(
        await secureStore.read(key: StoreKeys.practiceUntil) ?? '',
      );
      if (until == null) return false;
      await secureStore.delete(key: StoreKeys.practiceUntil);
      return DateTime.now().isBefore(until);
    } catch (_) {
      return false;
    }
  }
}

/// Vibration patterns (ms: wait, buzz, wait, buzz...) she can tell apart by
/// feel, with the phone in a pocket.
abstract final class Buzz {
  /// Two short: a trigger fired; it sends in [sosCancelWindow] unless cancelled.
  static const armed = [0, 150, 120, 150];

  /// One long: every contact's text was accepted by the network.
  static const sent = [0, 1000];

  /// Three long: not sent to everyone. Call 999.
  static const failed = [0, 600, 300, 600, 300, 600];
}

/// Vibration and the one status notice, from any engine (hardware_sos plugin).
class SosAlerts {
  const SosAlerts();

  Future<void> vibrate(List<int> pattern) =>
      _call('vibrate', {'pattern': pattern});

  Future<void> notify(
    String text, {
    bool cancel = false,
    bool call999 = false,
  }) => _call('notify', {'text': text, 'cancel': cancel, 'call999': call999});

  Future<void> clear() => _call('clearNotice');

  static Future<void> _call(String method, [Object? args]) async {
    try {
      await NativeSmsService.channel.invokeMethod(method, args);
    } catch (_) {}
  }
}

/// Every notice is plain, never a heads-up, and hidden on a secure lock screen
/// (N4): someone holding the phone learns little from it. Settings tells her
/// what each one means, and the buzz patterns say the same by feel.
/// The foreground-service notice: honest that something runs, nothing more.
const sosServiceNotice = 'Running.';
final sosCountdownNotice = 'Starting in ${sosCancelWindow.inSeconds} seconds.';
const sosNotSentNotice = 'Not done.';

/// The real outcome, never better than it was.
String sosResultNotice(
  SmsDispatch d, {
  int delivered = 0,
  int undelivered = 0,
}) {
  final total = d.statuses.length;
  final sent = d.statuses.values.where((s) => s == SmsStatus.sent).length;
  if (total == 0) return 'Not done: nothing set up.';
  if (sent == 0) return sosNotSentNotice;
  return [
    'Done: $sent of $total.',
    if (delivered > 0) '$delivered confirmed.',
    if (undelivered > 0) '$undelivered not confirmed.',
  ].join(' ');
}

/// One trigger at a time: buzz, show the notice with Cancel, wait [window],
/// send, then buzz and show the real result, updated as delivery reports
/// come in. A trigger while one is under way is ignored, so pressing or
/// shaking again still sends once.
class SosTriggerHandler {
  final Future<PanicResult> Function() send;
  final SosAlerts alerts;
  final Stream<(String, bool)> deliveries;
  final Duration window;
  Completer<bool>? _go;
  StreamSubscription<(String, bool)>? _deliverySub;

  SosTriggerHandler({
    required this.send,
    this.alerts = const SosAlerts(),
    Stream<(String, bool)>? deliveries,
    this.window = sosCancelWindow,
  }) : deliveries = deliveries ?? NativeSmsService.deliveries;

  bool get busy => _go != null;

  Future<void> trigger() async {
    if (_go != null) return;
    final go = _go = Completer<bool>();
    final timer = Timer(window, () {
      if (!go.isCompleted) go.complete(true);
    });
    try {
      await alerts.vibrate(Buzz.armed);
      await alerts.notify(sosCountdownNotice, cancel: true);
      if (!await go.future) {
        await alerts.clear();
        return;
      }
      PanicResult? result;
      try {
        result = await send();
      } catch (_) {}
      final ok = result?.success ?? false;
      await alerts.vibrate(ok ? Buzz.sent : Buzz.failed);
      if (result == null) {
        await alerts.notify(sosNotSentNotice, call999: true);
        return;
      }
      await alerts.notify(sosResultNotice(result.dispatch), call999: !ok);
      _watchDeliveries(result.dispatch);
    } finally {
      timer.cancel();
      _go = null;
    }
  }

  /// From the notice's Cancel button. Too late once the window has passed.
  void cancel() {
    final go = _go;
    if (go != null && !go.isCompleted) go.complete(false);
  }

  void _watchDeliveries(SmsDispatch d) {
    _deliverySub?.cancel();
    final delivered = <String>{}, undelivered = <String>{};
    _deliverySub = deliveries
        .where((e) => d.statuses[e.$1] == SmsStatus.sent)
        .listen((e) {
          (e.$2 ? delivered : undelivered).add(e.$1);
          alerts.notify(
            sosResultNotice(
              d,
              delivered: delivered.length,
              undelivered: undelivered.length,
            ),
            call999: !d.allSent || undelivered.isNotEmpty,
          );
        });
  }

  void dispose() {
    cancel();
    _deliverySub?.cancel();
  }
}

/// The power-button and shake triggers, in flutter_background_service's own
/// engine. Android only: iOS allows neither background triggers nor silent SMS.
@pragma('vm:entry-point')
class BackgroundSosService {
  /// Test seam: the permission check, so widget tests need no platform plugins.
  @visibleForTesting
  static Future<bool> Function({required bool ask}) permissions = _permissions;

  /// SMS, notifications (the Cancel button), location (the link) and the
  /// microphone (the service's declared type; it records two minutes as
  /// evidence). With [ask] false this only checks and never prompts.
  static Future<bool> _permissions({required bool ask}) async {
    if (!Platform.isAndroid) return false;
    try {
      if (!await NativeSmsService.hasPermission() &&
          !(ask && await NativeSmsService.requestPermission())) {
        return false;
      }
      var location = await Geolocator.checkPermission();
      if (ask && location == LocationPermission.denied) {
        location = await Geolocator.requestPermission();
      }
      if (location != LocationPermission.always &&
          location != LocationPermission.whileInUse) {
        return false;
      }
      if (!await AudioRecorder().hasPermission(request: ask)) return false;
      return await NativeSmsService.hasNotificationPermission() ||
          (ask && await NativeSmsService.requestNotificationPermission());
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isOn(SosTrigger t) async {
    try {
      return await secureStore.read(key: t.storeKey) == 'true';
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _anyOn() async =>
      await isOn(SosTrigger.power) || await isOn(SosTrigger.shake);

  /// False when a trigger is on but a permission was taken away since, so
  /// the service cannot run. Settings says so instead of failing silently.
  static Future<bool> ready() => permissions(ask: false);

  /// Asks for the permissions (call only after explaining why), then turns
  /// [t] on. Returns false, and it stays off, if any was refused.
  static Future<bool> enable(SosTrigger t) async {
    if (!await permissions(ask: true)) return false;
    await secureStore.write(key: t.storeKey, value: 'true');
    await _sync();
    return true;
  }

  static Future<void> disable(SosTrigger t) async {
    await secureStore.delete(key: t.storeKey);
    await _sync();
  }

  /// After a wipe has deleted the switches: a running service stops itself,
  /// and its status notice goes, so the plain calculator carries none (N9).
  static Future<void> afterWipe() async {
    await _sync();
    await const SosAlerts().clear();
  }

  /// Called on every lock screen load. Starts the service only if a trigger
  /// is on and the permissions still hold; never prompts, never throws.
  static Future<bool> startIfEnabled() async {
    try {
      if (!await _anyOn() || !await permissions(ask: false)) return false;
      await _sync();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Running exactly while a trigger is on: a running service re-reads the
  /// switches (and stops itself when none is on); a stopped one starts.
  static Future<void> _sync() async {
    if (!Platform.isAndroid) return;
    try {
      final service = FlutterBackgroundService();
      if (await service.isRunning()) {
        service.invoke('reload');
      } else if (await _anyOn()) {
        await _start(service);
      }
    } catch (_) {}
  }

  static Future<void> _start(FlutterBackgroundService service) async {
    var label = '';
    try {
      label =
          await NativeSmsService.channel.invokeMethod<String>('appLabel') ?? '';
    } catch (_) {}
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        // Android 14+ refuses a location/microphone service started at boot.
        // Opening the app once after a restart turns the triggers back on.
        autoStartOnBoot: false,
        isForegroundMode: true,
        // No channel id, so the plugin creates its own. Titled with this
        // app's label from resources, never the system's or another app's.
        initialNotificationTitle: label,
        initialNotificationContent: sosServiceNotice,
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(autoStart: false),
    );
    await service.startService();
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    // Plugins' Dart halves (path_provider, geolocator...) are not registered
    // on this engine until asked; without them every SOS found no contacts.
    DartPluginRegistrant.ensureInitialized();
    final handler = SosTriggerHandler(
      send: () async {
        final practice = await SosPractice.take();
        final result = await TriggerPanicUseCase(
          LocationService(),
          contactRepository: ContactRepository(DatabaseService()),
          audioService: SecureAudioService(),
          evidenceRepository: EvidenceRepository(DatabaseService()),
          sendSms: dispatchSilentSms,
        ).execute(dim: false, practice: practice);
        if (!practice) await AlertLog.record(result);
        return result;
      },
    );

    StreamSubscription<String>? events;
    late final ShakeToSosService shake;

    Future<void> apply() async {
      final shakeOn = await isOn(SosTrigger.shake);
      shakeOn ? shake.startListening() : shake.stopListening();
      if (!shakeOn && !await isOn(SosTrigger.power)) {
        await events?.cancel();
        handler.dispose();
        service.stopSelf();
      }
    }

    // The switch is read again at trigger time: after a wipe or a change in
    // Settings, a stale service must not send.
    Future<void> fire(SosTrigger t) async =>
        await isOn(t) ? handler.trigger() : apply();

    shake = ShakeToSosService(() => fire(SosTrigger.shake));
    // Also carries the notice's Cancel taps, so it is listened to even when
    // only shake is on.
    events = hardware_sos.HardwareSos().sosEvents.listen((event) {
      if (event == 'sos_cancelled') handler.cancel();
      if (event == 'sos_triggered') fire(SosTrigger.power);
    });
    service.on('reload').listen((_) => apply());
    await apply();
  }
}
