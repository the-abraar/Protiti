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
        signingCertHashes: ['INSERT_PROD_CERT_HASH_HERE'],
      ),
      iosConfig: IOSConfig(
        bundleIds: ['com.protiti.protiti'],
        teamId: 'INSERT_TEAM_ID_HERE',
      ),
      watcherMail: 'security@typesafe.ai',
      isProd: kReleaseMode, // Ensures aggressive protection in production
    );

    // Setup the Threat Callbacks
    final callback = ThreatCallback(
      onAppIntegrity: () => _detonate('App signature modified'),
      onDebug: () => _detonate('Active debugger attached'),
      onHooks: () => _detonate('Frida/Xposed hooking framework detected in RAM'),
      onSimulator: () => _detonate('Emulator execution detected'),
      onPrivilegedAccess: () => print('Root/Jailbreak warning logged'),
      onObfuscationIssues: () => print('Obfuscation missing'),
      onDeviceBinding: () => print('Device binding failed'),
      onDeviceID: () => print('Device ID tampered'),
      onSecureHardwareNotAvailable: () => print('Hardware keystore offline'),
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
