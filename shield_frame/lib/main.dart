import 'package:flutter/material.dart';
import 'ui/core/theme/app_theme.dart';
import 'ui/features/auth/lock_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ShieldFrameApp());
}

class ShieldFrameApp extends StatelessWidget {
  const ShieldFrameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Protiti',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      home: const LockScreen(),
    );
  }
}
