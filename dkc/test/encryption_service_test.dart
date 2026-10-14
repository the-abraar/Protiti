import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protiti/data/services/encryption_service.dart';
import 'package:protiti/data/services/secure_store.dart';

import 'helpers/fakes.dart';

/// Writes a file the way builds before Oct 2026 did: AES-CTR over the base64
/// of the bytes, stored as `iv:ciphertext` text, no authentication tag.
Future<void> writeLegacy(File file, List<int> bytes, FakeSecureStorage storage) async {
  final stored = storage.store.putIfAbsent(StoreKeys.evidenceKey, () => base64UrlEncode(Key.fromSecureRandom(32).bytes));
  final key = Key.fromBase64(stored);
  final iv = IV.fromSecureRandom(16);
  final ct = Encrypter(AES(key)).encrypt(base64Encode(bytes), iv: iv);
  file.writeAsStringSync('${iv.base64}:${ct.base64}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final storage = FakeSecureStorage();
  late Directory dir;
  final service = EncryptionService();
  // Three full chunks and a partial one.
  final big = Uint8List.fromList(List.generate(EncryptionService.chunkSize * 3 + 1234, (i) => i * 31 % 251));

  setUp(() {
    storage
      ..store.clear()
      ..install();
    dir = Directory.systemTemp.createTempSync('protiti_enc_');
  });
  tearDown(() {
    storage.uninstall();
    dir.deleteSync(recursive: true);
  });

  File f(String name) => File('${dir.path}/$name');

  test('a multi-chunk file round-trips and the hash is of the original bytes', () async {
    f('plain').writeAsBytesSync(big);
    final hash = await service.encryptFile(f('plain'), f('x.enc'));

    expect(hash, sha256.convert(big).toString());
    expect(f('x.enc').readAsBytesSync().sublist(0, 4), [0, 0x50, 0x52, 0x54]);
    expect(await service.decryptToBytes(f('x.enc')), big);
    await service.decryptToFile(f('x.enc'), f('out'));
    expect(f('out').readAsBytesSync(), big);
  });

  test('an empty file round-trips', () async {
    f('plain').writeAsBytesSync([]);
    expect(await service.encryptFile(f('plain'), f('x.enc')), sha256.convert([]).toString());
    expect(await service.decryptToBytes(f('x.enc')), isEmpty);
  });

  test('a changed byte, a dropped last chunk or a swapped chunk fails to decrypt', () async {
    f('plain').writeAsBytesSync(big);
    await service.encryptFile(f('plain'), f('x.enc'));
    final good = f('x.enc').readAsBytesSync();
    const sealed = 12 + EncryptionService.chunkSize + 16;

    final flipped = Uint8List.fromList(good)..[100] ^= 1;
    f('flip.enc').writeAsBytesSync(flipped);
    await expectLater(service.decryptToBytes(f('flip.enc')), throwsA(anything));

    f('cut.enc').writeAsBytesSync(good.sublist(0, 21 + sealed * 3));
    await expectLater(service.decryptToBytes(f('cut.enc')), throwsA(anything));

    final swapped = [
      ...good.sublist(0, 21),
      ...good.sublist(21 + sealed, 21 + sealed * 2),
      ...good.sublist(21, 21 + sealed),
      ...good.sublist(21 + sealed * 2),
    ];
    f('swap.enc').writeAsBytesSync(swapped);
    await expectLater(service.decryptToBytes(f('swap.enc')), throwsA(anything));
  });

  test('an old AES-CTR file still opens and is rewritten as GCM on first read', () async {
    final photo = [0xFF, 0xD8, 0xFF, 0xE1, ...utf8.encode('Exif original bytes')];
    await writeLegacy(f('old.enc'), photo, storage);

    expect(await service.decryptToBytes(f('old.enc')), photo);
    expect(f('old.enc').readAsBytesSync().sublist(0, 4), [0, 0x50, 0x52, 0x54], reason: 'migrated');
    expect(await service.decryptToBytes(f('old.enc')), photo, reason: 'still opens after migration');
    expect(dir.listSync().where((e) => e.path.endsWith('.tmp')), isEmpty);
  });

  test('an old audio file streams to a file and is migrated', () async {
    await writeLegacy(f('old.enc'), big, storage);
    await service.decryptToFile(f('old.enc'), f('out'));
    expect(f('out').readAsBytesSync(), big);
    expect(await service.decryptToBytes(f('old.enc')), big);
  });

  test('if the rewrite fails the old file is left untouched', () async {
    await writeLegacy(f('old.enc'), [1, 2, 3], storage);
    final before = f('old.enc').readAsStringSync();
    // A directory where the temp file would go makes the rewrite fail.
    final ro = Directory('${dir.path}/ro')..createSync();
    final old = File('${ro.path}/old.enc')..writeAsStringSync(before);
    await Process.run('chmod', ['555', ro.path]);
    addTearDown(() => Process.runSync('chmod', ['755', ro.path]));

    expect(await service.decryptToBytes(old), [1, 2, 3]);
    expect(old.readAsStringSync(), before);
  });
}
