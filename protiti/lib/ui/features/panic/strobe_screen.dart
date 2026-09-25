import 'dart:async';
import 'package:flutter/material.dart';
import 'package:screen_brightness/screen_brightness.dart';

class StrobeScreen extends StatefulWidget {
  const StrobeScreen({super.key});

  @override
  State<StrobeScreen> createState() => _StrobeScreenState();
}

class _StrobeScreenState extends State<StrobeScreen> {
  bool _isWhite = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // 1. Force the hardware screen brightness to absolute maximum (1.0)
    ScreenBrightness().setApplicationScreenBrightness(1.0);
    
    // 2. Rapidly alternate the screen color every 100ms to create a blinding strobe
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (mounted) {
        setState(() {
          _isWhite = !_isWhite;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    // Return to normal brightness when the strobe is dismissed
    ScreenBrightness().resetApplicationScreenBrightness();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context), // Tap anywhere to stop the strobe
      child: Scaffold(
        backgroundColor: _isWhite ? Colors.white : Colors.black,
        body: Center(
          child: Text(
            'TAP TO STOP STROBE',
            style: TextStyle(
              color: _isWhite ? Colors.black : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
        ),
      ),
    );
  }
}
