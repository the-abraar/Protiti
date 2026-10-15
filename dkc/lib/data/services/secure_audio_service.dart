import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../domain/models/evidence.dart';
import '../repositories/evidence_repository.dart';
import 'encryption_service.dart';
import 'evidence_files.dart';
import 'temp_files.dart';

class SecureAudioService {
  // Lazy, so building the service never touches the microphone plugin.
  late final AudioRecorder _audioRecorder = AudioRecorder();
  final EncryptionService _encryptionService = EncryptionService();
  String? _recordingPath;
  DateTime? _startedAt;

  /// Records into the app's private documents directory, never the shared
  /// cache. With [askPermission] false it never shows the OS prompt, which
  /// matters mid-emergency; it just returns false.
  Future<bool> startRecording({bool askPermission = true}) async {
    if (!await _audioRecorder.hasPermission(request: askPermission)) {
      return false;
    }
    final directory = await getApplicationDocumentsDirectory();
    _recordingPath = p.join(
      directory.path,
      '${const Uuid().v4()}$recordingExt',
    );
    _startedAt = DateTime.now();
    await _audioRecorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000),
      path: _recordingPath!,
    );
    return true;
  }

  /// Encrypts a finished recording into an evidence file beside it and
  /// deletes the plaintext. The hash is of the recording as the recorder
  /// wrote it, taken while encrypting.
  Future<Evidence?> fileRecording(
    File plain, {
    required String description,
    required DateTime capturedAt,
  }) async {
    if (!await plain.exists()) return null;
    final secureFile = File(
      p.join(plain.parent.path, '${const Uuid().v4()}$evidenceExt'),
    );
    final hash = await _encryptionService.encryptFile(plain, secureFile);
    await plain.delete();
    return Evidence(
      id: p.basenameWithoutExtension(secureFile.path),
      type: 'audio',
      description: description,
      filePath: secureFile.path,
      metadata: Evidence.captureMetadata(
        source: 'audio',
        sha256: hash,
        capturedAt: capturedAt,
      ),
      createdAt: capturedAt,
    );
  }

  /// Stops the current recording and files it as evidence in [repository].
  Future<Evidence?> stopAndSave(
    EvidenceRepository repository, {
    required String description,
  }) async {
    final path = await _audioRecorder.stop() ?? _recordingPath;
    final startedAt = _startedAt ?? DateTime.now();
    _recordingPath = null;
    _startedAt = null;
    if (path == null) return null;
    final evidence = await fileRecording(
      File(path),
      description: description,
      capturedAt: startedAt,
    );
    if (evidence != null) await repository.addEvidence(evidence);
    return evidence;
  }

  /// Decrypts a recording for the player into its own temp folder. The
  /// player deletes it on pause, stop and close; [TempFiles.sweep] removes
  /// anything left by a crash.
  Future<File> decryptForPlayback(String encryptedPath) async {
    final dir = await TempFiles.playbackDir();
    await dir.create(recursive: true);
    final out = File(p.join(dir.path, '${const Uuid().v4()}$recordingExt'));
    try {
      await _encryptionService.decryptToFile(File(encryptedPath), out);
    } catch (_) {
      if (await out.exists()) await out.delete();
      rethrow;
    }
    return out;
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
      // The app was killed mid-recording, so only the file's last write time is known.
      final evidence = await fileRecording(
        entity,
        description:
            'Recovered recording (time is when the file was last written)',
        capturedAt: modified,
      );
      if (evidence == null) continue;
      await repository.addEvidence(evidence);
      recovered++;
    }
    return recovered;
  }
}
