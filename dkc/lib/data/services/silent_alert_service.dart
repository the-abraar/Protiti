import '../../domain/use_cases/trigger_panic.dart';
import '../repositories/contact_repository.dart';
import '../repositories/evidence_repository.dart';
import 'database_service.dart';
import 'location_service.dart';
import 'secure_audio_service.dart';
import 'secure_store.dart';

/// The last alert sent while the app was not on screen (a shortcut, the
/// second PIN, or an in-app SOS she left mid-countdown), so the real SOS tab
/// can tell her whether it went.
class AlertLog {
  static Future<void> record(PanicResult r) async {
    final sent = r.dispatch.statuses.values.where((s) => s == SmsStatus.sent).length;
    try {
      await secureStore.write(
        key: StoreKeys.lastAlert,
        value: '${r.timestamp.toIso8601String()}|$sent|${r.dispatch.statuses.length}',
      );
    } catch (_) {}
  }

  /// Null when there is nothing to report.
  static Future<String?> summary() async {
    try {
      final parts = (await secureStore.read(key: StoreKeys.lastAlert))?.split('|');
      if (parts == null || parts.length != 3) return null;
      final at = DateTime.parse(parts[0]);
      final sent = int.parse(parts[1]), total = int.parse(parts[2]);
      final when = '${at.day}/${at.month} ${at.hour.toString().padLeft(2, '0')}:'
          '${at.minute.toString().padLeft(2, '0')}';
      if (total == 0) return 'Alert at $when: not sent, you had no trusted contacts.';
      return 'Alert at $when: sent to $sent of $total contacts.';
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    try {
      await secureStore.delete(key: StoreKeys.lastAlert);
    } catch (_) {}
  }
}

/// Opt-in, off by default (B22): opening with the second PIN quietly texts
/// her trusted contacts. Silent SMS only, no dimming, no recording, no
/// buzz, no notice: the decoy looks exactly as it does without it.
class DuressAlert {
  static Future<bool> isOn() async {
    try {
      return await secureStore.read(key: StoreKeys.duressAlertOn) == 'true';
    } catch (_) {
      return false;
    }
  }

  static Future<void> setOn(bool on) => on
      ? secureStore.write(key: StoreKeys.duressAlertOn, value: 'true')
      : secureStore.delete(key: StoreKeys.duressAlertOn);

  /// Never throws and never shows anything.
  static Future<void> sendIfOn({TriggerPanicUseCase? useCase}) async {
    try {
      if (!await isOn()) return;
      final panic = useCase ??
          TriggerPanicUseCase(
            LocationService(),
            contactRepository: ContactRepository(DatabaseService()),
            audioService: SecureAudioService(),
            evidenceRepository: EvidenceRepository(DatabaseService()),
            sendSms: dispatchSilentSms,
          );
      await AlertLog.record(await panic.execute(dim: false, record: false));
    } catch (_) {}
  }
}
