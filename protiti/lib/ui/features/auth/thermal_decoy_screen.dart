import 'package:flutter/material.dart';

class ThermalDecoyScreen extends StatefulWidget {
  const ThermalDecoyScreen({super.key});

  @override
  State<ThermalDecoyScreen> createState() => _ThermalDecoyScreenState();
}

class _ThermalDecoyScreenState extends State<ThermalDecoyScreen> {
  @override
  void initState() {
    super.initState();
    // Automatically fade to absolute black after 5 seconds to simulate a hardware thermal shutdown
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        // You can combine this with the ScreenBrightness plugin to force 0.0 hardware brightness!
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation1, animation2) => Container(color: Colors.black),
            transitionDuration: Duration.zero,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // This UI strictly mimics the native iOS/Android emergency thermal lockout screens
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.thermostat, color: Colors.redAccent, size: 64),
            SizedBox(height: 20),
            Text(
              'Temperature',
              style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              'Device needs to cool down\nbefore you can use it.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}
