import '../../domain/models/evidence.dart';
import '../services/database_service.dart';

class EvidenceRepository {
  final DatabaseService dbService;

  EvidenceRepository(this.dbService);

  Future<void> addEvidence(Evidence evidence) async {
    final db = await dbService.database;
    await db.insert('evidence', {
      'id': evidence.id,
      'type': evidence.type,
      'filePath': evidence.filePath,
      'url': evidence.url,
      'description': evidence.description,
      'metadata': '', // Serialize to string
      'createdAt': evidence.createdAt.toIso8601String(),
    });
  }

  Future<List<Evidence>> getAllEvidence() async {
    final db = await dbService.database;
    final List<Map<String, dynamic>> maps = await db.query('evidence');
    return maps.map((e) => Evidence(
      id: e['id'],
      type: e['type'],
      filePath: e['filePath'],
      url: e['url'],
      description: e['description'],
      createdAt: DateTime.parse(e['createdAt']),
    )).toList();
  }
}
