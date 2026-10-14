import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:protiti/data/services/native_sms_service.dart';
import 'package:protiti/data/services/secure_store.dart';
import 'package:protiti/data/services/wipe_service.dart';

import 'helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the wipe also clears the SOS status notice (N9)', () async {
    final storage = FakeSecureStorage()..install();
    final root = installTempPaths();
    final calls = <String>[];
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(NativeSmsService.channel, (call) async => calls.add(call.method));
    addTearDown(() {
      messenger.setMockMethodCallHandler(NativeSmsService.channel, null);
      storage.uninstall();
      root.deleteSync(recursive: true);
    });
    storage.store[StoreKeys.powerSosOn] = 'true';

    await WipeService.executeNuclearWipe();
    expect(storage.store, isEmpty);
    expect(calls, contains('clearNotice'));
  });

  test('wipe deletes both databases with their -wal/-journal/-shm files and every evidence file', () async {
    final root = Directory.systemTemp.createTempSync('protiti_wipe_');
    final dbDir = Directory('${root.path}/dbs')..createSync();
    final docs = Directory('${root.path}/docs')..createSync();
    final temp = Directory('${root.path}/tmp')..createSync();

    for (final db in ['app_state.db', 'app_cache.db']) {
      for (final suffix in ['', '-wal', '-journal', '-shm']) {
        File('${dbDir.path}/$db$suffix').writeAsStringSync('x');
      }
    }
    for (final name in ['a.enc', 'b.bin', 'c.tmp', 'd.enc_audio', 'e.m4a']) {
      File('${docs.path}/$name').writeAsStringSync('x');
    }
    final unrelated = File('${docs.path}/flutter_assets.txt')..writeAsStringSync('keep');
    File('${temp.path}/dossier.pdf').writeAsStringSync('x');
    Directory('${temp.path}/picker').createSync();

    await WipeService.wipeFiles(dbDir: dbDir, docsDir: docs, tempDir: temp);

    expect(dbDir.listSync(), isEmpty);
    expect(docs.listSync().map((e) => e.path), [unrelated.path]);
    expect(temp.listSync(), isEmpty);
    root.deleteSync(recursive: true);
  });
}
