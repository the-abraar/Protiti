import 'package:flutter/material.dart';
import 'ui/core/theme/app_theme.dart';
import 'ui/features/auth/lock_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(ShieldFrameApp());
}

class ShieldFrameApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shield Frame',
      theme: AppTheme.darkTheme,
      home: LockScreen(),
    );
  }
}\n