import 'package:flutter_test/flutter_test.dart';
import 'package:hardware_sos/hardware_sos.dart';
import 'package:hardware_sos/hardware_sos_platform_interface.dart';
import 'package:hardware_sos/hardware_sos_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockHardwareSosPlatform
    with MockPlatformInterfaceMixin
    implements HardwareSosPlatform {
  @override
  Stream<String> get sosEvents => Stream.value('triple_press_power_button');
}

void main() {
  final HardwareSosPlatform initialPlatform = HardwareSosPlatform.instance;

  test('$MethodChannelHardwareSos is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelHardwareSos>());
  });

  test('sosEvents', () async {
    HardwareSos hardwareSosPlugin = HardwareSos();
    MockHardwareSosPlatform fakePlatform = MockHardwareSosPlatform();
    HardwareSosPlatform.instance = fakePlatform;

    expect(await hardwareSosPlugin.sosEvents.first, 'triple_press_power_button');
  });
}
