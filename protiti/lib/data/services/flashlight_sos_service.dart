import 'dart:async';
import 'package:torch_light/torch_light.dart';

class FlashlightSosService {
  bool _isFlashing = false;

  /// Arms the camera hardware LED to broadcast a high-visibility SOS pattern.
  Future<void> startVisualSos() async {
    try {
      if (await TorchLight.isTorchAvailable()) {
        _isFlashing = true;
        _flashLoop();
      }
    } catch (e) {
      // Graceful fail if the device lacks a camera flash or is hardware-locked
    }
  }

  void _flashLoop() async {
    while (_isFlashing) {
      // Standard SOS Morse Code: 3 Short (...), 3 Long (---), 3 Short (...)
      await _emitMorsePulse(
        [200, 200, 200], // Short pulses (milliseconds)
        [600, 600, 600], // Long pulses
        [200, 200, 200]  // Short pulses
      );
      // Wait 2 seconds before repeating the SOS sequence
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  Future<void> _emitMorsePulse(List<int> shortMs, List<int> longMs, List<int> shortEndMs) async {
    final sequence = [...shortMs, ...longMs, ...shortEndMs];
    
    for (int duration in sequence) {
      if (!_isFlashing) break;
      
      await TorchLight.enableTorch();
      await Future.delayed(Duration(milliseconds: duration));
      await TorchLight.disableTorch();
      
      // Pause between individual flashes
      await Future.delayed(const Duration(milliseconds: 300));
    }
  }

  Future<void> stopVisualSos() async {
    _isFlashing = false;
    try {
      await TorchLight.disableTorch();
    } catch (e) {
      // Ignore
    }
  }
}
