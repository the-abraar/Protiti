import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hardware_sos/hardware_sos_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final MethodChannelHardwareSos platform = MethodChannelHardwareSos();
  const EventChannel channel = EventChannel('hardware_sos_events');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(channel, MockStreamHandler.inline(
      onListen: (Object? arguments, MockStreamHandlerEventSink events) {
        events.success('triple_press_power_button');
      },
    ));
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(channel, null);
  });

  test('sosEvents forwards native event channel payloads', () async {
    expect(await platform.sosEvents.first, 'triple_press_power_button');
  });
}
