import 'dart:convert';
import '../../domain/models/complaint.dart';
import '../services/database_service.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class ComplaintRepository {
  final DatabaseService dbService;

  ComplaintRepository(this.dbService);

  Future<void> saveComplaint(Complaint complaint) async {
    final db = await dbService.database;
    await db.insert(
      'sys_crash_reports', 
      {
        'dump_id': complaint.id,
        'dump_type': complaint.type,
        'header_title': complaint.title,
        'stack_trace': complaint.description,
        'ref_ids': jsonEncode(complaint.evidenceIds),
        'compiled_out': complaint.generatedText,
        'route_node': complaint.targetPoliceStation,
        'sync_state': complaint.status,
        'timestamp': complaint.createdAt.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Complaint>> getAllComplaints() async {
    final db = await dbService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'sys_crash_reports',
      orderBy: 'timestamp DESC',
    );
    return maps.map((c) {
      List<String> evIds = [];
      try {
        final decoded = jsonDecode(c['ref_ids'] as String? ?? '[]');
        if (decoded is List) {
          evIds = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}

      return Complaint(
        id: c['dump_id'] as String,
        type: c['dump_type'] as String,
        title: c['header_title'] as String,
        description: c['stack_trace'] as String,
        evidenceIds: evIds,
        generatedText: c['compiled_out'] as String,
        targetPoliceStation: c['route_node'] as String,
        status: c['sync_state'] as String,
        createdAt: DateTime.parse(c['timestamp'] as String),
      );
    }).toList();
  }
}
