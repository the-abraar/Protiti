import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'hardware_sos_platform_interface.dart';

class MethodChannelHardwareSos extends HardwareSosPlatform {
  @visibleForTesting
  final eventChannel = const EventChannel('hardware_sos_events');

  @override
  Stream<String> get sosEvents {
    return eventChannel.receiveBroadcastStream().cast<String>();
  }
}
