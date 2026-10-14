import 'package:flutter_test/flutter_test.dart';
import 'package:protiti/data/services/database_service.dart';

void main() {
  test('real and decoy vaults use separate tables', () {
    expect(DatabaseService().evidenceTable, isNot(DatabaseService(isDecoy: true).evidenceTable));
  });
}
