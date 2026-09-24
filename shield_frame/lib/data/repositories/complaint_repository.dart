import 'dart:convert';
import '../../domain/models/complaint.dart';
import '../services/database_service.dart';

class ComplaintRepository {
  final DatabaseService dbService;

  ComplaintRepository(this.dbService);

  Future<void> saveComplaint(Complaint complaint) async {
    final db = await dbService.database;
    await db.insert('complaints', {
      'id': complaint.id,
      'type': complaint.type,
      'title': complaint.title,
      'description': complaint.description,
      'evidenceIds': jsonEncode(complaint.evidenceIds),
      'generatedText': complaint.generatedText,
      'targetPoliceStation': complaint.targetPoliceStation,
      'status': complaint.status,
      'createdAt': complaint.createdAt.toIso8601String(),
    });
  }

  Future<List<Complaint>> getAllComplaints() async {
    final db = await dbService.database;
    final List<Map<String, dynamic>> maps = await db.query('complaints', orderBy: 'createdAt DESC');
    return maps.map((c) {
      List<String> evIds = [];
      try {
        final decoded = jsonDecode(c['evidenceIds'] as String? ?? '[]');
        if (decoded is List) {
          evIds = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}

      return Complaint(
        id: c['id'] as String,
        type: c['type'] as String,
        title: c['title'] as String,
        description: c['description'] as String,
        evidenceIds: evIds,
        generatedText: c['generatedText'] as String,
        targetPoliceStation: c['targetPoliceStation'] as String,
        status: c['status'] as String,
        createdAt: DateTime.parse(c['createdAt'] as String),
      );
    }).toList();
  }
}
