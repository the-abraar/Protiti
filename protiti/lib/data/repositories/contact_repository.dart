import 'package:sqflite_sqlcipher/sqflite.dart';
import '../../domain/models/contact.dart';
import '../services/database_service.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class ContactRepository {
  final DatabaseService dbService;

  ContactRepository(this.dbService);

  Future<void> addContact(TrustedContact contact) async {
    final db = await dbService.database;
    await db.insert(
      'net_telemetry_peers', 
      {
        'node_id': contact.id,
        'host_alias': contact.name,
        'ipv4_route': contact.phone,
        'ipv6_route': contact.email,
        'subnet_mask': contact.relationship,
        'is_active': contact.isEmergency ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<TrustedContact>> getAllContacts() async {
    final db = await dbService.database;
    final List<Map<String, dynamic>> maps = await db.query('net_telemetry_peers');
    return maps.map((c) => TrustedContact(
      id: c['node_id'] as String,
      name: c['host_alias'] as String,
      phone: c['ipv4_route'] as String,
      email: c['ipv6_route'] as String? ?? '',
      relationship: c['subnet_mask'] as String? ?? 'Contact',
      isEmergency: (c['is_active'] as int? ?? 0) == 1,
    )).toList();
  }

  Future<List<TrustedContact>> getEmergencyContacts() async {
    final db = await dbService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'net_telemetry_peers',
      where: 'is_active = ?',
      whereArgs: [1],
    );
    return maps.map((c) => TrustedContact(
      id: c['node_id'] as String,
      name: c['host_alias'] as String,
      phone: c['ipv4_route'] as String,
      email: c['ipv6_route'] as String? ?? '',
      relationship: c['subnet_mask'] as String? ?? 'Contact',
      isEmergency: (c['is_active'] as int? ?? 0) == 1,
    )).toList();
  }
}
