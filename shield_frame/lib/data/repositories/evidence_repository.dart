import '../../domain/models/evidence.dart';
import '../services/database_service.dart';

class EvidenceRepository {
  final DatabaseService dbService;

  EvidenceRepository(this.dbService);

  Future<void> addEvidence(Evidence evidence) async {
    final db = await dbService.database;
    await db.insert('evidence', evidence.toMap());
  }

  /// Returns evidence filtered by whether the session is in decoy mode or real forensic mode
  Future<List<Evidence>> getEvidence({bool isDecoy = false}) async {
    final db = await dbService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'evidence',
      where: 'isDecoy = ?',
      whereArgs: [isDecoy ? 1 : 0],
      orderBy: 'createdAt DESC',
    );
    return maps.map((e) => Evidence.fromMap(e)).toList();
  }

  /// Delete an evidence record by ID
  Future<void> deleteEvidence(String id) async {
    final db = await dbService.database;
    await db.delete(
      'evidence',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
