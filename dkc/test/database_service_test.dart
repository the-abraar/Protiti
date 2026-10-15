import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:protiti/data/services/database_service.dart';
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
