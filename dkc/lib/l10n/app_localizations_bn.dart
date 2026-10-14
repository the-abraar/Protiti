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
  String get panicSequenceActive => 'জরুরী অবস্থা সক্রিয়';

  @override
  String get panicOfflineReady => 'অফলাইন এসএমএস পাঠানোর জন্য প্রস্তুত';

  @override
  String get panicHoldInstruction =>
      'এসওএস ব্রডকাস্ট করতে ৩ সেকেন্ড চেপে ধরে রাখুন';

  @override
  String get supportBridgeTitle => 'আইনি সহায়তা ও সমর্থন';

  @override
  String get deleteTooltip => 'মুছুন';

  @override
  String get calculatorLabel => 'ক্যালকুলেটর';

  @override
  String get navFiles => 'ফাইল';

  @override
  String get navNotes => 'নোট';

  @override
  String get navSafety => 'নিরাপত্তা';

  @override
  String get navHelp => 'সাহায্য';

  @override
  String get addFileFab => 'ফাইল যোগ করুন';

  @override
  String get safetySettingsTooltip => 'সেটিংস';

  @override
  String get lockVaultTooltip => 'লক করুন';

  @override
  String get addTextNote => 'টেক্সট নোট যোগ করুন';

  @override
  String get secureCameraCapture => 'নিরাপদ ক্যামেরা ক্যাপচার';

  @override
  String get secureAudioRecord => 'নিরাপদ অডিও রেকর্ড';

  @override
  String get secureGalleryImport => 'নিরাপদ গ্যালারি ইম্পোর্ট';

  @override
  String get actionRequiredTitle => 'পদক্ষেপ প্রয়োজন';

  @override
  String get galleryDeleteWarning =>
      'আপনার প্রমাণ এখন এনক্রিপ্ট করে ভল্টে নিরাপদে সংরক্ষণ করা হয়েছে। \n\nতবে, মূল আনএনক্রিপ্টেড ছবিটি এখনও আপনার ফোনের সর্বজনীন ফটো গ্যালারিতে রয়ে গেছে। আপনার নিরাপত্তা নিশ্চিত করতে অবিলম্বে আপনার ফটো অ্যাপ খুলে এটি ম্যানুয়ালি মুছে ফেলুন এবং সম্প্রতি মোছা ফোল্ডারও খালি করুন।';

  @override
  String get iUnderstand => 'আমি বুঝেছি';

  @override
  String get addPersonalDocument => 'ব্যক্তিগত নথি যোগ করুন';

  @override
  String get secureNewEvidence => 'নতুন প্রমাণ সংরক্ষণ করুন';

  @override
  String get documentTitleLabel => 'নথির শিরোনাম / নোট';

  @override
  String get evidenceDescriptionLabel => 'প্রমাণের বিবরণ';

  @override
  String get cancel => 'বাতিল';

  @override
  String get save => 'সংরক্ষণ';

  @override
  String get evidenceDetailsTitle => 'বিস্তারিত';

  @override
  String get close => 'বন্ধ করুন';

  @override
  String get noPersonalFilesYet => 'এখনো কোনো ব্যক্তিগত ফাইল সংরক্ষিত নেই';

  @override
  String get disarmSosTooltip => 'এসওএস নিষ্ক্রিয় করুন';

  @override
  String callContactTooltip(String name) {
    return '$name কে কল করুন';
  }

  @override
  String get deleteItemTitle => 'এটি মুছে ফেলবেন?';

  @override
  String get deleteItemBody =>
      'এটি এই ফোন থেকে মুছে যাবে, আর ফিরিয়ে আনা যাবে না।';

  @override
  String get storageErrorMessage =>
      'আপনার ফাইল খোলা যায়নি। ফোন রিস্টার্ট করে আবার চেষ্টা করুন।';
}
