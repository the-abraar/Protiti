import 'dart:io';
import 'package:flutter/material.dart';
import 'package:secure_application/secure_application.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:protiti/l10n/app_localizations.dart'; 
import 'ui/core/theme/app_theme.dart';
import 'ui/features/auth/lock_screen.dart';

import 'data/services/rasp_service.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The background SOS service (hardware button / shake-to-SOS / geofence)
  // requests its own location + microphone permissions and starts itself
  // once they're granted — see BackgroundSosService.ensureStarted(), called
  // from LockScreen.initState(). Starting it unconditionally here crashes on
  // Android 14+, which requires a foreground service's declared permission
  // types to already be granted before the service can start.

  // Arm the Runtime Application Self-Protection (RASP) Engine
  await RaspService.initializeRasp();
  
  runApp(const ProtitiApp());
}

class ProtitiApp extends StatefulWidget {
  const ProtitiApp({super.key});

  @override
  State<ProtitiApp> createState() => _ProtitiAppState();
}

class _ProtitiAppState extends State<ProtitiApp> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSupported = Platform.isAndroid || Platform.isIOS;
    
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
      home: isSupported 
        ? SecureApplication(
            nativeRemoveDelay: 100,
            autoUnlockNative: true,
            child: Builder(builder: (context) {
              // Secures the app by blurring it in the background task switcher
              // and blocking OS-level screenshots.
              return SecureGate(
                blurr: 20,
                lockedBuilder: (context, secureNotifier) => const Scaffold(
                  backgroundColor: Color(0xFFF7F9FC),
                  body: Center(
                    child: Icon(Icons.lock_outline, size: 48, color: Color(0xFFA0AEC0)),
                  ),
                ),
                child: const LockScreen(),
              );
            }),
          )
        : const LockScreen(),
    );
  }
}
