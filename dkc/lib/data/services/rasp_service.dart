import 'package:freerasp/freerasp.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'wipe_service.dart';

import 'dart:io';

class RaspService {
  /// Initializes the Runtime Application Self-Protection (RASP) engine.
  /// This monitors the live RAM space for debuggers, emulators, and hooking frameworks (Frida).
  static Future<void> initializeRasp() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return;
    }
    final config = TalsecConfig(
      androidConfig: AndroidConfig(
        packageName: 'com.protiti.protiti',
        signingCertHashes: ['lkK94jMU4dKwO3ec3Z6r6q+3OKnwpVY+3h/DeoxriUM='],
        // Allow direct ADB/sideloaded installs (not just Play Store)
        supportedStores: ['adb'],
      ),
      iosConfig: IOSConfig(
        bundleIds: ['com.protiti.protiti'],
        teamId: 'INSERT_TEAM_ID_HERE',
      ),
      watcherMail: 'security@typesafe.ai',
      isProd: kReleaseMode,
    );

    // Setup the Threat Callbacks
    final callback = ThreatCallback(
      onAppIntegrity: () => _detonate('App signature modified'),
      // onDebug fires when developer mode is on — do NOT detonate, only log.
      // Detonating here crashes the app during normal testing/sideloading.
      onDebug: () => debugPrint('[RASP] Debugger / developer mode detected'),
      onHooks: () => _detonate('Frida/Xposed hooking framework detected in RAM'),
      onSimulator: () => debugPrint('[RASP] Emulator detected'),
      onPrivilegedAccess: () => debugPrint('Root/Jailbreak warning logged'),
      onObfuscationIssues: () => debugPrint('Obfuscation missing'),
      onDeviceBinding: () => debugPrint('Device binding failed'),
      onDeviceID: () => debugPrint('Device ID tampered'),
      onSecureHardwareNotAvailable: () => debugPrint('Hardware keystore offline'),
    );

    Talsec.instance.attachListener(callback);
    await Talsec.instance.start(config);
  }

  /// Executes the Scorched-Earth policy if active RAM tampering is detected.
  static Future<void> _detonate(String threatType) async {
    // 1. Immediately shred the SQLite DB and Document Storage to protect the evidence
    await WipeService.executeNuclearWipe();
    
    // 2. Force an unrecoverable hard crash to kill the compromised memory process
    SystemChannels.platform.invokeMethod('SystemNavigator.pop');
  }
}
