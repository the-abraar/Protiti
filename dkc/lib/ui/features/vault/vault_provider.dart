import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../../data/repositories/evidence_repository.dart';
import '../../../domain/models/evidence.dart';
import '../../../data/services/encryption_service.dart';
import '../../../data/services/secure_audio_service.dart';
import '../../../data/services/evidence_files.dart';

typedef PickImage = Future<XFile?> Function(ImageSource source);

class VaultProvider extends ChangeNotifier {
  final EvidenceRepository _repository;
  final bool isDecoy;
  final PickImage _pickImage;

  List<Evidence> _items = [];
  bool _isLoading = true;
  bool _loadFailed = false;
  bool _pickerOpen = false;

  VaultProvider(this._repository, {required this.isDecoy, PickImage? pickImage})
    : _pickImage =
          pickImage ?? ((source) => ImagePicker().pickImage(source: source)) {
    loadEvidence();
  }

  List<Evidence> get items => _items;
  bool get isLoading => _isLoading;

  /// True when storage could not be opened (fail closed, never an empty fresh vault).
  bool get loadFailed => _loadFailed;

  /// True while the system camera or photo picker that she opened from here
  /// is on screen. It sends the app to the background, which must not lock
  /// the vault and drop the photo (B18).
  bool get pickerOpen => _pickerOpen;

  @override
  void notifyListeners() {
    // A save that finishes after the vault screen closed must still land.
    if (hasListeners) super.notifyListeners();
  }

  Future<void> loadEvidence() async {
    _isLoading = true;
    notifyListeners();

    try {
      _items = await _repository.getEvidence();
      _loadFailed = false;
    } catch (_) {
      _items = [];
      _loadFailed = true;
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addEvidence(Evidence evidence) async {
    await _repository.addEvidence(evidence);
    await loadEvidence(); // Auto-refresh the list
  }

  /// A typed note. Its hash is of the text exactly as saved.
  Future<void> addNote(
    String text, {
    String platform = '',
    String url = '',
  }) async {
    final now = DateTime.now();
    final note = Evidence(
      id: now.millisecondsSinceEpoch.toString(),
      type: 'text',
      description: text,
      createdAt: now,
      isDecoy: isDecoy,
      metadata: isDecoy
          ? null
          : Evidence.captureMetadata(
              source: 'note',
              sha256: sha256.convert(utf8.encode(text)).toString(),
              capturedAt: now,
            ),
    );
    await addEvidence(
      isDecoy
          ? note
          : note.withDetails(description: text, platform: platform, url: url),
    );
  }

  /// Opens the camera or the gallery and stores the file exactly as the OS
  /// hands it over: hashed and encrypted in one pass, never re-encoded and
  /// never stripped of EXIF. [captureSource] is camera, gallery or screenshot.
  /// Returns the saved item, or null if she backed out.
  Future<Evidence?> addImage(
    ImageSource source, {
    required String captureSource,
  }) async {
    if (isDecoy) return null;

    final XFile? photo;
    _pickerOpen = true;
    try {
      photo = await _pickImage(source);
    } finally {
      _pickerOpen = false;
    }
    if (photo == null) return null;

    final picked = File(photo.path);
    try {
      _isLoading = true;
      notifyListeners();

      final now = DateTime.now();
      final id = const Uuid().v4();
      final file = File(
        p.join(
          (await getApplicationDocumentsDirectory()).path,
          '$id$evidenceExt',
        ),
      );
      final hash = await EncryptionService().encryptFile(picked, file);
      final evidence = Evidence(
        id: id,
        type: 'image',
        description: captureSource == 'camera'
            ? 'Camera photo'
            : (captureSource == 'screenshot' ? 'Screenshot' : 'Gallery photo'),
        filePath: file.path,
        metadata: Evidence.captureMetadata(
          source: captureSource,
          sha256: hash,
          capturedAt: now,
        ),
        createdAt: now,
      );
      await _repository.addEvidence(evidence);
      return evidence;
    } finally {
      // The picker's plaintext copy in the cache; the gallery original is hers to delete.
      try {
        if (await picked.exists()) await picked.delete();
      } catch (_) {}
      await loadEvidence();
    }
  }

  /// Saves her description, platform and link on an item already stored.
  Future<void> updateDetails(
    Evidence item, {
    required String description,
    required String platform,
    required String url,
  }) => addEvidence(
    item.withDetails(description: description, platform: platform, url: url),
  );

  Future<Evidence?> captureAndSaveSecureAudio(BuildContext context) async {
    if (isDecoy) return null;

    final audioService = SecureAudioService();
    if (!await audioService.startRecording()) return null;

    // Show a dialog to stop recording
    if (!context.mounted) return null;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Recording Secure Audio...',
          style: TextStyle(color: Colors.red),
        ),
        content: const LinearProgressIndicator(color: Colors.red),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'STOP & SECURE',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    _isLoading = true;
    notifyListeners();

    try {
      return await audioService.stopAndSave(
        _repository,
        description: 'Audio recording',
      );
    } finally {
      await loadEvidence();
    }
  }

  /// Removes the row and its encrypted file.
  Future<void> deleteEvidence(Evidence item) async {
    await _repository.deleteEvidence(item.id);
    final path = item.filePath;
    if (path != null) {
      try {
        await File(path).delete();
      } catch (_) {}
    }
    await loadEvidence();
  }
}
