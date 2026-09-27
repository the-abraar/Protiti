import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'hardware_sos_method_channel.dart';

abstract class HardwareSosPlatform extends PlatformInterface {
  HardwareSosPlatform() : super(token: _token);

  static final Object _token = Object();
  static HardwareSosPlatform _instance = MethodChannelHardwareSos();

  static HardwareSosPlatform get instance => _instance;

  static set instance(HardwareSosPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Stream<String> get sosEvents {
    throw UnimplementedError('sosEvents has not been implemented.');
  }
}
