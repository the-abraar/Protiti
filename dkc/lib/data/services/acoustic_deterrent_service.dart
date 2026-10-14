import 'package:volume_controller/volume_controller.dart';
import 'package:audioplayers/audioplayers.dart';

class AcousticDeterrentService {
  // Created on first use, so opening the SOS screen never touches the audio plugin.
  AudioPlayer? _player;

  /// Maxes out the hardware volume and blares a continuous siren.
  /// This is used to actively scare off an attacker or draw public attention.
  Future<void> triggerLoudSiren() async {
    try {
      // 1. Force the hardware media volume to absolute maximum (1.0)
      await VolumeController.instance.setVolume(1.0);
      
      // 2. Loop a high-decibel siren asset indefinitely
      final player = _player ??= AudioPlayer();
      player.setReleaseMode(ReleaseMode.loop);
      await player.play(AssetSource('audio/siren.mp3'));
    } catch (e) {
      // Fallback
    }
  }

  Future<void> stopSiren() async {
    await _player?.stop();
  }
}
