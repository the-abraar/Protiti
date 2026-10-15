import 'package:flutter/material.dart';

/// Explains, in plain words, why the phone is about to ask for a permission.
/// [request] (which shows the OS prompt) runs only if she taps Continue.
Future<bool> explainThenRequest(
  BuildContext context, {
  required String title,
  required String body,
  required Future<bool> Function() request,
}) async {
  final proceed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Not now'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Continue'),
        ),
      ],
    ),
  );
  if (proceed != true) return false;
  return request();
}
