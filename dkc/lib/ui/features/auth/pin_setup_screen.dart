import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../data/services/auth_service.dart';

/// First run, or Settings > Change codes: a real PIN, a second PIN and a wipe
/// code, each typed twice so one typo cannot lock her out. Changing them
/// needs the current real PIN first.
class PinSetupScreen extends StatefulWidget {
  final AuthService authService;
  final VoidCallback onDone;
  final bool changing;

  const PinSetupScreen({
    super.key,
    required this.authService,
    required this.onDone,
    this.changing = false,
  });

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  final _current = TextEditingController();
  final _real = TextEditingController();
  final _realAgain = TextEditingController();
  final _duress = TextEditingController();
  final _duressAgain = TextEditingController();
  final _wipe = TextEditingController();
  final _wipeAgain = TextEditingController();
  String? _error;

  @override
  void dispose() {
    for (final c in [_current, _real, _realAgain, _duress, _duressAgain, _wipe, _wipeAgain]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_real.text != _realAgain.text ||
        _duress.text != _duressAgain.text ||
        _wipe.text != _wipeAgain.text) {
      return setState(() => _error = 'The two entries for a code do not match.');
    }
    final err = AuthService.validatePins(_real.text, _duress.text, _wipe.text);
    if (err != null) return setState(() => _error = err);
    try {
      if (widget.changing) {
        final ok = await widget.authService.changePins(
          currentPin: _current.text,
          realPin: _real.text,
          duressPin: _duress.text,
          wipeCode: _wipe.text,
        );
        if (!ok) {
          if (mounted) setState(() => _error = 'The current PIN is not right.');
          return;
        }
      } else {
        await widget.authService.setPins(
          realPin: _real.text,
          duressPin: _duress.text,
          wipeCode: _wipe.text,
        );
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not save on this phone. Try again.');
      return;
    }
    widget.onDone();
  }

  Widget _field(TextEditingController c, String label) => TextField(
        controller: c,
        obscureText: true,
        keyboardType: TextInputType.number,
        maxLength: 10,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(labelText: label),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.changing ? 'Change your codes' : 'Set up your codes')),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Choose three different codes of 6 to 10 digits.\n'
              '• Real PIN: opens your notes.\n'
              '• Second PIN: opens an ordinary-looking notes space instead. Use it if someone makes you unlock.\n'
              '• Wipe code: deletes everything on this phone at once.\n\n'
              'A forgotten PIN cannot be recovered. Keep the codes somewhere only you can reach.',
            ),
            const SizedBox(height: 16),
            if (widget.changing) _field(_current, 'Current real PIN'),
            _field(_real, 'Real PIN'),
            _field(_realAgain, 'Real PIN again'),
            _field(_duress, 'Second PIN'),
            _field(_duressAgain, 'Second PIN again'),
            _field(_wipe, 'Wipe code'),
            _field(_wipeAgain, 'Wipe code again'),
            if (_error != null)
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _save, child: const Text('Save')),
          ],
        ),
      );
}
