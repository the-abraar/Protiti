import 'package:flutter_test/flutter_test.dart';
import 'package:hardware_sos/hardware_sos.dart';
import 'package:hardware_sos/hardware_sos_platform_interface.dart';
import 'package:hardware_sos/hardware_sos_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockHardwareSosPlatform
    with MockPlatformInterfaceMixin
    implements HardwareSosPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final HardwareSosPlatform initialPlatform = HardwareSosPlatform.instance;

  test('$MethodChannelHardwareSos is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelHardwareSos>());
  });

  test('getPlatformVersion', () async {
    HardwareSos hardwareSosPlugin = HardwareSos();
    MockHardwareSosPlatform fakePlatform = MockHardwareSosPlatform();
    HardwareSosPlatform.instance = fakePlatform;

    expect(await hardwareSosPlugin.getPlatformVersion(), '42');
  });
}
