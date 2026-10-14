import 'package:flutter/material.dart';
import '../../../data/services/native_sms_service.dart';
import '../../core/theme/app_theme.dart';

/// Steps for the phone makers whose battery savers most often stop
/// background apps in Bangladesh.
const _brandSteps = {
  'Xiaomi': 'Turn on Autostart for this app, and set its Battery saver to "No restrictions". '
      'In Recent apps, hold this app\'s card and tap the lock.',
  'Oppo': 'In Settings > Battery, find this app and allow background activity. '
      'Turn on Auto launch (or "Allow auto startup").',
  'Vivo': 'In Settings > Battery > Background power consumption, allow this app. '
      'In i Manager > App manager > Autostart, turn it on.',
  'Realme': 'In Settings > Battery > App battery management, find this app and allow '
      'background activity and Auto launch.',
};

/// Which of the four a phone maker's name belongs to, or null.
String? batteryBrand(String? maker) => switch (maker?.trim().toLowerCase()) {
      'xiaomi' || 'redmi' || 'poco' => 'Xiaomi',
      'oppo' => 'Oppo',
      'vivo' || 'iqoo' => 'Vivo',
      'realme' => 'Realme',
      _ => null,
    };

/// Shown when she turns on a trigger, and from Settings.
class BatteryGuideScreen extends StatefulWidget {
  final Future<String?> Function() maker;
  final Future<bool> Function() openSettings;

  const BatteryGuideScreen({
    super.key,
    this.maker = _deviceMaker,
    this.openSettings = _openBatterySettings,
  });

  static Future<String?> _deviceMaker() async {
    try {
      return await NativeSmsService.channel.invokeMethod<String>('deviceMaker');
    } catch (_) {
      return null;
    }
  }

  static Future<bool> _openBatterySettings() async {
    try {
      return await NativeSmsService.channel.invokeMethod<bool>('openBatterySettings') ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  State<BatteryGuideScreen> createState() => _BatteryGuideScreenState();
}

class _BatteryGuideScreenState extends State<BatteryGuideScreen> {
  String? _brand;

  @override
  void initState() {
    super.initState();
    widget.maker().then((m) {
      if (mounted) setState(() => _brand = batteryBrand(m));
    });
  }

  Future<void> _open() async {
    final messenger = ScaffoldMessenger.of(context);
    if (!await widget.openSettings()) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Opened this app\'s settings. Look for Battery there.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final brand = _brand;
    return Scaffold(
      appBar: AppBar(title: const Text('Keep SOS shortcuts working')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Some phones stop apps running in the background to save battery. Then the '
            'power-button and shake SOS stop working, and nothing tells you.',
          ),
          const SizedBox(height: 16),
          const Text('1. Set this app\'s battery use to "Unrestricted" or "No restrictions".'),
          const SizedBox(height: 8),
          const Text('2. After the phone restarts, open this app once. That turns the shortcuts '
              'back on.'),
          if (brand != null) ...[
            const SizedBox(height: 16),
            Text('On your $brand phone', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_brandSteps[brand]!),
          ],
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _open,
            child: Text(brand == null ? 'Open app settings' : 'Open $brand settings'),
          ),
          const SizedBox(height: 16),
          const Text(
            'Menu names differ between phones and Android versions.',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}
