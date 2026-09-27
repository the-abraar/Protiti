import 'hardware_sos_platform_interface.dart';

class HardwareSos {
  Stream<String> get sosEvents {
    return HardwareSosPlatform.instance.sosEvents;
  }
}
