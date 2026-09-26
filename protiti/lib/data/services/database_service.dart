import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:io';

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
    String? key;
    try {
      key = await _secureStorage.read(key: _encryptionKeyStorageKey);
    } catch (e) {
      print('Warning: Secure storage unavailable. Using transient key.');
    }
    
    if (key == null || key.isEmpty) {
      final random = Random.secure();
      final values = List<int>.generate(32, (i) => random.nextInt(256));
      key = base64UrlEncode(values);
      try {
        await _secureStorage.write(key: _encryptionKeyStorageKey, value: key);
      } catch (_) {}
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
            await db.execute(
              'ALTER TABLE evidence ADD COLUMN isDecoy INTEGER DEFAULT 0',
            );
          } catch (_) {}
        }
      },
    );
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS sys_analytics_cache (
        req_id TEXT PRIMARY KEY,
        mime_type TEXT,
        uri_path TEXT,
        ext_url TEXT,
        blob_ref TEXT,
        meta_tags TEXT,
        timestamp TEXT,
        is_temp INTEGER DEFAULT 0
      )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS sys_crash_reports (
        dump_id TEXT PRIMARY KEY,
        dump_type TEXT,
        header_title TEXT,
        stack_trace TEXT,
        ref_ids TEXT,
        compiled_out TEXT,
        route_node TEXT,
        sync_state TEXT,
        timestamp TEXT
      )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS net_telemetry_peers (
        node_id TEXT PRIMARY KEY,
        host_alias TEXT,
        ipv4_route TEXT,
        ipv6_route TEXT,
        subnet_mask TEXT,
        is_active INTEGER DEFAULT 1
      )''');
  }

  Future<void> _seedInitialData(Database db) async {
    // Seed real forensic evidence
    final now = DateTime.now();
    await db.insert('sys_analytics_cache', {
      'req_id': 'real_ev_1',
      'mime_type': 'screenshot',
      'uri_path': null,
      'ext_url': null,
      'blob_ref':
          'Threatening WhatsApp chat from perpetrator with time-stamped extortion demand',
      'meta_tags': jsonEncode({
        'source': 'WhatsApp',
        'hash': 'sha256_mock_a8f9c1',
      }),
      'timestamp': now.subtract(const Duration(days: 1)).toIso8601String(),
      'is_temp': 0,
    });
    await db.insert('sys_analytics_cache', {
      'req_id': 'real_ev_2',
      'mime_type': 'audio',
      'uri_path': null,
      'ext_url': null,
      'blob_ref':
          'Recorded audio harassment call with explicit death threat and location stalking',
      'meta_tags': jsonEncode({'durationSeconds': 94, 'codec': 'm4a'}),
      'timestamp': now.subtract(const Duration(days: 3)).toIso8601String(),
      'is_temp': 0,
    });
    await db.insert('sys_analytics_cache', {
      'req_id': 'real_ev_3',
      'mime_type': 'pdf',
      'uri_path': null,
      'ext_url': null,
      'blob_ref':
          'Certified cyber incident log export documenting unauthorized login attempts',
      'meta_tags': jsonEncode({'pages': 3, 'format': 'pdf'}),
      'timestamp': now.subtract(const Duration(days: 5)).toIso8601String(),
      'is_temp': 0,
    });

    // Seed decoy innocent evidence (shown when Duress PIN is entered)
    await db.insert('sys_analytics_cache', {
      'req_id': 'decoy_ev_1',
      'mime_type': 'pdf',
      'uri_path': null,
      'ext_url': null,
      'blob_ref': 'Fall 2026 University Semester Syllabus & Exam Routine',
      'meta_tags': jsonEncode({'category': 'Study', 'pages': 2}),
      'timestamp': now.subtract(const Duration(days: 2)).toIso8601String(),
      'is_temp': 1,
    });
    await db.insert('sys_analytics_cache', {
      'req_id': 'decoy_ev_2',
      'mime_type': 'text',
      'uri_path': null,
      'ext_url': null,
      'blob_ref': 'Weekly Grocery Budget & Household Expenses (Dhanmondi)',
      'meta_tags': jsonEncode({'category': 'Personal', 'status': 'Archived'}),
      'timestamp': now.subtract(const Duration(days: 4)).toIso8601String(),
      'is_temp': 1,
    });
    await db.insert('sys_analytics_cache', {
      'req_id': 'decoy_ev_3',
      'mime_type': 'text',
      'uri_path': null,
      'ext_url': null,
      'blob_ref': 'Family Recipe: Traditional Kacchi Biryani & Shahi Tukra',
      'meta_tags': jsonEncode({'category': 'Cooking'}),
      'timestamp': now.subtract(const Duration(days: 6)).toIso8601String(),
      'is_temp': 1,
    });

    // Seed emergency contacts (Default BD Helplines + Trusted Contact)
    await db.insert('net_telemetry_peers', {
      'node_id': 'c_1',
      'host_alias': 'National Emergency Police (999)',
      'ipv4_route': '999',
      'ipv6_route': 'help@police.gov.bd',
      'subnet_mask': 'Emergency Response',
      'is_active': 1,
    });
    await db.insert('net_telemetry_peers', {
      'node_id': 'c_2',
      'host_alias': 'GBV Helpline Bangladesh (109)',
      'ipv4_route': '109',
      'ipv6_route': 'helpline109@mowca.gov.bd',
      'subnet_mask': 'Helpline',
      'is_active': 1,
    });
    await db.insert('net_telemetry_peers', {
      'node_id': 'c_3',
      'host_alias': 'Ayesha (Sister / Trusted SOS)',
      'ipv4_route': '+8801700000000',
      'ipv6_route': 'ayesha@example.com',
      'subnet_mask': 'Family',
      'is_active': 1,
    });
  }
}
