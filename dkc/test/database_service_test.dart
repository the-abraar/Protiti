import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:protiti/data/repositories/evidence_repository.dart';
import 'package:protiti/data/services/database_service.dart';
import 'package:protiti/domain/models/evidence.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'helpers/fakes.dart';

/// Records schema statements and row writes instead of touching SQLite.
class RecordingDatabase implements Database {
  final List<String> statements = [];
  final List<String> insertsInto = [];
  final List<Map<String, Object?>> rows = [];
  final List<(String, List<Object?>?)> deletes = [];
  bool closed = false;

  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) async =>
      statements.add(sql);

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    insertsInto.add(table);
    rows.add(values);
    return 1;
  }

  @override
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    deletes.add((table, whereArgs));
    return 1;
  }

  @override
  Future<void> close() async => closed = true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Stands in for the SQLCipher plugin channel: one row store per database
/// file, which opens only with the key it was first opened with. Understands
/// just the SQL this app sends; an unknown table throws, as SQLite does.
class FakeSqlCipher {
  FakeSqlCipher(this.dbsPath);
  final String dbsPath;
  final files = <String, Map<String, List<Map<String, Object?>>>>{};
  final keys = <String, String>{};
  final _versions = <String, int>{};
  final _open = <int, String>{};

  void install() => TestDefaultBinaryMessengerBinding
      .instance
      .defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('com.davidmartos96.sqflite_sqlcipher'),
        _handle,
      );

  Future<Object?> _handle(MethodCall call) async {
    final args = call.arguments is Map ? call.arguments as Map : const {};
    switch (call.method) {
      case 'getDatabasesPath':
        return dbsPath;
      case 'openDatabase':
        final id = _open.length + 1;
        _open[id] = args['path'] as String;
        files.putIfAbsent(args['path'] as String, () => {});
        return {'id': id};
      case 'closeDatabase':
        return null;
      case 'execute' || 'insert' || 'query':
        return _sql(
          _open[args['id']]!,
          args['sql'] as String,
          args['arguments'],
        );
    }
    return null;
  }

  Object? _sql(String path, String sql, Object? arguments) {
    final tables = files[path]!;
    final values = (arguments as List?) ?? const [];
    Never fail(String m) =>
        throw PlatformException(code: 'sqlite_error', message: m);
    List<Map<String, Object?>> table(String name) =>
        tables[name] ?? fail('no such table: $name');
    RegExpMatch? m(String re) =>
        RegExp(re, caseSensitive: false).firstMatch(sql);

    if (m(r"^PRAGMA key = '(.*)'") case final k?) {
      if ((keys[path] ??= k[1]!) != k[1]) fail('file is not a database');
    } else if (m(r'^PRAGMA user_version = (\d+)') case final v?) {
      _versions[path] = int.parse(v[1]!);
    } else if (m(r'^PRAGMA user_version') != null) {
      return {
        'columns': ['user_version'],
        'rows': [
          [_versions[path] ?? 0],
        ],
      };
    } else if (m(r'^CREATE TABLE IF NOT EXISTS (\w+)') case final c?) {
      tables.putIfAbsent(c[1]!, () => []);
    } else if (m(
          r'^INSERT(?: OR REPLACE)? INTO (\w+) \(([^)]*)\) VALUES \((.*)\)',
        )
        case final i?) {
      // sqflite inlines NULL and binds everything else as ?.
      final args = values.iterator;
      final cells = i[3]!
          .split(',')
          .map((v) => v.trim() == 'NULL' ? null : (args..moveNext()).current);
      final row = Map.fromIterables(
        i[2]!.split(',').map((c) => c.trim()),
        cells,
      );
      table(i[1]!)
        ..removeWhere((r) => r.values.first == row.values.first)
        ..add(row);
      return 1;
    } else if (m(r'^SELECT \* FROM (\w+)') case final q?) {
      final rows = table(q[1]!);
      final cols = rows.isEmpty ? <String>[] : rows.first.keys.toList();
      return {
        'columns': cols,
        'rows': [
          for (final r in rows) [for (final c in cols) r[c]],
        ],
      };
    }
    return sql.startsWith('PRAGMA') ? {'columns': [], 'rows': []} : null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final storage = FakeSecureStorage();

  setUp(() {
    storage
      ..store.clear()
      ..failing = false
      ..install();
  });
  tearDown(storage.uninstall);

  test('real and decoy vaults use separate tables', () {
    expect(
      DatabaseService().evidenceTable,
      isNot(DatabaseService(isDecoy: true).evidenceTable),
    );
  });

  test(
    'evidence saved under the real PIN never shows in the second-PIN space, and the reverse',
    () async {
      final root = installTempPaths();
      final sql = FakeSqlCipher('${root.path}/dbs')..install();
      addTearDown(() async {
        await DatabaseService.closeAll();
        root.deleteSync(recursive: true);
      });
      const secret = 'He hit me on 3 October; photo of the bruise';
      const note = 'Buy milk and bread';

      await EvidenceRepository(DatabaseService()).addEvidence(
        Evidence(
          id: 'ev_real',
          type: 'text',
          description: secret,
          createdAt: DateTime(2026, 10, 3),
        ),
      );
      await DatabaseService.closeAll(); // the app is closed and reopened

      final decoy = EvidenceRepository(DatabaseService(isDecoy: true));
      await decoy.addEvidence(
        Evidence(
          id: 'ev_decoy',
          type: 'text',
          description: note,
          createdAt: DateTime(2026, 10, 4),
        ),
      );
      final decoyItems = await decoy.getEvidence();
      expect(decoyItems.map((e) => e.id), contains('ev_decoy'));
      expect(decoyItems.map((e) => e.id), isNot(contains('ev_real')));
      expect(decoyItems.map((e) => e.description), isNot(contains(secret)));

      await DatabaseService.closeAll();
      final realItems = await EvidenceRepository(
        DatabaseService(),
      ).getEvidence();
      expect(realItems.map((e) => e.description), [secret]);

      // On disk: each text lives in one file only, and the files have different keys.
      Iterable<String> holders(String text) => sql.files.entries
          .where(
            (f) => f.value.values
                .expand((rows) => rows)
                .any((r) => r.containsValue(text)),
          )
          .map((f) => p.basename(f.key));
      expect(holders(secret), ['app_state.db']);
      expect(holders(note), ['app_cache.db']);
      expect(sql.keys.values.toSet(), hasLength(2));
    },
  );

  test(
    'each fresh second-PIN space gets a different few ordinary notes (N14)',
    () async {
      final seen = <String>{};
      for (var i = 0; i < 10; i++) {
        final db = RecordingDatabase();
        await DatabaseService(isDecoy: true).onCreate(db, 1);
        expect(db.rows.length, inInclusiveRange(2, 4));
        for (final row in db.rows) {
          expect(DatabaseService.decoyNotePool, contains(row['body_text']));
        }
        seen.add(
          [
            for (final r in db.rows) '${r['body_text']}@${r['saved_at']}',
          ].join('|'),
        );
      }
      expect(
        seen.length,
        greaterThan(1),
        reason: 'not the same notes on every install',
      );
    },
  );

  test('a fresh real vault has 0 evidence and 0 contacts', () async {
    final db = RecordingDatabase();
    await DatabaseService().onCreate(db, 1);
    expect(
      db.statements.where((s) => s.contains('sys_analytics_cache')),
      hasLength(1),
    );
    expect(
      db.statements.where((s) => s.contains('net_telemetry_peers')),
      hasLength(1),
    );
    expect(db.insertsInto, isEmpty);
  });

  test(
    'upgrading an old real vault removes the seeded sample rows only',
    () async {
      final db = RecordingDatabase();
      await DatabaseService().onUpgrade(db, 1, 2);
      expect(db.deletes.map((d) => '${d.$1}: ${d.$2}'), [
        'sys_analytics_cache: [real_ev_1, real_ev_2, real_ev_3]',
        'net_telemetry_peers: [c_1, c_2, c_3]',
      ]);

      final decoy = RecordingDatabase();
      await DatabaseService(isDecoy: true).onUpgrade(decoy, 1, 2);
      expect(decoy.deletes, isEmpty);
    },
  );

  test(
    'a storage error fails closed instead of using a throwaway key',
    () async {
      storage.failing = true;
      await expectLater(
        DatabaseService().getOrGenerateDbKey(),
        throwsA(anything),
      );
    },
  );

  test(
    'a missing key for an existing database file throws, and writes no new key',
    () async {
      final root = installTempPaths();
      File('${root.path}/dbs/app_state.db').writeAsStringSync('old data');
      await expectLater(
        DatabaseService().getOrGenerateDbKey(),
        throwsStateError,
      );
      expect(storage.store, isEmpty);

      final key = await DatabaseService(isDecoy: true).getOrGenerateDbKey();
      expect(storage.store['app_cache_key'], key);
      root.deleteSync(recursive: true);
    },
  );

  test('closeAll closes and forgets both handles', () async {
    final real = RecordingDatabase();
    final decoy = RecordingDatabase();
    DatabaseService.debugSetHandles(real: real, decoy: decoy);
    await DatabaseService.closeAll();
    expect(real.closed && decoy.closed, isTrue);

    real.closed = false;
    await DatabaseService.closeAll();
    expect(real.closed, isFalse, reason: 'handles were nulled');
  });
}
