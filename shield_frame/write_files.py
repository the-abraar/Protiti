import os

files = {
    'lib/domain/models/evidence.dart': '''
class Evidence {
  final String id;
  final String type; // screenshot, link, text
  final String? filePath;
  final String? url;
  final String description;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;

  Evidence({
    required this.id,
    required this.type,
    this.filePath,
    this.url,
    required this.description,
    this.metadata,
    required this.createdAt,
  });
}
''',
    'lib/domain/models/complaint.dart': '''
class Complaint {
  final String id;
  final String type;
  final String title;
  final String description;
  final List<String> evidenceIds;
  final String generatedText;
  final String targetPoliceStation;
  final String status;
  final DateTime createdAt;

  Complaint({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.evidenceIds,
    required this.generatedText,
    required this.targetPoliceStation,
    required this.status,
    required this.createdAt,
  });
}
''',
    'lib/domain/models/contact.dart': '''
class TrustedContact {
  final String id;
  final String name;
  final String phone;
  final String email;
  final String relationship;
  final bool isEmergency;

  TrustedContact({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.relationship,
    required this.isEmergency,
  });
}
''',
    'lib/domain/models/support_provider.dart': '''
class SupportProvider {
  final String id;
  final String name;
  final String type;
  final String organization;
  final String phone;
  final String email;
  final String division;
  final bool isProBono;

  SupportProvider({
    required this.id,
    required this.name,
    required this.type,
    required this.organization,
    required this.phone,
    required this.email,
    required this.division,
    required this.isProBono,
  });
}
''',
    'lib/domain/models/user_profile.dart': '''
class UserProfile {
  final String id;
  final String name;
  final String phone;
  final String division;
  final List<String> emergencyContactIds;

  UserProfile({
    required this.id,
    required this.name,
    required this.phone,
    required this.division,
    required this.emergencyContactIds,
  });
}
''',
    'lib/data/services/database_service.dart': '''
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
''',
    'lib/data/services/encryption_service.dart': '''
class EncryptionService {
  String encrypt(String plainText) {
    // Implement actual AES encryption here
    return plainText; 
  }

  String decrypt(String cipherText) {
    // Implement actual AES decryption here
    return cipherText;
  }
}
''',
    'lib/data/services/location_service.dart': '''
import 'package:geolocator/geolocator.dart';

class LocationService {
  Future<Position?> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return null;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      return null;
    } 

    return await Geolocator.getCurrentPosition();
  }
}
''',
    'lib/data/services/biometric_service.dart': '''
import 'package:local_auth/local_auth.dart';

class BiometricService {
  final LocalAuthentication auth = LocalAuthentication();

  Future<bool> authenticate() async {
    try {
      final bool didAuthenticate = await auth.authenticate(
        localizedReason: 'Please authenticate to show vault',
        options: const AuthenticationOptions(useErrorDialogs: false),
      );
      return didAuthenticate;
    } catch (e) {
      return false;
    }
  }
}
''',
    'lib/data/repositories/evidence_repository.dart': '''
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
''',
    'lib/data/repositories/complaint_repository.dart': '''
import '../../domain/models/complaint.dart';
import '../services/database_service.dart';

class ComplaintRepository {
  final DatabaseService dbService;

  ComplaintRepository(this.dbService);
  
  // Implementation for storing/retrieving complaints
}
''',
    'lib/data/repositories/contact_repository.dart': '''
import '../../domain/models/contact.dart';
import '../services/database_service.dart';

class ContactRepository {
  final DatabaseService dbService;

  ContactRepository(this.dbService);

  // Implementation for contacts
}
''',
    'lib/domain/use_cases/generate_complaint.dart': '''
import '../models/evidence.dart';

class GenerateComplaintUseCase {
  String execute(List<Evidence> evidence, Map<String, dynamic> answers) {
    // Generates legally-formatted General Diary (GD) complaints
    return 'Subject: General Diary regarding online harassment...';
  }
}
''',
    'lib/domain/use_cases/package_evidence.dart': '''
import '../models/evidence.dart';

class PackageEvidenceUseCase {
  Future<String> execute(List<Evidence> evidence) async {
    // Packages evidence into a zipped folder or secure report
    return 'path/to/packaged_evidence.zip';
  }
}
''',
    'lib/domain/use_cases/trigger_panic.dart': '''
import '../../data/services/location_service.dart';

class TriggerPanicUseCase {
  final LocationService locationService;
  
  TriggerPanicUseCase(this.locationService);

  Future<void> execute() async {
    final loc = await locationService.getCurrentLocation();
    // Send SMS to emergency contacts with loc
  }
}
''',
    'lib/ui/core/theme/app_theme.dart': '''
import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData.dark().copyWith(
      primaryColor: const Color(0xFF0A1128),
      scaffoldBackgroundColor: const Color(0xFF0A1128),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF1282A2),
        secondary: Color(0xFFFFC857),
        error: Color(0xFFE63946),
        surface: Color(0xFF1B2838),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0A1128),
        elevation: 0,
      ),
    );
  }
}
''',
    'lib/ui/features/auth/lock_screen.dart': '''
import 'package:flutter/material.dart';
import '../../../data/services/biometric_service.dart';
import '../vault/vault_screen.dart';
import '../../core/theme/app_theme.dart';

class LockScreen extends StatefulWidget {
  @override
  _LockScreenState createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final BiometricService _bioService = BiometricService();
  bool _isCalculatorMode = false;

  void _authenticate() async {
    bool authed = await _bioService.authenticate();
    if (authed && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => VaultScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isCalculatorMode ? 'Calculator' : 'Protiti (প্রতীতি)'),
        actions: [
          IconButton(
            icon: Icon(Icons.calculate),
            onPressed: () {
              setState(() {
                _isCalculatorMode = !_isCalculatorMode;
              });
            }
          )
        ]
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.security, size: 80, color: Theme.of(context).colorScheme.primary),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _authenticate,
              child: Text('Unlock Vault'),
            )
          ],
        ),
      ),
    );
  }
}
''',
    'lib/ui/features/vault/vault_screen.dart': '''
import 'package:flutter/material.dart';
import '../panic/panic_screen.dart';
import '../complaint/complaint_wizard_screen.dart';
import '../support/support_screen.dart';

class VaultScreen extends StatefulWidget {
  @override
  _VaultScreenState createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    Center(child: Text('Vault: Your Evidences')),
    ComplaintWizardScreen(),
    PanicScreen(),
    SupportScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Vault')),
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.shield), label: 'Vault'),
          BottomNavigationBarItem(icon: Icon(Icons.description), label: 'Report'),
          BottomNavigationBarItem(icon: Icon(Icons.warning), label: 'Panic'),
          BottomNavigationBarItem(icon: Icon(Icons.support_agent), label: 'Support'),
        ],
      ),
      floatingActionButton: _currentIndex == 0 ? FloatingActionButton(
        onPressed: () {},
        child: Icon(Icons.add),
      ) : null,
    );
  }
}
''',
    'lib/ui/features/complaint/complaint_wizard_screen.dart': '''
import 'package:flutter/material.dart';

class ComplaintWizardScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(child: Text('Complaint Wizard (GD-Automator)'));
  }
}
''',
    'lib/ui/features/panic/panic_screen.dart': '''
import 'package:flutter/material.dart';

class PanicScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.error,
          padding: EdgeInsets.all(80),
          shape: CircleBorder(),
        ),
        onPressed: () {
          // Trigger panic
        },
        child: Text('PANIC', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
      )
    );
  }
}
''',
    'lib/ui/features/support/support_screen.dart': '''
import 'package:flutter/material.dart';

class SupportScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(child: Text('Support Bridge (Lawyers & Counselors)'));
  }
}
''',
    'lib/main.dart': '''
import 'package:flutter/material.dart';
import 'ui/core/theme/app_theme.dart';
import 'ui/features/auth/lock_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(ShieldFrameApp());
}

class ShieldFrameApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Protiti',
      theme: AppTheme.darkTheme,
      home: LockScreen(),
    );
  }
}
'''
}

for path, content in files.items():
    full_path = os.path.join('/Users/blackbird/Everything/dev/DKC/shield_frame', path)
    os.makedirs(os.path.dirname(full_path), exist_ok=True)
    with open(full_path, 'w') as f:
        f.write(content.strip() + '\\n')
