import '../../domain/models/contact.dart';
import '../services/database_service.dart';

class ContactRepository {
  final DatabaseService dbService;

  ContactRepository(this.dbService);

  Future<void> addContact(TrustedContact contact) async {
    final db = await dbService.database;
    await db.insert('contacts', contact.toMap());
  }

  Future<List<TrustedContact>> getAllContacts() async {
    final db = await dbService.database;
    final List<Map<String, dynamic>> maps = await db.query('contacts');
    return maps.map((c) => TrustedContact.fromMap(c)).toList();
  }

  Future<List<TrustedContact>> getEmergencyContacts() async {
    final db = await dbService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'contacts',
      where: 'isEmergency = ?',
      whereArgs: [1],
    );
    return maps.map((c) => TrustedContact.fromMap(c)).toList();
  }
}
