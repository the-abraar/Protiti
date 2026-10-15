import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:protiti/data/repositories/contact_repository.dart';
import 'package:protiti/data/repositories/evidence_repository.dart';
import 'package:protiti/data/services/database_service.dart';
import 'package:protiti/data/services/location_service.dart';
import 'package:protiti/data/services/secure_audio_service.dart';
import 'package:protiti/domain/models/contact.dart';
import 'package:protiti/domain/models/evidence.dart';
import 'package:protiti/domain/use_cases/trigger_panic.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show databaseFactory;

TestDefaultBinaryMessenger get _messenger =>
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

/// In-memory stand-in for the flutter_secure_storage platform channel.
/// Set [failing] to make every call throw, like a broken keystore.
class FakeSecureStorage {
  static const channel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  final Map<String, String> store = {};
  bool failing = false;

  void install() => _messenger.setMockMethodCallHandler(channel, _handle);
  void uninstall() => _messenger.setMockMethodCallHandler(channel, null);

  Future<Object?> _handle(MethodCall call) async {
    if (failing) {
      throw PlatformException(code: 'keystore', message: 'unavailable');
    }
    final args = (call.arguments as Map?) ?? const {};
    switch (call.method) {
      case 'read':
        return store[args['key']];
      case 'write':
        store[args['key'] as String] = args['value'] as String;
        return null;
      case 'delete':
        store.remove(args['key']);
        return null;
      case 'deleteAll':
        store.clear();
        return null;
      case 'readAll':
        return store;
      case 'containsKey':
        return store.containsKey(args['key']);
    }
    return null;
  }
}

/// Points path_provider and sqflite's databases path at a temp directory.
Directory installTempPaths() {
  final root = Directory.systemTemp.createTempSync('protiti_test_');
  final docs = Directory('${root.path}/docs')..createSync();
  final temp = Directory('${root.path}/tmp')..createSync();
  final dbs = Directory('${root.path}/dbs')..createSync();
  _messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (call) async {
      return switch (call.method) {
        'getApplicationDocumentsDirectory' => docs.path,
        'getTemporaryDirectory' => temp.path,
        _ => root.path,
      };
    },
  );
  _messenger.setMockMethodCallHandler(
    const MethodChannel('com.davidmartos96.sqflite_sqlcipher'),
    (call) async {
      if (call.method == 'getDatabasesPath') return dbs.path;
      return null;
    },
  );
  // sqflite caches the path from its first call; point it at this test's dir.
  unawaited(databaseFactory.setDatabasesPath(dbs.path));
  return root;
}

/// Evidence repository backed by a list, no database.
class FakeEvidenceRepository extends EvidenceRepository {
  final List<Evidence> items;
  final List<String> deleted = [];

  FakeEvidenceRepository([List<Evidence>? items])
    : items = items ?? [],
      super(DatabaseService());

  /// Same id replaces, like the real table's ConflictAlgorithm.replace.
  @override
  Future<void> addEvidence(Evidence evidence) async => items
    ..removeWhere((e) => e.id == evidence.id)
    ..add(evidence);

  @override
  Future<List<Evidence>> getEvidence() async => List.of(items);

  @override
  Future<void> deleteEvidence(String id) async {
    deleted.add(id);
    items.removeWhere((e) => e.id == id);
  }
}

/// Contact repository backed by a list, no database.
class FakeContactRepository extends ContactRepository {
  final List<TrustedContact> contacts;
  FakeContactRepository([List<TrustedContact>? contacts])
    : contacts = contacts ?? [],
      super(DatabaseService());

  @override
  Future<void> addContact(TrustedContact contact) async {
    contacts.removeWhere((c) => c.id == contact.id);
    contacts.add(contact);
  }

  @override
  Future<void> deleteContact(String id) async =>
      contacts.removeWhere((c) => c.id == id);

  @override
  Future<List<TrustedContact>> getAllContacts() async => List.of(contacts);

  @override
  Future<List<TrustedContact>> getEmergencyContacts() async =>
      contacts.where((c) => c.isEmergency).toList();
}

TrustedContact contact(String name, String phone) => TrustedContact(
  id: name,
  name: name,
  phone: phone,
  email: '',
  relationship: '',
  isEmergency: true,
);

/// Records SMS requests and answers with [answer].
class FakeSms {
  final List<(List<String>, String)> sent = [];
  SmsStatus answer = SmsStatus.sent;

  Future<SmsDispatch> call(List<String> recipients, String message) async {
    sent.add((recipients, message));
    if (recipients.isEmpty) return const SmsDispatch('no_contacts', {});
    return SmsDispatch('sms', {for (final r in recipients) r: answer});
  }
}

/// Never records: no microphone in tests.
class SilentAudioService extends SecureAudioService {
  @override
  Future<bool> startRecording({bool askPermission = true}) async => false;
}

class FakeLocationService extends LocationService {
  final Position? position;
  int calls = 0;
  FakeLocationService([this.position]);

  @override
  Future<Position?> getLastKnownLocation() async {
    calls++;
    return position;
  }
}

DateTime _todayAt930() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day, 9, 30);
}

Position position(double lat, double lng) => Position(
  latitude: lat,
  longitude: lng,
  timestamp: _todayAt930(),
  accuracy: 10,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

TriggerPanicUseCase panicUseCase({
  required FakeSms sms,
  List<TrustedContact> contacts = const [],
  Position? at,
}) => TriggerPanicUseCase(
  FakeLocationService(at),
  contactRepository: FakeContactRepository(List.of(contacts)),
  audioService: SilentAudioService(),
  evidenceRepository: FakeEvidenceRepository(),
  sendSms: sms.call,
);
