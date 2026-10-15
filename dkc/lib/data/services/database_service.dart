import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'secure_store.dart';

/// Manages two fully isolated encrypted SQLite databases: one for the real
/// forensic vault, one for the decoy vault shown under duress. Each gets its
/// own file, its own SQLCipher key, and its own table shape, so extracting
/// or decrypting one file never exposes the other partition or even reveals
/// that it exists.
class DatabaseService {
  final bool isDecoy;
  final FlutterSecureStorage _secureStorage;

  DatabaseService({this.isDecoy = false, FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? secureStore;

  static Database? _realDb;
  static Database? _decoyDb;

  static const String _realKeyStorageKey = 'app_state_key';
  static const String _decoyKeyStorageKey = 'app_cache_key';

  /// Innocuous filenames: neither name hints that a dual-vault scheme exists.
  static const fileNames = ['app_state.db', 'app_cache.db'];
  String get _fileName => isDecoy ? fileNames[1] : fileNames[0];
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

  /// Closes and forgets both handles, so a wipe leaves nothing readable in memory.
  static Future<void> closeAll() async {
    final handles = [_realDb, _decoyDb];
    _realDb = null;
    _decoyDb = null;
    for (final db in handles) {
      try {
        await db?.close();
      } catch (_) {}
    }
  }

  @visibleForTesting
  static void debugSetHandles({Database? real, Database? decoy}) {
    _realDb = real;
    _decoyDb = decoy;
  }

  /// Retrieves or generates a secure random 256-bit passphrase for this
  /// partition. Fails closed: a storage error, or a missing key for a file
  /// that already exists, throws instead of opening with a key that would
  /// be lost at the next launch.
  Future<String> getOrGenerateDbKey() async {
    final existing = await _secureStorage.read(key: _keyStorageKey);
    if (existing != null && existing.isNotEmpty) return existing;
    if (await File(join(await getDatabasesPath(), _fileName)).exists()) {
      throw StateError('Storage key missing for an existing database file.');
    }
    final random = Random.secure();
    final key = base64UrlEncode(
      List<int>.generate(32, (_) => random.nextInt(256)),
    );
    await _secureStorage.write(key: _keyStorageKey, value: key);
    return key;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _fileName);

    // Obtain the partition-specific secure key from hardware-backed keystore
    final dbKey = await getOrGenerateDbKey();

    return await openDatabase(
      path,
      version: 2,
      onConfigure: (db) async {
        // Configure SQLCipher encryption key via PRAGMA
        await db.rawQuery("PRAGMA key = '$dbKey'");
      },
      onCreate: onCreate,
      onUpgrade: onUpgrade,
    );
  }

  /// Version 2 removes the sample rows older builds seeded into the real
  /// vault: invented evidence, and SOS "contacts" 999, 109 and a placeholder
  /// number that may belong to a stranger. Her own rows have other ids.
  @visibleForTesting
  Future<void> onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (isDecoy || oldVersion >= 2) return;
    await db.delete(
      'sys_analytics_cache',
      where: 'req_id IN (?, ?, ?)',
      whereArgs: ['real_ev_1', 'real_ev_2', 'real_ev_3'],
    );
    await db.delete(
      'net_telemetry_peers',
      where: 'node_id IN (?, ?, ?)',
      whereArgs: ['c_1', 'c_2', 'c_3'],
    );
  }

  /// A fresh real vault starts empty: no sample evidence, no placeholder contacts.
  @visibleForTesting
  Future<void> onCreate(Database db, int version) async {
    if (isDecoy) {
      await _createDecoyTables(db);
      await _seedDecoyData(db);
    } else {
      await _createRealTables(db);
    }
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

  /// Ordinary notes for a fresh second-PIN space. Each install gets a random
  /// few with random ages, so no two look alike and a second look weeks later
  /// is not the same three notes at the same ages (N14).
  /// shortcut: the pool is in a public repo; upgrade to notes she writes at setup.
  @visibleForTesting
  static const decoyNotePool = [
    'Grocery list: rice, dal, onions, eggs, cooking oil',
    'বাজারের লিস্ট: চাল, ডাল, পেঁয়াজ, ডিম, তেল',
    'Electricity bill paid, keep the receipt',
    'Class routine: Sun and Tue 10 am, Thu 2 pm',
    'Tailor: pick up the kameez on Thursday',
    'মায়ের ওষুধ: সকালে একটা, রাতে একটা',
    'Chicken curry: ginger garlic paste first, then onions',
    'Gas cylinder: call the shop when it runs low',
    'Gift ideas for Nanu\'s birthday',
    'Rickshaw and bus fare this week',
    'মিটিং শনিবার বিকেল ৪টায়',
    'Wi-Fi bill due on the 10th',
  ];

  Future<void> _seedDecoyData(Database db) async {
    final rand = Random.secure();
    final picks = List.of(decoyNotePool)..shuffle(rand);
    final now = DateTime.now(), count = 2 + rand.nextInt(3);
    for (var i = 0; i < count; i++) {
      await db.insert('local_notes_cache', {
        'note_id': 'decoy_${i + 1}',
        'category': 'text',
        'attachment_path': null,
        'body_text': picks[i],
        'extra_json': '{}',
        'saved_at': now
            .subtract(Duration(hours: 6 + rand.nextInt(24 * 21)))
            .toIso8601String(),
      });
    }
  }
}
