import 'dart:io';
import 'package:flutter_background_service/flutter_background_service.dart';
// Note: flutter_background_service_android doesn't exist separately anymore, the android platform is integrated into the core package.
// Actually, it's just flutter_background_service for the core classes.
import 'package:geolocator/geolocator.dart';
import 'package:record/record.dart';
import 'shake_to_sos_service.dart';
import '../../domain/use_cases/trigger_panic.dart';
import 'location_service.dart';
import '../repositories/contact_repository.dart';
import 'database_service.dart';
import '../repositories/evidence_repository.dart';
import 'secure_store.dart';
import 'secure_audio_service.dart';
import 'package:hardware_sos/hardware_sos.dart' as hardware_sos;
import 'dart:async';

@pragma('vm:entry-point')
class BackgroundSosService {
  /// Location + microphone, which the Android manifest declares for this
  /// foreground service (`foregroundServiceType="location|microphone"`).
  /// Android refuses to start it unless both are already granted. With
  /// [ask] false this only checks and never shows an OS prompt.
  static Future<bool> _hasRequiredPermissions({required bool ask}) async {
    if (!Platform.isAndroid) return true;
    try {
      var locationPermission = await Geolocator.checkPermission();
      if (ask && locationPermission == LocationPermission.denied) {
        locationPermission = await Geolocator.requestPermission();
      }
      final hasLocation = locationPermission == LocationPermission.always ||
          locationPermission == LocationPermission.whileInUse;
      final hasMic = await AudioRecorder().hasPermission(request: ask);
      return hasLocation && hasMic;
    } catch (_) {
      return false;
    }
  }

  /// Off until she turns it on in Settings, after an explanation (B17).
  static Future<bool> isEnabled() async {
    try {
      return await secureStore.read(key: StoreKeys.sosTriggersOn) == 'true';
    } catch (_) {
      return false;
    }
  }

  /// Asks for the permissions (call only after explaining why) and starts
  /// the service. Returns false, and stays off, if either was refused.
  static Future<bool> enable() async {
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    if (!await _hasRequiredPermissions(ask: true)) return false;
    await secureStore.write(key: StoreKeys.sosTriggersOn, value: 'true');
    await initializeService();
    return true;
  }

  static Future<void> disable() async {
    await secureStore.delete(key: StoreKeys.sosTriggersOn);
    try {
      FlutterBackgroundService().invoke('stopService');
    } catch (_) {}
  }

  /// Called on every lock screen load. Starts the service only if she opted
  /// in and the permissions are still granted; never prompts, never throws.
  static Future<bool> startIfEnabled() async {
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    try {
      if (!await isEnabled() || !await _hasRequiredPermissions(ask: false)) return false;
      await initializeService();
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> initializeService() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return;
    }
    final service = FlutterBackgroundService();
    if (await service.isRunning()) return;

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
      evidenceRepository: EvidenceRepository(DatabaseService()),
    );
    // Initialize our dependencies inside this background isolate
    final shakeService = ShakeToSosService(triggerPanic);
    shakeService.startListening();
    
    StreamSubscription? hardwareSosSubscription;
    if (Platform.isAndroid) {
      final hardwareSos = hardware_sos.HardwareSos();
      hardwareSosSubscription = hardwareSos.sosEvents.listen((event) async {
        if (event == "sos_triggered") {
          await triggerPanic.execute();
        }
      });
    }
    
    service.on('stopService').listen((event) {
      hardwareSosSubscription?.cancel();
      shakeService.stopListening();
      service.stopSelf();
    });
  }

  @pragma('vm:entry-point')
  static bool onIosBackground(ServiceInstance service) {
    return true;
  }
}
