import 'dart:io';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class WipeService {
  /// Executes a scorched-earth forensic wipe of all application data.
  static Future<void> executeNuclearWipe() async {
    // 1. Erase the SQLite Database containing all text/metadata
    final dbPath = await getDatabasesPath();
    final dbFile = File('$dbPath/protiti_vault.db');
    if (dbFile.existsSync()) {
      dbFile.deleteSync();
    }
    
    // 2. Shred all physical encrypted evidence files (Photos/Audio)
    final dir = await getApplicationDocumentsDirectory();
    final files = dir.listSync();
    for (var f in files) {
      if (f.path.endsWith('.enc') || f.path.endsWith('.enc_audio')) {
        f.deleteSync();
      }
    }
    
    // 3. Purge the Hardware Keystore (Destroys AES keys, PINs, and Drafts)
    const storage = FlutterSecureStorage();
    await storage.deleteAll();
  }
}
