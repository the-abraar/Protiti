import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../data/services/auth_service.dart';

/// First-run screen: the user must choose a real PIN and a different duress PIN.
class PinSetupScreen extends StatefulWidget {
  final AuthService authService;
  final VoidCallback onDone;
  const PinSetupScreen({super.key, required this.authService, required this.onDone});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  final _real = TextEditingController();
  final _duress = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _real.dispose();
    _duress.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final err = AuthService.validatePins(_real.text, _duress.text);
    if (err != null) return setState(() => _error = err);
    await widget.authService.setPins(realPin: _real.text, duressPin: _duress.text);
    widget.onDone();
  }

  Widget _field(TextEditingController c, String label) => TextField(
        controller: c,
        obscureText: true,
        keyboardType: TextInputType.number,
        maxLength: 4,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(labelText: label),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Set up your PINs')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            const Text('Choose a real PIN (opens your vault) and a different duress PIN (opens a decoy vault). Do not use 0000.'),
            _field(_real, 'Real PIN (4 digits)'),
            _field(_duress, 'Duress PIN (4 digits)'),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _save, child: const Text('Save')),
          ]),
        ),
      );
}
