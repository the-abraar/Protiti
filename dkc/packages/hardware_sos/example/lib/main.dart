import 'package:flutter/material.dart';
import 'dart:async';

import 'package:hardware_sos/hardware_sos.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _lastEvent = 'Waiting for hardware SOS trigger...';
  final _hardwareSosPlugin = HardwareSos();
  StreamSubscription<String>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = _hardwareSosPlugin.sosEvents.listen(
      (event) {
        if (!mounted) return;
        setState(() => _lastEvent = event);
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() => _lastEvent = 'Error listening for SOS events: $error');
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Plugin example app')),
        body: Center(child: Text('Last SOS event: $_lastEvent\n')),
      ),
    );
  }
}
