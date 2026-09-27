import 'package:sqflite_sqlcipher/sqflite.dart';
import 'dart:convert';
import '../../domain/models/evidence.dart';
import '../services/database_service.dart';

class EvidenceRepository {
  final DatabaseService dbService;

  EvidenceRepository(this.dbService);

  bool get _isDecoy => dbService.isDecoy;

  Future<void> addEvidence(Evidence evidence) async {
    final db = await dbService.database;

    if (_isDecoy) {
      await db.insert(
        'local_notes_cache',
        {
          'note_id': evidence.id,
          'category': evidence.type,
          'attachment_path': evidence.filePath,
          'body_text': evidence.description,
          'extra_json':
              evidence.metadata != null ? jsonEncode(evidence.metadata) : '',
          'saved_at': evidence.createdAt.toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return;
    }

    await db.insert(
      'sys_analytics_cache',
      {
        'req_id': evidence.id,
        'mime_type': evidence.type,
        'uri_path': evidence.filePath,
        'ext_url': evidence.url,
        'blob_ref': evidence.description,
        'meta_tags':
            evidence.metadata != null ? jsonEncode(evidence.metadata) : '',
        'timestamp': evidence.createdAt.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Returns every record from whichever partition (real or decoy) this
  /// repository's [DatabaseService] was constructed for. The two partitions
  /// are separate encrypted files, so there is no row-level filter here
  /// anymore — the correct database is selected by construction, not by a
  /// shared "isDecoy" column.
  Future<List<Evidence>> getEvidence() async {
    final db = await dbService.database;

    if (_isDecoy) {
      final List<Map<String, dynamic>> maps = await db.query(
        'local_notes_cache',
        orderBy: 'saved_at DESC',
      );
      return maps.map((e) {
        Map<String, dynamic>? meta;
        if (e['extra_json'] != null &&
            e['extra_json'].toString().isNotEmpty) {
          try {
            meta = jsonDecode(e['extra_json'].toString())
                as Map<String, dynamic>?;
          } catch (_) {}
        }
        return Evidence(
          id: e['note_id'] as String,
          type: e['category'] as String,
          filePath: e['attachment_path'] as String?,
          description: e['body_text'] as String,
          metadata: meta,
          createdAt: DateTime.parse(e['saved_at'] as String),
          isDecoy: true,
        );
      }).toList();
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'sys_analytics_cache',
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
        isDecoy: false,
      );
    }).toList();
  }

  /// Delete an evidence record by ID from whichever partition this
  /// repository addresses.
  Future<void> deleteEvidence(String id) async {
    final db = await dbService.database;
    if (_isDecoy) {
      await db.delete('local_notes_cache', where: 'note_id = ?', whereArgs: [id]);
      return;
    }
    await db.delete('sys_analytics_cache', where: 'req_id = ?', whereArgs: [id]);
  }
}
