// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Bengali Bangla (`bn`).
class AppLocalizationsBn extends AppLocalizations {
  AppLocalizationsBn([String locale = 'bn']) : super(locale);

  @override
  String get appTitle => 'প্রতীতি';

  @override
  String get vaultAuthTitle => 'ফরেনসিক ভল্ট প্রমাণীকরণ';

  @override
  String get vaultAuthSubtitle =>
      'রেকর্ড অ্যাক্সেস করতে নিরাপত্তা পিন বা বায়োমেট্রিক্স ব্যবহার করুন';

  @override
  String get panicSequenceActive => 'জরুরী অবস্থা সক্রিয়';

  @override
  String get panicOfflineReady => 'অফলাইন এসএমএস পাঠানোর জন্য প্রস্তুত';

  @override
  String get panicHoldInstruction =>
      'এসওএস ব্রডকাস্ট করতে ৩ সেকেন্ড চেপে ধরে রাখুন';

  @override
  String get supportBridgeTitle => 'আইনি সহায়তা ও সমর্থন';

  @override
  String get decoySupportTitle => 'ছাত্র পরিষেবা এবং ক্যাম্পাস ডিরেক্টরি';

  @override
  String get decoyVaultTitle => 'ব্যক্তিগত নোট এবং ফাইল';
}
