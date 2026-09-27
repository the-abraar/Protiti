import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../../data/services/disguise_settings_service.dart';
import '../../../data/services/native_sms_service.dart';
import 'dart:io';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _alwaysLaunchAsCalculator = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final value = await DisguiseSettingsService.getAlwaysLaunchAsCalculator();
    if (mounted) {
      setState(() {
        _alwaysLaunchAsCalculator = value;
        _loading = false;
      });
    }
  }

  Future<void> _onToggle(bool value) async {
    setState(() => _alwaysLaunchAsCalculator = value);
    await DisguiseSettingsService.setAlwaysLaunchAsCalculator(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Safety Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SwitchListTile(
                  activeThumbColor: AppTheme.brandSecondary,
                  title: const Text('Always launch as calculator'),
                  subtitle: const Text(
                    'Skip the Protiti lock screen entirely and always open '
                    'straight into the calculator disguise. Enter your PIN '
                    'followed by "=" to reach either vault from there.',
                  ),
                  value: _alwaysLaunchAsCalculator,
                  onChanged: _onToggle,
                ),
                const Divider(height: 32),
                if (Platform.isAndroid)
                  ListTile(
                    leading: const Icon(Icons.sms_outlined, color: AppTheme.brandSecondary),
                    title: const Text('Silent SOS text permission'),
                    subtitle: const Text(
                      'Lets the offline Panic alert message emergency contacts '
                      'directly, without opening the Messages app on-screen.',
                    ),
                    trailing: FutureBuilder<bool>(
                      future: NativeSmsService.hasPermission(),
                      builder: (context, snapshot) {
                        final granted = snapshot.data ?? false;
                        return TextButton(
                          onPressed: granted
                              ? null
                              : () async {
                                  await NativeSmsService.requestPermission();
                                  if (mounted) setState(() {});
                                },
                          child: Text(granted ? 'Granted' : 'Grant'),
                        );
                      },
                    ),
                  ),
              ],
            ),
    );
  }
}
