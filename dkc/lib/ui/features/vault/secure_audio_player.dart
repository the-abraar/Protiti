import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../data/services/secure_audio_service.dart';

/// Plays an encrypted recording. The decrypted copy exists only while it is
/// playing: pause, the end of the track and closing the screen delete it, and
/// the next play decrypts it again from where she paused.
class SecureAudioPlayer extends StatefulWidget {
  final String filePath;
  final AudioPlayer? player;
  const SecureAudioPlayer({super.key, required this.filePath, @visibleForTesting this.player});

  @override
  State<SecureAudioPlayer> createState() => _SecureAudioPlayerState();
}

class _SecureAudioPlayerState extends State<SecureAudioPlayer> {
  late final AudioPlayer _audioPlayer = widget.player ?? AudioPlayer();
  final SecureAudioService _audio = SecureAudioService();
  StreamSubscription<void>? _onComplete;
  File? _plain;
  Duration _resumeAt = Duration.zero;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _onComplete = _audioPlayer.onPlayerComplete.listen((_) {
      _resumeAt = Duration.zero;
      _discard();
    });
  }

  Future<void> _play() async {
    setState(() => _busy = true);
    try {
      _plain = await _audio.decryptForPlayback(widget.filePath);
      if (!mounted) return _discard();
      await _audioPlayer.setSourceDeviceFile(_plain!.path);
      await _audioPlayer.seek(_resumeAt);
      await _audioPlayer.resume();
    } catch (_) {
      await _discard();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to decrypt audio evidence.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pause() async {
    setState(() => _busy = true);
    try {
      _resumeAt = await _audioPlayer.getCurrentPosition() ?? _resumeAt;
      // Stop releases the file before it is deleted.
      await _audioPlayer.stop();
    } finally {
      await _discard();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _discard() async {
    final file = _plain;
    _plain = null;
    if (mounted) setState(() {});
    try {
      if (file != null && await file.exists()) await file.delete();
    } catch (_) {}
  }

  @override
  void dispose() {
    _onComplete?.cancel();
    _audioPlayer.dispose();
    try {
      _plain?.deleteSync();
    } catch (_) {}
    _plain = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playing = _plain != null;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Secure Audio Review', style: TextStyle(fontSize: 14)),
      ),
      body: Center(
        child: _busy
            ? const CircularProgressIndicator(color: Colors.white)
            : IconButton(
                iconSize: 64,
                color: Colors.white,
                tooltip: playing ? 'Pause' : 'Play',
                icon: Icon(playing ? Icons.pause_circle_filled : Icons.play_circle_fill),
                onPressed: playing ? _pause : _play,
              ),
      ),
    );
  }
}
