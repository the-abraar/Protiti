import 'package:audioplayers/audioplayers.dart';
import 'package:volume_controller/volume_controller.dart';

class AcousticDeterrentService {
  final AudioPlayer _player = AudioPlayer();

  /// Maxes out the hardware volume and blares a continuous siren.
  /// This is used to actively scare off an attacker or draw public attention.
  Future<void> triggerLoudSiren() async {
    try {
      // 1. Force the hardware media volume to absolute maximum (1.0)
      await VolumeController().setVolume(1.0);
      
      // 2. Loop a high-decibel siren asset indefinitely
      _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(AssetSource('audio/siren.mp3'));
    } catch (e) {
      // Fallback
    }
  }

  Future<void> stopSiren() async {
    await _player.stop();
  }
}
