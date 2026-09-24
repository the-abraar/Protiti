import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:math';

class DatabaseService {
  static Database? _db;
  final _secureStorage = const FlutterSecureStorage();

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'shield_frame.db');
    
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE evidence (id TEXT PRIMARY KEY, type TEXT, filePath TEXT, url TEXT, description TEXT, metadata TEXT, createdAt TEXT)',
        );
        await db.execute(
          'CREATE TABLE complaints (id TEXT PRIMARY KEY, type TEXT, title TEXT, description TEXT, evidenceIds TEXT, generatedText TEXT, targetPoliceStation TEXT, status TEXT, createdAt TEXT)',
        );
        await db.execute(
          'CREATE TABLE contacts (id TEXT PRIMARY KEY, name TEXT, phone TEXT, email TEXT, relationship TEXT, isEmergency INTEGER)',
        );
      },
    );
  }
}
