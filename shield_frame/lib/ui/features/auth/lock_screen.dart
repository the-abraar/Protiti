import 'package:flutter/material.dart';
import '../../../data/services/biometric_service.dart';
import '../vault/vault_screen.dart';
import '../../core/theme/app_theme.dart';

class LockScreen extends StatefulWidget {
  @override
  _LockScreenState createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final BiometricService _bioService = BiometricService();
  bool _isCalculatorMode = false;

  void _authenticate() async {
    bool authed = await _bioService.authenticate();
    if (authed && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => VaultScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isCalculatorMode ? 'Calculator' : 'Shield Frame'),
        actions: [
          IconButton(
            icon: Icon(Icons.calculate),
            onPressed: () {
              setState(() {
                _isCalculatorMode = !_isCalculatorMode;
              });
            }
          )
        ]
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.security, size: 80, color: Theme.of(context).colorScheme.primary),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _authenticate,
              child: Text('Unlock Vault'),
            )
          ],
        ),
      ),
    );
  }
}\n