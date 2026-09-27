import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class StealthNotificationService {
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettingsIOS = DarwinInitializationSettings();
    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    await _flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> showStealthNotification({required String event}) async {
    // Disguise our background notifications as boring system-level alerts
    const androidDetails = AndroidNotificationDetails(
      'sys_update',
      'System Updates',
      channelDescription: 'Core system updates and syncing',
      importance: Importance.low, // Prevent pop-up heads-up display
      priority: Priority.low,
      showWhen: false,
    );
    
    const platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: false, presentSound: false),
    );

    // Map critical internal vault events to highly obfuscated, boring system messages
    String title = 'System Service';
    String body = 'Running background optimizations...';
    
    if (event == 'backup_complete') {
      title = 'Google Play Services';
      body = 'App storage optimization complete.';
    } else if (event == 'ai_analysis_done') {
      title = 'Android System';
      body = 'Device cache cleared successfully.';
    } else if (event == 'sos_sent') {
      title = 'Network Configuration';
      body = 'VoLTE carrier settings updated.';
    }

    await _flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecond,
      title,
      body,
      platformDetails,
    );
  }
}
