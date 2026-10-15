import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'background_sos_service.dart';
import 'database_service.dart';
import 'evidence_files.dart';
import 'secure_store.dart';

class WipeService {
  /// Destroys all app data. Keys go before files, so anything a later step
  /// fails to delete is already unreadable.
  static Future<void> executeNuclearWipe() async {
    // First, so even a wipe cut short never leads back to the setup screen.
    try {
      await (await _wipedMarker()).create(recursive: true);
    } catch (_) {}
    await DatabaseService.closeAll();
    try {
      await secureStore.deleteAll();
    } catch (_) {}
    await BackgroundSosService.afterWipe();
    await wipeFiles(
      dbDir: Directory(await getDatabasesPath()),
      docsDir: await getApplicationDocumentsDirectory(),
      tempDir: await getTemporaryDirectory(),
    );
  }

  /// An empty file, outside the keychain on purpose: iOS keeps keychain items
  /// after an uninstall, but app files go with it, so a reinstall can set up again.
  static Future<File> _wipedMarker() async =>
      File(join((await getApplicationSupportDirectory()).path, '.c'));

  /// True once the wipe has run on this install. Whoever typed the wipe code,
  /// now or later, then only ever sees a plain calculator, never the setup screen.
  static Future<bool> hasWiped() async => (await _wipedMarker()).exists();

  @visibleForTesting
  static Future<void> wipeFiles({
    required Directory dbDir,
    required Directory docsDir,
    required Directory tempDir,
  }) async {
    for (final name in DatabaseService.fileNames) {
      for (final suffix in const ['', '-wal', '-journal', '-shm']) {
        await _delete(File(join(dbDir.path, '$name$suffix')));
      }
    }
    final exts = [evidenceExt, recordingExt, ...legacyEvidenceExts];
    for (final entity in await _list(docsDir)) {
      if (entity is File && exts.any(entity.path.endsWith)) {
        await _delete(entity);
      }
    }
    // Temp holds exported PDFs, image-picker copies and decrypted playback files.
    for (final entity in await _list(tempDir)) {
      await _delete(entity);
    }
  }

  static Future<List<FileSystemEntity>> _list(Directory dir) async {
    try {
      return await dir.list().toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> _delete(FileSystemEntity entity) async {
    try {
      if (await entity.exists()) await entity.delete(recursive: true);
    } catch (_) {}
  }
}
