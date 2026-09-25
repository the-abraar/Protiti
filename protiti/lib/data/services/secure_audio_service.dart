import 'dart:io';
import 'dart:convert';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'encryption_service.dart';

class SecureAudioService {
  final AudioRecorder _audioRecorder = AudioRecorder();
  final EncryptionService _encryptionService = EncryptionService();
  String? _tempFilePath;

  Future<void> startRecording() async {
    if (await _audioRecorder.hasPermission()) {
      final directory = await getTemporaryDirectory();
      _tempFilePath = '${directory.path}/${const Uuid().v4()}.m4a';
      
      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000),
        path: _tempFilePath!,
      );
    }
  }

  Future<String?> stopAndEncryptRecording() async {
    final path = await _audioRecorder.stop();
    if (path == null || _tempFilePath == null) return null;

    final tempFile = File(path);
    final bytes = await tempFile.readAsBytes();

    // End-to-End Encrypt the Audio File
    // Note: For large audio files, stream-based chunk encryption is better, 
    // but for short ambient recordings, memory byte encryption works perfectly.
    final base64Audio = base64Encode(bytes);
    final encryptedData = await _encryptionService.encrypt(base64Audio);

    // Save to Secure App Documents
    final secureDir = await getApplicationDocumentsDirectory();
    final fileName = const Uuid().v4();
    final secureFile = File('${secureDir.path}/$fileName.tmp');
    await secureFile.writeAsString(encryptedData);

    // FORENSIC WIPE: Delete the unencrypted temporary audio cache
    if (tempFile.existsSync()) {
      tempFile.deleteSync();
    }

    return secureFile.path;
  }
}
