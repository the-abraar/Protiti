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
  String get panicSequenceActive => 'EMERGENCY SEQUENCE ACTIVE';

  @override
  String get panicOfflineReady => 'OFFLINE SMS DISPATCH READY';

  @override
  String get panicHoldInstruction =>
      'Press & Hold for 3 seconds to broadcast SOS';

  @override
  String get supportBridgeTitle => 'Legal Aid & Support Bridge';

  @override
  String get deleteTooltip => 'Delete';

  @override
  String get calculatorLabel => 'Calculator';

  @override
  String get navFiles => 'Files';

  @override
  String get navNotes => 'Notes';

  @override
  String get navSafety => 'Safety';

  @override
  String get navHelp => 'Help';

  @override
  String get addFileFab => 'Add File';

  @override
  String get safetySettingsTooltip => 'Settings';

  @override
  String get lockVaultTooltip => 'Lock';

  @override
  String get addTextNote => 'Add Text Note';

  @override
  String get secureCameraCapture => 'Secure Camera Capture';

  @override
  String get secureAudioRecord => 'Secure Audio Record';

  @override
  String get secureGalleryImport => 'Secure Gallery Import';

  @override
  String get actionRequiredTitle => 'Action Required';

  @override
  String get galleryDeleteWarning =>
      'Your evidence is now encrypted and secured in the Vault. \n\nHowever, the original unencrypted photo is STILL in your phone\'s public photo gallery. You must open your Photos app and manually delete it (and clear your Recently Deleted folder) immediately to ensure your safety.';

  @override
  String get iUnderstand => 'I Understand';

  @override
  String get addPersonalDocument => 'Add Personal Document';

  @override
  String get secureNewEvidence => 'Secure New Evidence';

  @override
  String get documentTitleLabel => 'Document Title / Note';

  @override
  String get evidenceDescriptionLabel => 'Evidence Description';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get evidenceDetailsTitle => 'Details';

  @override
  String get secureScreenshotImport => 'Import Screenshot';

  @override
  String get addDetailsTitle => 'Add details (optional)';

  @override
  String get skip => 'Skip';

  @override
  String get evidencePlatformLabel =>
      'App or platform, e.g. Facebook (optional)';

  @override
  String get evidenceUrlLabel => 'Link to the post or profile (optional)';

  @override
  String get captureSourceLabel => 'Source';

  @override
  String captureSourceName(String source) {
    String _temp0 = intl.Intl.selectLogic(source, {
      'camera': 'Camera',
      'gallery': 'Gallery',
      'screenshot': 'Screenshot',
      'note': 'Typed note',
      'audio': 'Microphone',
      'other': 'Not recorded',
    });
    return '$_temp0';
  }

  @override
  String get capturedAtLabel => 'Saved at (this phone\'s clock, UTC)';

  @override
  String get platformLabel => 'App or platform';

  @override
  String get linkLabel => 'Link';

  @override
  String get sha256Label => 'SHA-256 of the original';

  @override
  String get notRecorded => 'Not recorded (saved by an older version)';

  @override
  String get close => 'Close';

  @override
  String get noPersonalFilesYet => 'No personal files saved yet';

  @override
  String get disarmSosTooltip => 'Disarm SOS';

  @override
  String callContactTooltip(String name) {
    return 'Call $name';
  }

  @override
  String get deleteItemTitle => 'Delete this item?';

  @override
  String get deleteItemBody =>
      'It is removed from this phone and cannot be brought back.';

  @override
  String get storageErrorMessage =>
      'Your files could not be opened. Restart the phone and try again.';
}
