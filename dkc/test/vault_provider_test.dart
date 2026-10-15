import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:protiti/data/services/database_service.dart';
import 'package:protiti/data/repositories/evidence_repository.dart';
import 'package:protiti/data/services/encryption_service.dart';
import 'package:protiti/ui/features/vault/vault_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'helpers/fakes.dart';

/// Answers every query with [rows].
class _RowsDatabase implements Database {
  final List<Map<String, Object?>> rows;
  _RowsDatabase(this.rows);

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async => rows;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final storage = FakeSecureStorage();
  late Directory root;
  // A JPEG start with EXIF, as the camera hands it over.
  final original = [
    0xFF,
    0xD8,
    0xFF,
    0xE1,
    ...utf8.encode('Exif GPS 23.81N 90.41E'),
    0xFF,
    0xD9,
  ];

  setUp(() {
    storage
      ..store.clear()
      ..install();
    root = installTempPaths();
  });
  tearDown(() {
    storage.uninstall();
    root.deleteSync(recursive: true);
    DatabaseService.debugSetHandles();
  });

  XFile picked() => XFile(
    (File(
      '${root.path}/tmp/image_picker_1.jpg',
    )..writeAsBytesSync(original)).path,
  );

  for (final (source, captureSource) in [
    (ImageSource.camera, 'camera'),
    (ImageSource.gallery, 'gallery'),
    (ImageSource.gallery, 'screenshot'),
  ]) {
    test(
      'a $captureSource image is stored byte for byte, hashed before anything else',
      () async {
        final repo = FakeEvidenceRepository();
        final cache = picked();
        ImageSource? asked;
        final vault = VaultProvider(
          repo,
          isDecoy: false,
          pickImage: (s) async {
            asked = s;
            return cache;
          },
        );

        final saved = await vault.addImage(
          source,
          captureSource: captureSource,
        );

        expect(asked, source);
        expect(saved, isNotNull);
        expect(repo.items.single.id, saved!.id);
        expect(saved.type, 'image');
        expect(saved.captureSource, captureSource);
        expect(saved.sha256, sha256.convert(original).toString());
        expect(
          saved.capturedAt.difference(DateTime.now().toUtc()).inMinutes,
          0,
        );
        expect(
          await EncryptionService().decryptToBytes(File(saved.filePath!)),
          original,
          reason: 'no re-encode, EXIF kept',
        );
        expect(
          File(cache.path).existsSync(),
          isFalse,
          reason: 'picker copy deleted',
        );
        expect(vault.pickerOpen, isFalse);
      },
    );
  }

  test('the picker flag is up only while the picker is open', () async {
    late bool during;
    late VaultProvider vault;
    vault = VaultProvider(
      FakeEvidenceRepository(),
      isDecoy: false,
      pickImage: (_) async {
        during = vault.pickerOpen;
        return null;
      },
    );
    expect(
      await vault.addImage(ImageSource.camera, captureSource: 'camera'),
      isNull,
    );
    expect(during, isTrue);
    expect(vault.pickerOpen, isFalse);
  });

  test('her details are added without touching the hash', () async {
    final repo = FakeEvidenceRepository();
    final vault = VaultProvider(
      repo,
      isDecoy: false,
      pickImage: (_) async => picked(),
    );
    final saved = (await vault.addImage(
      ImageSource.camera,
      captureSource: 'camera',
    ))!;

    await vault.updateDetails(
      saved,
      description: 'Threat in Messenger',
      platform: 'Facebook',
      url: 'https://fb.com/x',
    );

    final row = repo.items.single;
    expect(
      (row.description, row.platform, row.url),
      ('Threat in Messenger', 'Facebook', 'https://fb.com/x'),
    );
    expect(row.sha256, saved.sha256);
    expect(row.captureSource, 'camera');
  });

  test('a typed note is type text, with the hash of its text', () async {
    final repo = FakeEvidenceRepository();
    await VaultProvider(
      repo,
      isDecoy: false,
    ).addNote('সে হুমকি দিয়েছে', platform: 'WhatsApp');
    final note = repo.items.single;
    expect(note.type, 'text');
    expect(note.captureSource, 'note');
    expect(
      note.sha256,
      sha256.convert(utf8.encode('সে হুমকি দিয়েছে')).toString(),
    );
    expect(note.platform, 'WhatsApp');
    expect(note.url, isNull);
  });

  test(
    'notes typed in older builds, saved as screenshot with no file, read back as text',
    () async {
      DatabaseService.debugSetHandles(
        real: _RowsDatabase([
          {
            'req_id': 'n',
            'mime_type': 'screenshot',
            'uri_path': null,
            'ext_url': null,
            'blob_ref': 'old note',
            'meta_tags': '',
            'timestamp': '2026-09-01T10:00:00.000',
          },
          {
            'req_id': 'i',
            'mime_type': 'image',
            'uri_path': '/x.enc',
            'ext_url': null,
            'blob_ref': 'photo',
            'meta_tags': '',
            'timestamp': '2026-09-01T10:00:00.000',
          },
        ]),
      );
      final items = await EvidenceRepository(DatabaseService()).getEvidence();
      expect(items.map((e) => e.type), ['text', 'image']);
      expect(items.first.sha256, isNull);
      expect(items.first.captureSource, isNull);
    },
  );
}
