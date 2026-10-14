import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:protiti/data/services/database_service.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'helpers/fakes.dart';

/// Records schema statements and row writes instead of touching SQLite.
class RecordingDatabase implements Database {
  final List<String> statements = [];
  final List<String> insertsInto = [];
  bool closed = false;

  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) async => statements.add(sql);

  @override
  Future<int> insert(String table, Map<String, Object?> values,
      {String? nullColumnHack, ConflictAlgorithm? conflictAlgorithm}) async {
    insertsInto.add(table);
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
    expect(DatabaseService().evidenceTable, isNot(DatabaseService(isDecoy: true).evidenceTable));
  });

  test('a fresh real vault has 0 evidence and 0 contacts', () async {
    final db = RecordingDatabase();
    await DatabaseService().onCreate(db, 1);
    expect(db.statements.where((s) => s.contains('sys_analytics_cache')), hasLength(1));
    expect(db.statements.where((s) => s.contains('net_telemetry_peers')), hasLength(1));
    expect(db.insertsInto, isEmpty);
  });

  test('a storage error fails closed instead of using a throwaway key', () async {
    storage.failing = true;
    await expectLater(DatabaseService().getOrGenerateDbKey(), throwsA(anything));
  });

  test('a missing key for an existing database file throws, and writes no new key', () async {
    final root = installTempPaths();
    File('${root.path}/dbs/app_state.db').writeAsStringSync('old data');
    await expectLater(DatabaseService().getOrGenerateDbKey(), throwsStateError);
    expect(storage.store, isEmpty);

    final key = await DatabaseService(isDecoy: true).getOrGenerateDbKey();
    expect(storage.store['app_cache_key'], key);
    root.deleteSync(recursive: true);
  });

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
