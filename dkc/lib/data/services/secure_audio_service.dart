import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../domain/models/evidence.dart';
import '../repositories/evidence_repository.dart';
import 'encryption_service.dart';
import 'evidence_files.dart';
import 'hash_evidence_service.dart';

class SecureAudioService {
  // Lazy, so building the service never touches the microphone plugin.
  late final AudioRecorder _audioRecorder = AudioRecorder();
  final EncryptionService _encryptionService = EncryptionService();
  String? _recordingPath;

  /// Records into the app's private documents directory, never the shared
  /// cache. With [askPermission] false it never shows the OS prompt, which
  /// matters mid-emergency; it just returns false.
  Future<bool> startRecording({bool askPermission = true}) async {
    if (!await _audioRecorder.hasPermission(request: askPermission)) return false;
    final directory = await getApplicationDocumentsDirectory();
    _recordingPath = p.join(directory.path, '${const Uuid().v4()}$recordingExt');
    await _audioRecorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000),
      path: _recordingPath!,
    );
    return true;
  }

  Future<String?> stopAndEncryptRecording() async {
    final path = await _audioRecorder.stop() ?? _recordingPath;
    _recordingPath = null;
    if (path == null) return null;
    return encryptFile(File(path));
  }

  /// Encrypts a plaintext recording into an evidence file beside it, then
  /// deletes the plaintext. shortcut: whole-file base64 in memory; stream it
  /// in chunks before allowing recordings much longer than a few minutes.
  Future<String?> encryptFile(File plain) async {
    if (!await plain.exists()) return null;
    final encryptedData = await _encryptionService.encrypt(base64Encode(await plain.readAsBytes()));
    final secureFile = File(p.join(plain.parent.path, '${const Uuid().v4()}$evidenceExt'));
    await secureFile.writeAsString(encryptedData);
    await plain.delete();
    return secureFile.path;
  }

  Future<Evidence> evidenceFor(String encryptedPath, {required String description, DateTime? createdAt}) async {
    final when = createdAt ?? DateTime.now();
    return Evidence(
      id: p.basenameWithoutExtension(encryptedPath),
      type: 'audio',
      description: description,
      filePath: encryptedPath,
      metadata: {
        'sha256_checksum': await HashEvidenceService.generateFileHash(encryptedPath),
        'capture_device_timestamp': when.toUtc().toIso8601String(),
      },
      createdAt: when,
    );
  }

  /// Stops the current recording and files it as evidence in [repository].
  Future<Evidence?> stopAndSave(EvidenceRepository repository, {required String description}) async {
    final path = await stopAndEncryptRecording();
    if (path == null) return null;
    final evidence = await evidenceFor(path, description: description);
    await repository.addEvidence(evidence);
    return evidence;
  }

  /// Encrypts and files plaintext recordings left behind when the app was
  /// killed mid-recording. Files touched within [minAge] may still be
  /// recording (e.g. from the background service) and wait for the next launch.
  Future<int> recoverPending(
    EvidenceRepository repository, {
    Directory? directory,
    Duration minAge = const Duration(minutes: 3),
  }) async {
    directory ??= await getApplicationDocumentsDirectory();
    var recovered = 0;
    for (final entity in await directory.list().toList()) {
      if (entity is! File || !entity.path.endsWith(recordingExt)) continue;
      final modified = await entity.lastModified();
      if (DateTime.now().difference(modified) < minAge) continue;
      final path = await encryptFile(entity);
      if (path == null) continue;
      await repository.addEvidence(
        await evidenceFor(path, description: 'Recovered recording', createdAt: modified),
      );
      recovered++;
    }
    return recovered;
  }
}
