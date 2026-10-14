import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:protiti/data/services/wipe_service.dart';

void main() {
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
