import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protiti/data/services/encryption_service.dart';
import 'package:protiti/ui/features/vault/secure_audio_player.dart';

import 'helpers/app_harness.dart';
import 'helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final storage = FakeSecureStorage();
  const id = 'player-under-test';
  const events = 'xyz.luan/audioplayers/events/$id';
  final calls = <String>[];
  late Directory root;

  setUp(() {
    storage
      ..store.clear()
      ..install();
    root = installTempPaths();
    calls.clear();
    // Stand-in for the audioplayers plugin: accepts every call and reports a
    // source as ready, as the platform does.
    messenger.setMockMethodCallHandler(const MethodChannel('xyz.luan/audioplayers'), (call) async {
      calls.add(call.method);
      if (call.method == 'setSourceUrl') {
        messenger.handlePlatformMessage(
            events, const StandardMethodCodec().encodeSuccessEnvelope({'event': 'audio.onPrepared', 'value': true}), (_) {});
      }
      return call.method == 'getCurrentPosition' ? 1500 : null;
    });
    messenger.setMockMethodCallHandler(const MethodChannel('xyz.luan/audioplayers.global'), (_) async => null);
    messenger.setMockMethodCallHandler(const MethodChannel(events), (_) async => null);
  });
  tearDown(() {
    storage.uninstall();
    for (final c in ['xyz.luan/audioplayers', 'xyz.luan/audioplayers.global', events]) {
      messenger.setMockMethodCallHandler(MethodChannel(c), null);
    }
    root.deleteSync(recursive: true);
  });

  List<FileSystemEntity> plaintext() {
    final dir = Directory('${root.path}/tmp/playback');
    return dir.existsSync() ? dir.listSync() : const [];
  }

  testWidgets('the decrypted copy exists only while playing', (tester) async {
    final enc = File('${root.path}/docs/rec.enc');
    await tester.runAsync(() => EncryptionService().encryptFile(File('${root.path}/rec.m4a')..writeAsBytesSync([1, 2, 3]), enc));
    await tester.pumpWidget(harness(SecureAudioPlayer(filePath: enc.path, player: AudioPlayer(playerId: id))));
    expect(plaintext(), isEmpty, reason: 'nothing decrypted until she presses play');

    // File work runs on the real event loop and the player's events in the
    // test's fake zone, so let each side run in turn.
    Future<void> settle() async {
      for (var i = 0; i < 15; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
        await tester.pump();
      }
    }

    Future<void> press(String tooltip) async {
      await tester.tap(find.byTooltip(tooltip));
      await settle();
    }

    await press('Play');
    expect(plaintext(), hasLength(1));
    expect((plaintext().single as File).readAsBytesSync(), [1, 2, 3]);
    expect(calls, containsAllInOrder(['setSourceUrl', 'seek', 'resume']));

    await press('Pause');
    expect(plaintext(), isEmpty);
    expect(calls, containsAllInOrder(['getCurrentPosition', 'stop']));

    await press('Play');
    expect(plaintext(), hasLength(1));
    await messenger.handlePlatformMessage(
        events, const StandardMethodCodec().encodeSuccessEnvelope({'event': 'audio.onComplete'}), (_) {});
    await settle();
    expect(plaintext(), isEmpty, reason: 'deleted at the end of the track');

    await press('Play');
    expect(plaintext(), hasLength(1));
    await tester.pumpWidget(const SizedBox());
    expect(plaintext(), isEmpty, reason: 'deleted when the screen closes');
  });
}
