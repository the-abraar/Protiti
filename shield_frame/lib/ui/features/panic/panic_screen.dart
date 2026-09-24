import 'package:flutter/material.dart';

class PanicScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.error,
          padding: EdgeInsets.all(80),
          shape: CircleBorder(),
        ),
        onPressed: () {
          // Trigger panic
        },
        child: Text('PANIC', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
      )
    );
  }
}\n