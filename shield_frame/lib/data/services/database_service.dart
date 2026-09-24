import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'dart:math';

class DatabaseService {
  static Database? _db;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  static const String _encryptionKeyStorageKey = 'protiti_db_encryption_key';

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  /// Retrieves or generates a secure random 256-bit passphrase for local encryption
  Future<String> getOrGenerateDbKey() async {
    String? key = await _secureStorage.read(key: _encryptionKeyStorageKey);
    if (key == null || key.isEmpty) {
      final random = Random.secure();
      final values = List<int>.generate(32, (i) => random.nextInt(256));
      key = base64UrlEncode(values);
      await _secureStorage.write(key: _encryptionKeyStorageKey, value: key);
    }
    return key;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'protiti_vault.db');
    
    // Obtain secure key from hardware-backed keystore
    final dbKey = await getOrGenerateDbKey();

    return await openDatabase(
      path,
      version: 2,
      onConfigure: (db) async {
        // Configure SQLCipher encryption key via PRAGMA
        await db.rawQuery("PRAGMA key = '$dbKey'");
      },
      onCreate: (db, version) async {
        await _createTables(db);
        await _seedInitialData(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          try {
            await db.execute('ALTER TABLE evidence ADD COLUMN isDecoy INTEGER DEFAULT 0');
          } catch (_) {}
        }
      },
    );
  }

  Future<void> _createTables(Database db) async {
    await db.execute(
      '''CREATE TABLE IF NOT EXISTS evidence (
        id TEXT PRIMARY KEY,
        type TEXT,
        filePath TEXT,
        url TEXT,
        description TEXT,
        metadata TEXT,
        createdAt TEXT,
        isDecoy INTEGER DEFAULT 0
      )''',
    );
    await db.execute(
      '''CREATE TABLE IF NOT EXISTS complaints (
        id TEXT PRIMARY KEY,
        type TEXT,
        title TEXT,
        description TEXT,
        evidenceIds TEXT,
        generatedText TEXT,
        targetPoliceStation TEXT,
        status TEXT,
        createdAt TEXT
      )''',
    );
    await db.execute(
      '''CREATE TABLE IF NOT EXISTS contacts (
        id TEXT PRIMARY KEY,
        name TEXT,
        phone TEXT,
        email TEXT,
        relationship TEXT,
        isEmergency INTEGER DEFAULT 1
      )''',
    );
  }

  Future<void> _seedInitialData(Database db) async {
    // Seed real forensic evidence
    final now = DateTime.now();
    await db.insert('evidence', {
      'id': 'real_ev_1',
      'type': 'screenshot',
      'filePath': null,
      'url': null,
      'description': 'Threatening WhatsApp chat from perpetrator with time-stamped extortion demand',
      'metadata': jsonEncode({'source': 'WhatsApp', 'hash': 'sha256_mock_a8f9c1'}),
      'createdAt': now.subtract(const Duration(days: 1)).toIso8601String(),
      'isDecoy': 0,
    });
    await db.insert('evidence', {
      'id': 'real_ev_2',
      'type': 'audio',
      'filePath': null,
      'url': null,
      'description': 'Recorded audio harassment call with explicit death threat and location stalking',
      'metadata': jsonEncode({'durationSeconds': 94, 'codec': 'm4a'}),
      'createdAt': now.subtract(const Duration(days: 3)).toIso8601String(),
      'isDecoy': 0,
    });
    await db.insert('evidence', {
      'id': 'real_ev_3',
      'type': 'pdf',
      'filePath': null,
      'url': null,
      'description': 'Certified cyber incident log export documenting unauthorized login attempts',
      'metadata': jsonEncode({'pages': 3, 'format': 'pdf'}),
      'createdAt': now.subtract(const Duration(days: 5)).toIso8601String(),
      'isDecoy': 0,
    });

    // Seed decoy innocent evidence (shown when Duress PIN is entered)
    await db.insert('evidence', {
      'id': 'decoy_ev_1',
      'type': 'pdf',
      'filePath': null,
      'url': null,
      'description': 'Fall 2026 University Semester Syllabus & Exam Routine',
      'metadata': jsonEncode({'category': 'Study', 'pages': 2}),
      'createdAt': now.subtract(const Duration(days: 2)).toIso8601String(),
      'isDecoy': 1,
    });
    await db.insert('evidence', {
      'id': 'decoy_ev_2',
      'type': 'text',
      'filePath': null,
      'url': null,
      'description': 'Weekly Grocery Budget & Household Expenses (Dhanmondi)',
      'metadata': jsonEncode({'category': 'Personal', 'status': 'Archived'}),
      'createdAt': now.subtract(const Duration(days: 4)).toIso8601String(),
      'isDecoy': 1,
    });
    await db.insert('evidence', {
      'id': 'decoy_ev_3',
      'type': 'text',
      'filePath': null,
      'url': null,
      'description': 'Family Recipe: Traditional Kacchi Biryani & Shahi Tukra',
      'metadata': jsonEncode({'category': 'Cooking'}),
      'createdAt': now.subtract(const Duration(days: 6)).toIso8601String(),
      'isDecoy': 1,
    });

    // Seed emergency contacts (Default BD Helplines + Trusted Contact)
    await db.insert('contacts', {
      'id': 'c_1',
      'name': 'National Emergency Police (999)',
      'phone': '999',
      'email': 'help@police.gov.bd',
      'relationship': 'Emergency Response',
      'isEmergency': 1,
    });
    await db.insert('contacts', {
      'id': 'c_2',
      'name': 'GBV Helpline Bangladesh (109)',
      'phone': '109',
      'email': 'helpline109@mowca.gov.bd',
      'relationship': 'Helpline',
      'isEmergency': 1,
    });
    await db.insert('contacts', {
      'id': 'c_3',
      'name': 'Ayesha (Sister / Trusted SOS)',
      'phone': '+8801700000000',
      'email': 'ayesha@example.com',
      'relationship': 'Family',
      'isEmergency': 1,
    });
  }
}
