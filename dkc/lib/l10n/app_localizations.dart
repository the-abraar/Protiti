import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_bn.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('bn'),
    Locale('en'),
  ];

  /// App bar title in both the real and second-PIN views. Neutral: never the brand name (N3).
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get appTitle;

  /// No description provided for @panicSequenceActive.
  ///
  /// In en, this message translates to:
  /// **'EMERGENCY SEQUENCE ACTIVE'**
  String get panicSequenceActive;

  /// No description provided for @panicOfflineReady.
  ///
  /// In en, this message translates to:
  /// **'OFFLINE SMS DISPATCH READY'**
  String get panicOfflineReady;

  /// No description provided for @panicHoldInstruction.
  ///
  /// In en, this message translates to:
  /// **'Press & Hold for 3 seconds to broadcast SOS'**
  String get panicHoldInstruction;

  /// No description provided for @supportBridgeTitle.
  ///
  /// In en, this message translates to:
  /// **'Legal Aid & Support Bridge'**
  String get supportBridgeTitle;

  /// No description provided for @deleteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteTooltip;

  /// No description provided for @calculatorLabel.
  ///
  /// In en, this message translates to:
  /// **'Calculator'**
  String get calculatorLabel;

  /// No description provided for @navFiles.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get navFiles;

  /// No description provided for @navNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get navNotes;

  /// No description provided for @navSafety.
  ///
  /// In en, this message translates to:
  /// **'Safety'**
  String get navSafety;

  /// No description provided for @navHelp.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get navHelp;

  /// No description provided for @addFileFab.
  ///
  /// In en, this message translates to:
  /// **'Add File'**
  String get addFileFab;

  /// No description provided for @safetySettingsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get safetySettingsTooltip;

  /// No description provided for @lockVaultTooltip.
  ///
  /// In en, this message translates to:
  /// **'Lock'**
  String get lockVaultTooltip;

  /// No description provided for @addTextNote.
  ///
  /// In en, this message translates to:
  /// **'Add Text Note'**
  String get addTextNote;

  /// No description provided for @secureCameraCapture.
  ///
  /// In en, this message translates to:
  /// **'Secure Camera Capture'**
  String get secureCameraCapture;

  /// No description provided for @secureAudioRecord.
  ///
  /// In en, this message translates to:
  /// **'Secure Audio Record'**
  String get secureAudioRecord;

  /// No description provided for @secureGalleryImport.
  ///
  /// In en, this message translates to:
  /// **'Secure Gallery Import'**
  String get secureGalleryImport;

  /// No description provided for @actionRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Action Required'**
  String get actionRequiredTitle;

  /// No description provided for @galleryDeleteWarning.
  ///
  /// In en, this message translates to:
  /// **'Your evidence is now encrypted and secured in the Vault. \n\nHowever, the original unencrypted photo is STILL in your phone\'s public photo gallery. You must open your Photos app and manually delete it (and clear your Recently Deleted folder) immediately to ensure your safety.'**
  String get galleryDeleteWarning;

  /// No description provided for @iUnderstand.
  ///
  /// In en, this message translates to:
  /// **'I Understand'**
  String get iUnderstand;

  /// No description provided for @addPersonalDocument.
  ///
  /// In en, this message translates to:
  /// **'Add Personal Document'**
  String get addPersonalDocument;

  /// No description provided for @secureNewEvidence.
  ///
  /// In en, this message translates to:
  /// **'Secure New Evidence'**
  String get secureNewEvidence;

  /// No description provided for @documentTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Document Title / Note'**
  String get documentTitleLabel;

  /// No description provided for @evidenceDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Evidence Description'**
  String get evidenceDescriptionLabel;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @evidenceDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get evidenceDetailsTitle;

  /// No description provided for @secureScreenshotImport.
  ///
  /// In en, this message translates to:
  /// **'Import Screenshot'**
  String get secureScreenshotImport;

  /// No description provided for @addDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Add details (optional)'**
  String get addDetailsTitle;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @evidencePlatformLabel.
  ///
  /// In en, this message translates to:
  /// **'App or platform, e.g. Facebook (optional)'**
  String get evidencePlatformLabel;

  /// No description provided for @evidenceUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Link to the post or profile (optional)'**
  String get evidenceUrlLabel;

  /// No description provided for @captureSourceLabel.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get captureSourceLabel;

  /// No description provided for @captureSourceName.
  ///
  /// In en, this message translates to:
  /// **'{source, select, camera{Camera} gallery{Gallery} screenshot{Screenshot} note{Typed note} audio{Microphone} other{Not recorded}}'**
  String captureSourceName(String source);

  /// No description provided for @capturedAtLabel.
  ///
  /// In en, this message translates to:
  /// **'Saved at (this phone\'s clock, UTC)'**
  String get capturedAtLabel;

  /// No description provided for @platformLabel.
  ///
  /// In en, this message translates to:
  /// **'App or platform'**
  String get platformLabel;

  /// No description provided for @linkLabel.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get linkLabel;

  /// No description provided for @sha256Label.
  ///
  /// In en, this message translates to:
  /// **'SHA-256 of the original'**
  String get sha256Label;

  /// No description provided for @notRecorded.
  ///
  /// In en, this message translates to:
  /// **'Not recorded (saved by an older version)'**
  String get notRecorded;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @noPersonalFilesYet.
  ///
  /// In en, this message translates to:
  /// **'No personal files saved yet'**
  String get noPersonalFilesYet;

  /// No description provided for @disarmSosTooltip.
  ///
  /// In en, this message translates to:
  /// **'Disarm SOS'**
  String get disarmSosTooltip;

  /// No description provided for @callContactTooltip.
  ///
  /// In en, this message translates to:
  /// **'Call {name}'**
  String callContactTooltip(String name);

  /// No description provided for @deleteItemTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this item?'**
  String get deleteItemTitle;

  /// No description provided for @deleteItemBody.
  ///
  /// In en, this message translates to:
  /// **'It is removed from this phone and cannot be brought back.'**
  String get deleteItemBody;

  /// No description provided for @storageErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Your files could not be opened. Restart the phone and try again.'**
  String get storageErrorMessage;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['bn', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'bn':
      return AppLocalizationsBn();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
