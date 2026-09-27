import 'package:sqflite_sqlcipher/sqflite.dart';
import 'dart:convert';
import '../../domain/models/evidence.dart';
import '../services/database_service.dart';

class EvidenceRepository {
  final DatabaseService dbService;

  EvidenceRepository(this.dbService);

  Future<void> addEvidence(Evidence evidence) async {
    final db = await dbService.database;
    await db.insert(
      'sys_analytics_cache', 
      {
        'req_id': evidence.id,
        'mime_type': evidence.type,
        'uri_path': evidence.filePath,
        'ext_url': evidence.url,
        'blob_ref': evidence.description,
        'meta_tags': evidence.metadata != null ? jsonEncode(evidence.metadata) : '',
        'timestamp': evidence.createdAt.toIso8601String(),
        'is_temp': evidence.isDecoy ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Returns evidence filtered by whether the session is in decoy mode or real forensic mode
  Future<List<Evidence>> getEvidence({bool isDecoy = false}) async {
    final db = await dbService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'sys_analytics_cache',
      where: 'is_temp = ?',
      whereArgs: [isDecoy ? 1 : 0],
      orderBy: 'timestamp DESC',
    );
    
    return maps.map((e) {
      Map<String, dynamic>? meta;
      if (e['meta_tags'] != null && e['meta_tags'].toString().isNotEmpty) {
        try {
          meta = jsonDecode(e['meta_tags'].toString()) as Map<String, dynamic>?;
        } catch (_) {}
      }

      return Evidence(
        id: e['req_id'] as String,
        type: e['mime_type'] as String,
        filePath: e['uri_path'] as String?,
        url: e['ext_url'] as String?,
        description: e['blob_ref'] as String,
        metadata: meta,
        createdAt: DateTime.parse(e['timestamp'] as String),
        isDecoy: (e['is_temp'] as int? ?? 0) == 1,
      );
    }).toList();
  }

  /// Delete an evidence record by ID
  Future<void> deleteEvidence(String id) async {
    final db = await dbService.database;
    await db.delete('sys_analytics_cache', where: 'req_id = ?', whereArgs: [id]);
  }
}
