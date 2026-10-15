import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/explain_permission.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/background_sos_service.dart';
import '../../../data/services/native_sms_service.dart';
import '../../../data/services/silent_alert_service.dart';
import '../../../domain/use_cases/trigger_panic.dart';
import '../auth/pin_setup_screen.dart';
import 'battery_guide_screen.dart';
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
  // SOS (pro-sos): each trigger and the second-PIN alert, all off by default.
  final Map<SosTrigger, bool> _triggers = {
    for (final t in SosTrigger.values) t: false,
  };
  bool _triggersReady = true;
  bool _duressAlert = false;
  bool _loading = true;

  /// iOS allows neither background triggers nor silent SMS.
  static bool get _android => defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    var biometric = false;
    final triggers = <SosTrigger, bool>{};
    var ready = true;
    var duressAlert = false;
    if (!widget.isDecoy) {
      try {
        biometric = await _auth.isBiometricEnabled();
      } catch (_) {}
      for (final t in SosTrigger.values) {
        triggers[t] = await BackgroundSosService.isOn(t);
      }
      if (triggers.containsValue(true)) {
        ready = await BackgroundSosService.ready();
      }
      duressAlert = await DuressAlert.isOn();
    }
    if (mounted) {
      setState(() {
        _biometric = biometric;
        _triggers.addAll(triggers);
        _triggersReady = ready;
        _duressAlert = duressAlert;
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
          location == LocationPermission.whileInUse ||
          location == LocationPermission.always;
      return hasLocation &&
          (!Platform.isAndroid || await NativeSmsService.hasPermission());
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _requestSosPermissions() async {
    try {
      final sms =
          !Platform.isAndroid || await NativeSmsService.requestPermission();
      final location = await Geolocator.requestPermission();
      return sms &&
          (location == LocationPermission.whileInUse ||
              location == LocationPermission.always);
    } catch (_) {
      return false;
    }
  }

  Future<void> _askSosPermissions() async {
    await explainThenRequest(
      context,
      title: 'SOS text and location',
      body:
          'When you hold the SOS button, this app texts your trusted contacts with where '
          'you are. If the screen goes off or you leave it during the ${sosCancelWindow.inSeconds} '
          'seconds after, it sends at once. For that, the phone will now ask to let it send SMS '
          'and see your location. '
          'Nothing is sent until you trigger an SOS. Android may keep a copy of each text in '
          'your Messages app, where anyone who opens it can read it.',
      request: _requestSosPermissions,
    );
    if (mounted) setState(() {});
  }

  static const _triggerText = {
    SosTrigger.power: (
      title: 'Power button SOS',
      gesture: 'Press the power button 4 times quickly',
      risk: 'Quick presses in a bag or pocket can set it off.',
    ),
    SosTrigger.shake: (
      title: 'Shake SOS',
      gesture: 'Shake the phone hard for about two seconds',
      risk: 'A bumpy rickshaw or CNG ride can set it off.',
    ),
  };

  Future<void> _onTrigger(SosTrigger t, bool value) async {
    if (!value) {
      await BackgroundSosService.disable(t);
      if (mounted) setState(() => _triggers[t] = false);
      return;
    }
    final text = _triggerText[t]!;
    final on = await explainThenRequest(
      context,
      title: text.title,
      body:
          '${text.gesture} and, after ${sosCancelWindow.inSeconds} seconds, your trusted '
          'contacts get your SOS text with your location. ${text.risk} Two short buzzes mean it '
          'is about to send. To stop a mistake, unlock the phone and tap Cancel on the notice in '
          'the notification shade within those ${sosCancelWindow.inSeconds} seconds. One long '
          'buzz means it was sent. Three long buzzes mean it was not sent to everyone, so call 999.\n\n'
          'The notices stay plain so someone holding your phone learns little: '
          '"$sosCountdownNotice", then "Done: 2 of 2." or "$sosNotSentNotice", with a Call button '
          'that opens the dialer with 999. Nothing shows on the lock screen and nothing pops up.\n\n'
          'A small service keeps running, with a notice that says "$sosServiceNotice" The phone '
          'will ask to send SMS, show notices, see your location and use the microphone. It '
          'records two minutes of sound as evidence; while it does, Android shows a green '
          'microphone dot and lists this app as using the microphone. That cannot be hidden. '
          'Android may keep a copy of each text in your Messages app.\n\n'
          'To try it, tap Practice run below first: your contacts then get a test text instead.',
      request: () => BackgroundSosService.enable(t),
    );
    if (!mounted) return;
    setState(() {
      _triggers[t] = on;
      if (on) _triggersReady = true;
    });
    if (on) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const BatteryGuideScreen()),
      );
    }
  }

  Future<void> _armPractice() async {
    try {
      await SosPractice.arm();
    } catch (_) {
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Practice is on for ${SosPractice.window.inMinutes} minutes. Try your shortcut now.',
        ),
      ),
    );
  }

  Future<void> _onDuressAlert(bool value) async {
    if (!value) {
      await DuressAlert.setOn(false);
      if (mounted) setState(() => _duressAlert = false);
      return;
    }
    final on = await explainThenRequest(
      context,
      title: 'Silent alert with your second PIN',
      body:
          'When you open the app with your second PIN, your trusted contacts get your SOS '
          'text and nothing on screen changes: no notice, no buzz, no recording. There is no '
          'time to cancel. You will not see whether it went; the next time you open with your '
          'real PIN, the SOS tab tells you. Android may keep a copy of the text in your '
          'Messages app, where someone holding your phone could see it.',
      request: () async {
        if (!await NativeSmsService.hasPermission() &&
            !await NativeSmsService.requestPermission()) {
          return false;
        }
        await DuressAlert.setOn(true);
        return true;
      },
    );
    if (mounted) setState(() => _duressAlert = on);
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
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Codes changed.')));
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
                  leading: Icon(
                    Icons.calculate_outlined,
                    color: AppTheme.brandSecondary,
                  ),
                  title: Text('Opens as a calculator'),
                  subtitle: Text(
                    'It always works as a normal calculator. Type your PIN, then "=", to get in.',
                  ),
                ),
                if (!widget.isDecoy) ...[
                  const Divider(height: 32),
                  ListTile(
                    leading: const Icon(
                      Icons.people_outline,
                      color: AppTheme.brandSecondary,
                    ),
                    title: const Text('Trusted contacts'),
                    subtitle: const Text(
                      'Who gets your SOS text. Send each a test text.',
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ContactsScreen()),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.sms_outlined,
                      color: AppTheme.brandSecondary,
                    ),
                    title: const Text('SOS text and location'),
                    subtitle: const Text(
                      'Lets the SOS text your contacts with your location. A copy may stay in '
                      'your Messages app.',
                    ),
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
                  if (_android) ...[
                    for (final t in SosTrigger.values)
                      SwitchListTile(
                        activeThumbColor: AppTheme.brandSecondary,
                        title: Text(_triggerText[t]!.title),
                        subtitle: Text(
                          _triggers[t]! && !_triggersReady
                              ? 'Not working: a permission was turned off. Turn this off and on again.'
                              : 'Off by default. ${_triggerText[t]!.gesture}, then ${sosCancelWindow.inSeconds} s to cancel.',
                          style: _triggers[t]! && !_triggersReady
                              ? const TextStyle(color: AppTheme.panicRed)
                              : null,
                        ),
                        value: _triggers[t]!,
                        onChanged: (v) => _onTrigger(t, v),
                      ),
                    if (_triggers.values.any((on) => on))
                      ListTile(
                        leading: const Icon(
                          Icons.play_circle_outline,
                          color: AppTheme.brandSecondary,
                        ),
                        title: const Text('Practice run'),
                        subtitle: Text(
                          'For the next ${SosPractice.window.inMinutes} minutes, a shortcut texts your '
                          'contacts "${TriggerPanicUseCase.practiceHead}" instead of the SOS.',
                        ),
                        onTap: _armPractice,
                      ),
                    ListTile(
                      leading: const Icon(
                        Icons.battery_alert_outlined,
                        color: AppTheme.brandSecondary,
                      ),
                      title: const Text('Keep SOS shortcuts working'),
                      subtitle: const Text(
                        'Battery settings that stop them on some phones.',
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const BatteryGuideScreen(),
                        ),
                      ),
                    ),
                    SwitchListTile(
                      activeThumbColor: AppTheme.brandSecondary,
                      title: const Text('Silent alert with your second PIN'),
                      subtitle: const Text(
                        'Off by default. Opening with your second PIN quietly texts your contacts.',
                      ),
                      value: _duressAlert,
                      onChanged: _onDuressAlert,
                    ),
                  ] else
                    const ListTile(
                      leading: Icon(
                        Icons.info_outline,
                        color: AppTheme.brandSecondary,
                      ),
                      title: Text('On iPhone'),
                      subtitle: Text(
                        'The SOS opens Messages and you press Send. iPhone does not allow '
                        'power-button or shake SOS, or texts sent without you seeing them.',
                      ),
                    ),
                  const Divider(height: 32),
                  ListTile(
                    leading: const Icon(
                      Icons.pin_outlined,
                      color: AppTheme.brandSecondary,
                    ),
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
