import 'dart:io';
import 'package:flutter/material.dart';
import '../../../data/services/encryption_service.dart';

class SecureImageViewer extends StatelessWidget {
  final String filePath;
  final EncryptionService _encryptionService = EncryptionService();

  SecureImageViewer({super.key, required this.filePath});

  /// Decrypted only into memory, never to a file.
  Future<ImageProvider> _decryptImage() async =>
      MemoryImage(await _encryptionService.decryptToBytes(File(filePath)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Secure Evidence Viewer', style: TextStyle(fontSize: 14)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<ImageProvider>(
        future: _decryptImage(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.white));
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.broken_image, color: Colors.grey, size: 50),
                  SizedBox(height: 10),
                  Text('Decryption Failed', style: TextStyle(color: Colors.grey)),
                ],
              )
            );
          }
          
          return Center(
            child: InteractiveViewer(
              minScale: 1.0,
              maxScale: 4.0,
              child: Image(
                image: snapshot.data!,
                fit: BoxFit.contain,
              ),
            ),
          );
        },
      ),
    );
  }
}
