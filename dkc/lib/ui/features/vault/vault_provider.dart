import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../../data/repositories/evidence_repository.dart';
import '../../../domain/models/evidence.dart';
import '../../../domain/use_cases/analyze_evidence_use_case.dart';
import '../../../data/services/jev_service.dart';
import '../../../data/services/encryption_service.dart';
import '../../../data/services/cloud_backup_service.dart';
import '../../../data/services/secure_audio_service.dart';
import '../../../data/services/hash_evidence_service.dart';
import '../../../data/services/decoy_generator_service.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class VaultProvider extends ChangeNotifier {
  final EvidenceRepository _repository;
  final bool isDecoy;
  
  List<Evidence> _items = [];
  bool _isLoading = true;

  VaultProvider(this._repository, {required this.isDecoy}) {
    loadEvidence();
  }

  List<Evidence> get items => _items;
  bool get isLoading => _isLoading;

  Future<void> loadEvidence() async {
    _isLoading = true;
    notifyListeners();
    
    _items = await _repository.getEvidence();

    // If the decoy vault is suspiciously empty, dynamically generate organic content
    if (isDecoy && _items.isEmpty) {
      final decoyService = DecoyGeneratorService(_repository);
      await decoyService.seedDynamicDecoys();
      // Reload the newly seeded items
      _items = await _repository.getEvidence();
    }
    
    _isLoading = false;
    notifyListeners();
    
    // Fire-and-forget background cloud sync (only for real vault)
    if (!isDecoy && _items.isNotEmpty) {
      final backupService = CloudBackupService(EncryptionService());
      backupService.performZeroKnowledgeBackup(_items);
    }
  }

  Future<void> addEvidence(Evidence evidence) async {
    // Only run expensive AI analysis if it's real evidence, not decoy grocery lists
    if (!evidence.isDecoy) {
      try {
        final analysisCase = AnalyzeEvidenceUseCase(JevService('DKC_DEMO_API_KEY'));
        final analysisResult = await analysisCase.call(evidence.description);
        
        // Enrich the evidence with the AI classification metadata
        final enrichedEvidence = Evidence(
          id: evidence.id,
          type: evidence.type,
          description: '${evidence.description}\n\n[AI Classification: ${analysisResult.harassmentType.toUpperCase()} | Severity: ${analysisResult.severityScore}/10]',
          createdAt: evidence.createdAt,
          isDecoy: evidence.isDecoy,
        );

        await _repository.addEvidence(enrichedEvidence);
      } catch (e) {
        // Fallback to standard save if AI network fails
        await _repository.addEvidence(evidence);
      }
    } else {
      // Save decoy evidence normally
      await _repository.addEvidence(evidence);
    }
    
    await loadEvidence(); // Auto-refresh the list
  }
  
  Future<void> captureAndSaveSecureImage() async {
    // Only allow real evidence to use the secure camera pipeline
    if (isDecoy) return; 

    final picker = ImagePicker();
    // Force camera source to prevent picking from compromised public galleries
    final photo = await picker.pickImage(source: ImageSource.camera);
    if (photo == null) return;

    try {
      _isLoading = true;
      notifyListeners();

      // 1. Read image to memory
      final rawBytes = await photo.readAsBytes();
      
      // FORENSIC SANITIZATION: Strip all EXIF metadata (GPS coords, device model) 
      // to protect the victim's safe house location before the evidence is permanently sealed.
      final sanitizedBytes = await FlutterImageCompress.compressWithList(
        rawBytes,
        keepExif: false, // CRITICAL: Drops all geolocation and device tags!
        quality: 90,
      );

      final base64Image = base64Encode(sanitizedBytes);

      // 2. Encrypt the raw image data via our AES service
      final encryptionService = EncryptionService();
      final encryptedData = await encryptionService.encrypt(base64Image);

      // 3. Save ciphertext to isolated app documents directory
      final directory = await getApplicationDocumentsDirectory();
      final fileName = const Uuid().v4();
      final file = File('${directory.path}/$fileName.bin');
      await file.writeAsString(encryptedData);

      // 1. Generate Cryptographic Signature
      final fileHash = await HashEvidenceService.generateFileHash(file.path);

      // 4. Create database record
      final evidence = Evidence(
        id: fileName,
        type: 'image',
        description: 'Secure Camera Capture',
        filePath: file.path,
        metadata: {
          'sha256_checksum': fileHash,
          'capture_device_timestamp': DateTime.now().toUtc().toIso8601String(),
        },
        createdAt: DateTime.now(),
        isDecoy: false,
      );

      // Pass through our existing addEvidence method (which also triggers the AI)
      await addEvidence(evidence);

    } finally {
      // 5. FORENSIC WIPE: Delete the unencrypted cache file generated by ImagePicker
      final cacheFile = File(photo.path);
      if (cacheFile.existsSync()) {
        cacheFile.deleteSync();
      }
      
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Imports an existing photo from the public gallery, encrypts it, 
  /// and ensures the victim is warned to delete the unencrypted original.
  Future<bool> importAndScrubGalleryImage() async {
    if (isDecoy) return false; 

    final picker = ImagePicker();
    // Allow picking from the compromised public gallery
    final photo = await picker.pickImage(source: ImageSource.gallery);
    if (photo == null) return false;

    try {
      _isLoading = true;
      notifyListeners();

      final rawBytes = await photo.readAsBytes();
      
      // 1. Scrub EXIF Metadata
      final sanitizedBytes = await FlutterImageCompress.compressWithList(
        rawBytes,
        keepExif: false,
        quality: 90,
      );

      // 2. Encrypt and Save
      final base64Image = base64Encode(sanitizedBytes);
      final encryptionService = EncryptionService();
      final encryptedData = await encryptionService.encrypt(base64Image);

      final directory = await getApplicationDocumentsDirectory();
      final fileName = const Uuid().v4();
      final file = File('${directory.path}/$fileName.bin');
      await file.writeAsString(encryptedData);

      // 3. Generate Cryptographic Hash and Save to DB
      final fileHash = await HashEvidenceService.generateFileHash(file.path);
      final evidence = Evidence(
        id: fileName,
        type: 'image',
        description: 'Secure Gallery Import',
        filePath: file.path,
        metadata: {
          'sha256_checksum': fileHash,
          'capture_device_timestamp': DateTime.now().toUtc().toIso8601String(),
          'source': 'gallery_import',
        },
        createdAt: DateTime.now(),
        isDecoy: false,
      );

      await addEvidence(evidence);
      
      // Return true to indicate a successful import so the UI can trigger the warning
      return true;

    } finally {
      // Clear the temporary cache from the image picker
      final cacheFile = File(photo.path);
      if (cacheFile.existsSync()) cacheFile.deleteSync();
      
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> captureAndSaveSecureAudio(BuildContext context) async {
    if (isDecoy) return;
    
    final audioService = SecureAudioService();
    await audioService.startRecording();
    
    // Show a dialog to stop recording
    if (!context.mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Recording Secure Audio...', style: TextStyle(color: Colors.red)),
        content: const LinearProgressIndicator(color: Colors.red),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('STOP & SECURE', style: TextStyle(color: Colors.white)),
          )
        ],
      )
    );
    
    _isLoading = true;
    notifyListeners();
    
    try {
      final securePath = await audioService.stopAndEncryptRecording();
      if (securePath != null) {
        final fileName = securePath.split('/').last;
        final fileHash = await HashEvidenceService.generateFileHash(securePath);
        final evidence = Evidence(
          id: fileName,
          type: 'audio',
          description: 'Secure Audio Wiretap',
          filePath: securePath,
          metadata: {
            'sha256_checksum': fileHash,
            'capture_device_timestamp': DateTime.now().toUtc().toIso8601String(),
          },
          createdAt: DateTime.now(),
          isDecoy: false,
        );
        await addEvidence(evidence);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteEvidence(String id) async {
    await _repository.deleteEvidence(id);
    await loadEvidence(); // Auto-refresh the list
  }
}
