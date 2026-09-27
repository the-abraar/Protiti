import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'dart:math';

/// Manages two fully isolated encrypted SQLite databases: one for the real
/// forensic vault, one for the decoy vault shown under duress. Each gets its
/// own file, its own SQLCipher key, and its own table shape, so extracting
/// or decrypting one file never exposes the other partition or even reveals
/// that it exists.
class DatabaseService {
  final bool isDecoy;

  DatabaseService({this.isDecoy = false});

  static Database? _realDb;
  static Database? _decoyDb;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  static const String _realKeyStorageKey = 'app_state_key';
  static const String _decoyKeyStorageKey = 'app_cache_key';

  // Innocuous filenames: neither name hints that a dual-vault scheme exists.
  String get _fileName => isDecoy ? 'app_cache.db' : 'app_state.db';
  String get _keyStorageKey =>
      isDecoy ? _decoyKeyStorageKey : _realKeyStorageKey;

  /// Table holding evidence-shaped rows. Real and decoy vaults use distinct
  /// table and column names so the two schemas share no fingerprint.
  String get evidenceTable =>
      isDecoy ? 'local_notes_cache' : 'sys_analytics_cache';

  Future<Database> get database async {
    if (isDecoy) {
      _decoyDb ??= await _initDb();
      return _decoyDb!;
    }
    _realDb ??= await _initDb();
    return _realDb!;
  }

  /// Retrieves or generates a secure random 256-bit passphrase for local
  /// encryption, scoped to whichever partition (real/decoy) this instance
  /// addresses.
  Future<String> getOrGenerateDbKey() async {
    String? key;
    try {
      key = await _secureStorage.read(key: _keyStorageKey);
    } catch (e) {
      print('Warning: Secure storage unavailable. Using transient key.');
    }

    if (key == null || key.isEmpty) {
      final random = Random.secure();
      final values = List<int>.generate(32, (i) => random.nextInt(256));
      key = base64UrlEncode(values);
      try {
        await _secureStorage.write(key: _keyStorageKey, value: key);
      } catch (_) {}
    }
    return key;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _fileName);

    // Obtain the partition-specific secure key from hardware-backed keystore
    final dbKey = await getOrGenerateDbKey();

    return await openDatabase(
      path,
      version: 1,
      onConfigure: (db) async {
        // Configure SQLCipher encryption key via PRAGMA
        await db.rawQuery("PRAGMA key = '$dbKey'");
      },
      onCreate: (db, version) async {
        if (isDecoy) {
          await _createDecoyTables(db);
          await _seedDecoyData(db);
        } else {
          await _createRealTables(db);
          await _seedRealData(db);
        }
      },
    );
  }

  Future<void> _createRealTables(Database db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS sys_analytics_cache (
        req_id TEXT PRIMARY KEY,
        mime_type TEXT,
        uri_path TEXT,
        ext_url TEXT,
        blob_ref TEXT,
        meta_tags TEXT,
        timestamp TEXT
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

  /// Deliberately shaped like an ordinary notes-app cache table. No column
  /// or table name here overlaps with the real vault's schema above.
  Future<void> _createDecoyTables(Database db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS local_notes_cache (
        note_id TEXT PRIMARY KEY,
        category TEXT,
        attachment_path TEXT,
        body_text TEXT,
        extra_json TEXT,
        saved_at TEXT
      )''');
  }

  Future<void> _seedRealData(Database db) async {
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
    });

    // Seed emergency contacts (Default BD Helplines + Trusted Contact).
    // Contacts live only in the real database: the panic/SOS flow must work
    // identically in decoy mode for the survivor's safety, so it always
    // reads from the real partition regardless of which PIN unlocked the UI.
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

  Future<void> _seedDecoyData(Database db) async {
    final now = DateTime.now();
    await db.insert('local_notes_cache', {
      'note_id': 'decoy_1',
      'category': 'text',
      'attachment_path': null,
      'body_text': 'Fall 2026 University Semester Syllabus & Exam Routine',
      'extra_json': jsonEncode({'pages': 2}),
      'saved_at': now.subtract(const Duration(days: 2)).toIso8601String(),
    });
    await db.insert('local_notes_cache', {
      'note_id': 'decoy_2',
      'category': 'text',
      'attachment_path': null,
      'body_text': 'Weekly Grocery Budget & Household Expenses (Dhanmondi)',
      'extra_json': jsonEncode({'status': 'Archived'}),
      'saved_at': now.subtract(const Duration(days: 4)).toIso8601String(),
    });
    await db.insert('local_notes_cache', {
      'note_id': 'decoy_3',
      'category': 'text',
      'attachment_path': null,
      'body_text': 'Family Recipe: Traditional Kacchi Biryani & Shahi Tukra',
      'extra_json': '{}',
      'saved_at': now.subtract(const Duration(days: 6)).toIso8601String(),
    });
  }
}
