import 'package:flutter/material.dart';
import 'package:secure_application/secure_application.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; 
import 'ui/core/theme/app_theme.dart';
import 'ui/features/auth/lock_screen.dart';

import 'data/services/background_sos_service.dart';
import 'data/services/rasp_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await BackgroundSosService.initializeService();
  
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
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
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
      home: SecureApplication(
        nativeRemoveDelay: 100,
        autoUnlockNative: true,
        child: Builder(builder: (context) {
          // Secures the app by blurring it in the background task switcher
          // and blocking OS-level screenshots.
          return SecureGate(
            blurr: 40,
            lockedBuilder: (context, secureNotifier) => const Scaffold(
              backgroundColor: Colors.black,
              body: Center(
                child: Icon(Icons.shield_outlined, size: 64, color: Colors.grey),
              ),
            ),
            child: const LockScreen(),
          );
        }),
      ),
    );
  }
}
