import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/explain_permission.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/background_sos_service.dart';
import '../../../data/services/native_sms_service.dart';
import '../auth/pin_setup_screen.dart';
import 'contacts_screen.dart';

class SettingsScreen extends StatefulWidget {
  /// The second-PIN view only gets the harmless calculator note.
  final bool isDecoy;
  final AuthService? authService;

  const SettingsScreen({super.key, this.isDecoy = false, this.authService});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final AuthService _auth = widget.authService ?? AuthService();
  bool _biometric = false;
  bool _sosTriggers = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    var biometric = false;
    var sosTriggers = false;
    if (!widget.isDecoy) {
      try {
        biometric = await _auth.isBiometricEnabled();
      } catch (_) {}
      sosTriggers = await BackgroundSosService.isEnabled();
    }
    if (mounted) {
      setState(() {
        _biometric = biometric;
        _sosTriggers = sosTriggers;
        _loading = false;
      });
    }
  }

  Future<void> _onBiometric(bool value) async {
    final ok = await _auth.setBiometricEnabled(value);
    if (mounted) setState(() => _biometric = value && ok);
  }

  static Future<bool> _sosPermissionsGranted() async {
    try {
      final location = await Geolocator.checkPermission();
      final hasLocation =
          location == LocationPermission.whileInUse || location == LocationPermission.always;
      return hasLocation && (!Platform.isAndroid || await NativeSmsService.hasPermission());
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _requestSosPermissions() async {
    try {
      final sms = !Platform.isAndroid || await NativeSmsService.requestPermission();
      final location = await Geolocator.requestPermission();
      return sms &&
          (location == LocationPermission.whileInUse || location == LocationPermission.always);
    } catch (_) {
      return false;
    }
  }

  Future<void> _askSosPermissions() async {
    await explainThenRequest(
      context,
      title: 'SOS text and location',
      body: 'When you hold the SOS button, this app texts your trusted contacts with where '
          'you are. For that, the phone will now ask to let it send SMS and see your location. '
          'Nothing is sent until you trigger an SOS.',
      request: _requestSosPermissions,
    );
    if (mounted) setState(() {});
  }

  Future<void> _onSosTriggers(bool value) async {
    if (!value) {
      await BackgroundSosService.disable();
      if (mounted) setState(() => _sosTriggers = false);
      return;
    }
    final on = await explainThenRequest(
      context,
      title: 'Power button and shake SOS',
      body: 'This keeps a small service running so that pressing the power button three '
          'times, or shaking the phone hard, starts an SOS. The phone will ask for your '
          'location (for the text) and the microphone (it records two minutes of sound as '
          'evidence). It can go off by accident in a bag or a rickshaw.',
      request: BackgroundSosService.enable,
    );
    if (mounted) setState(() => _sosTriggers = on);
  }

  void _changeCodes() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (routeContext) => PinSetupScreen(
          authService: _auth,
          changing: true,
          onDone: () {
            Navigator.pop(routeContext);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Codes changed.')),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const ListTile(
                  leading: Icon(Icons.calculate_outlined, color: AppTheme.brandSecondary),
                  title: Text('Opens as a calculator'),
                  subtitle: Text('It always works as a normal calculator. Type your PIN, then "=", to get in.'),
                ),
                if (!widget.isDecoy) ...[
                  const Divider(height: 32),
                  ListTile(
                    leading: const Icon(Icons.people_outline, color: AppTheme.brandSecondary),
                    title: const Text('Trusted contacts'),
                    subtitle: const Text('Who gets your SOS text. Send each a test text.'),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ContactsScreen()),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.sms_outlined, color: AppTheme.brandSecondary),
                    title: const Text('SOS text and location'),
                    subtitle: const Text('Lets the SOS text your contacts with your location.'),
                    trailing: FutureBuilder<bool>(
                      future: _sosPermissionsGranted(),
                      builder: (context, snapshot) {
                        final granted = snapshot.data ?? false;
                        return TextButton(
                          onPressed: granted ? null : _askSosPermissions,
                          child: Text(granted ? 'Allowed' : 'Allow'),
                        );
                      },
                    ),
                  ),
                  SwitchListTile(
                    activeThumbColor: AppTheme.brandSecondary,
                    title: const Text('Power button and shake SOS'),
                    subtitle: const Text('Off by default. Starts an SOS without opening the app.'),
                    value: _sosTriggers,
                    onChanged: _onSosTriggers,
                  ),
                  const Divider(height: 32),
                  ListTile(
                    leading: const Icon(Icons.pin_outlined, color: AppTheme.brandSecondary),
                    title: const Text('Change codes'),
                    subtitle: const Text('Needs your current real PIN.'),
                    onTap: _changeCodes,
                  ),
                  SwitchListTile(
                    activeThumbColor: AppTheme.brandSecondary,
                    title: const Text('Unlock with fingerprint or face'),
                    subtitle: const Text(
                      'Off by default. Anyone who can force your finger onto the phone could '
                      'open your files. The phone\'s own PIN never works here. To use it, hold "=" '
                      'on the calculator.',
                    ),
                    value: _biometric,
                    onChanged: _onBiometric,
                  ),
                ],
              ],
            ),
    );
  }
}
