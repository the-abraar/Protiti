import 'dart:io';
import 'package:flutter/material.dart';
import 'package:secure_application/secure_application.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:protiti/l10n/app_localizations.dart';
import 'data/repositories/evidence_repository.dart';
import 'data/services/database_service.dart';
import 'data/services/secure_audio_service.dart';
import 'data/services/secure_store.dart';
import 'data/services/temp_files.dart';
import 'ui/core/theme/app_theme.dart';
import 'ui/features/auth/lock_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await migrateStoreKeys();
  } catch (_) {}
  runApp(const ProtitiApp());
  // Decrypted audio or a shared GD PDF left by a killed app or a share sheet.
  TempFiles.sweep();
  WidgetsBinding.instance.addObserver(SweepOnReturn(TempFiles.sweep));
  // Panic recordings cut off by a killed app become evidence rows now.
  SecureAudioService()
      .recoverPending(EvidenceRepository(DatabaseService()))
      .catchError((_) => 0);
}

/// Secured from the first frame: Android FLAG_SECURE (also set natively in
/// MainActivity) and the iOS app-switcher blur.
final appSecurity = SecureApplicationController(SecureApplicationState(secured: true));

/// MaterialApp.builder: sits above the Navigator, so every route, pushed or
/// replaced, is under the same protection.
Widget protectApp(BuildContext context, Widget? child) => SecureApplication(
      secureApplicationController: appSecurity,
      nativeRemoveDelay: 100,
      // The vault already returns to the lock screen when backgrounded, so
      // on return only the switcher cover needs lifting.
      onNeedUnlock: (controller) async {
        controller?.unlock();
        return null;
      },
      child: SecureGate(
        blurr: 20,
        lockedBuilder: (context, _) => ColoredBox(color: Theme.of(context).scaffoldBackgroundColor),
        child: child ?? const SizedBox.shrink(),
      ),
    );

class ProtitiApp extends StatefulWidget {
  const ProtitiApp({super.key});

  @override
  State<ProtitiApp> createState() => _ProtitiAppState();
}

class _ProtitiAppState extends State<ProtitiApp> {
  final bool _isSupported = Platform.isAndroid || Platform.isIOS;

  @override
  void initState() {
    super.initState();
    if (_isSupported) appSecurity.secure();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('bn'),
      ],
      builder: _isSupported ? protectApp : null,
      home: const LockScreen(),
    );
  }
}
