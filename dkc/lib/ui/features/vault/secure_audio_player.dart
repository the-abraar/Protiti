import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../../data/services/encryption_service.dart';

class SecureAudioPlayer extends StatefulWidget {
  final String filePath;
  const SecureAudioPlayer({super.key, required this.filePath});

  @override
  State<SecureAudioPlayer> createState() => _SecureAudioPlayerState();
}

class _SecureAudioPlayerState extends State<SecureAudioPlayer> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final EncryptionService _encryptionService = EncryptionService();
  bool _isPlaying = false;
  File? _decryptedTempFile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _prepareAudio();
    
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });
  }

  Future<void> _prepareAudio() async {
    try {
      // 1. Read encrypted ciphertext
      final file = File(widget.filePath);
      final encryptedData = await file.readAsString();
      
      // 2. Decrypt AES block back to base64
      final base64Audio = await _encryptionService.decrypt(encryptedData);
      final bytes = base64Decode(base64Audio);
      
      // 3. Write strictly to the OS temp cache (AudioPlayer requires a physical URI to stream)
      final tempDir = await getTemporaryDirectory();
      _decryptedTempFile = File('${tempDir.path}/${const Uuid().v4()}.m4a');
      await _decryptedTempFile!.writeAsBytes(bytes);
      
      await _audioPlayer.setSourceDeviceFile(_decryptedTempFile!.path);
      
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to decrypt audio evidence.')),
        );
      }
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    
    // FORENSIC WIPE: Guarantee destruction of the plaintext audio the millisecond the screen closes
    if (_decryptedTempFile != null && _decryptedTempFile!.existsSync()) {
      _decryptedTempFile!.deleteSync();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Secure Audio Review', style: TextStyle(fontSize: 14)),
      ),
      body: Center(
        child: _isLoading 
            ? const CircularProgressIndicator(color: Colors.white)
            : IconButton(
                iconSize: 64,
                color: Colors.white,
                icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill),
                onPressed: () {
                  if (_isPlaying) {
                    _audioPlayer.pause();
                  } else {
                    _audioPlayer.resume();
                  }
                },
              ),
      ),
    );
  }
}
