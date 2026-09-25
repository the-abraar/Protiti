import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
// Note: flutter_background_service_android doesn't exist separately anymore, the android platform is integrated into the core package.
// Actually, it's just flutter_background_service for the core classes.
import 'shake_to_sos_service.dart';
import '../../domain/use_cases/trigger_panic.dart';
import 'location_service.dart';
import '../repositories/contact_repository.dart';
import 'database_service.dart';
import 'geofence_service.dart';
import 'secure_audio_service.dart';

class BackgroundSosService {
  static Future<void> initializeService() async {
    final service = FlutterBackgroundService();
    
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        isForegroundMode: true,
        // Disguise the persistent foreground notification exactly like our stealth alerts
        notificationChannelId: 'sys_update',
        initialNotificationTitle: 'System Service',
        initialNotificationContent: 'Running background optimizations...',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
    
    await service.startService();
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    final triggerPanic = TriggerPanicUseCase(
      LocationService(),
      contactRepository: ContactRepository(DatabaseService()),
      audioService: SecureAudioService(),
    );
    // Initialize our dependencies inside this background isolate
    final shakeService = ShakeToSosService(triggerPanic);
    shakeService.startListening();
    
    final geofenceService = GeofenceService(triggerPanic);
    geofenceService.startGeofenceMonitoring();
    
    service.on('stopService').listen((event) {
      shakeService.stopListening();
      geofenceService.stopGeofenceMonitoring();
      service.stopSelf();
    });
  }

  @pragma('vm:entry-point')
  static bool onIosBackground(ServiceInstance service) {
    return true;
  }
}
