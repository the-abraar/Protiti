import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protiti/data/services/encryption_service.dart';
import 'package:protiti/data/services/secure_audio_service.dart';

import 'helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final storage = FakeSecureStorage();
  late Directory dir;

  setUp(() {
    storage
      ..store.clear()
      ..install();
    dir = Directory.systemTemp.createTempSync('protiti_audio_');
  });
  tearDown(() {
    storage.uninstall();
    dir.deleteSync(recursive: true);
  });

  test(
    'a recording left by a killed app is encrypted and filed as evidence at next launch',
    () async {
      File('${dir.path}/left.m4a').writeAsBytesSync([1, 2, 3, 4]);
      File('${dir.path}/other.enc').writeAsStringSync('already safe');
      final repo = FakeEvidenceRepository();

      final recovered = await SecureAudioService().recoverPending(
        repo,
        directory: dir,
        minAge: Duration.zero,
      );

      expect(recovered, 1);
      expect(
        File('${dir.path}/left.m4a').existsSync(),
        isFalse,
        reason: 'no plaintext left',
      );
      final row = repo.items.single;
      expect(row.type, 'audio');
      expect(row.captureSource, 'audio');
      expect(row.filePath, endsWith('.enc'));
      expect(
        row.sha256,
        sha256.convert([1, 2, 3, 4]).toString(),
        reason: 'hash of the recording, not the ciphertext',
      );
      expect(await EncryptionService().decryptToBytes(File(row.filePath!)), [
        1,
        2,
        3,
        4,
      ]);
    },
  );

  test('a recording still being written is left for the next launch', () async {
    File('${dir.path}/live.m4a').writeAsBytesSync([1]);
    final repo = FakeEvidenceRepository();
    expect(await SecureAudioService().recoverPending(repo, directory: dir), 0);
    expect(File('${dir.path}/live.m4a').existsSync(), isTrue);
    expect(repo.items, isEmpty);
  });

  test('playback decrypts into its own temp folder', () async {
    final root = installTempPaths();
    addTearDown(() => root.deleteSync(recursive: true));
    final enc = File('${dir.path}/rec.enc');
    await EncryptionService().encryptFile(
      File('${dir.path}/rec.m4a')..writeAsBytesSync([9, 8, 7]),
      enc,
    );

    final copy = await SecureAudioService().decryptForPlayback(enc.path);

    expect(copy.parent.path, '${root.path}/tmp/playback');
    expect(copy.readAsBytesSync(), [9, 8, 7]);
  });
}
