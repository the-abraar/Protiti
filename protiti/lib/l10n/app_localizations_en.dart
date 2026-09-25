// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Protiti (প্রতীতি)';

  @override
  String get vaultAuthTitle => 'Forensic Vault Authentication';

  @override
  String get vaultAuthSubtitle =>
      'Enter security PIN or use biometrics to access records';

  @override
  String get panicSequenceActive => 'EMERGENCY SEQUENCE ACTIVE';

  @override
  String get panicOfflineReady => 'OFFLINE SMS DISPATCH READY';

  @override
  String get panicHoldInstruction =>
      'Press & Hold for 3 seconds to broadcast SOS';

  @override
  String get supportBridgeTitle => 'Legal Aid & Support Bridge';

  @override
  String get decoySupportTitle => 'Student Services & Campus Directory';

  @override
  String get decoyVaultTitle => 'Personal Notes & Files';
}
