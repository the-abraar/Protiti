import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Plaintext that exists only for a moment: decrypted audio while it plays,
/// and the GD PDF copy the share sheet reads. Each is removed after use;
/// [sweep] runs at launch and on every return to the app, for anything a
/// crash or a slow share target left behind.
class TempFiles {
  static Future<Directory> playbackDir() async =>
      Directory(p.join((await getTemporaryDirectory()).path, 'playback'));

  /// GD PDFs: our dossier name, and the names older builds used.
  static final _pdf = RegExp(r'^((GD|PROTITI)-[A-Z0-9]{8}-\d{4}|GD_Complaint_\d+)\.pdf$');

  static Future<void> sweep() async {
    try {
      await sweepIn(await getTemporaryDirectory(), Directory.systemTemp);
    } catch (_) {}
  }

  /// printing's sharePdf writes its copy to `<cache>/share/` on Android and to
  /// the process temp dir on iOS (printing 5.14: PrintingJob.java, PrintJob.swift).
  @visibleForTesting
  static Future<void> sweepIn(Directory temp, Directory systemTemp) async {
    await _delete(Directory(p.join(temp.path, 'playback')));
    for (final dir in [temp, Directory(p.join(temp.path, 'share')), systemTemp]) {
      for (final f in await _list(dir)) {
        if (f is File && _pdf.hasMatch(p.basename(f.path))) await _delete(f);
      }
    }
  }

  static Future<List<FileSystemEntity>> _list(Directory dir) async {
    try {
      return await dir.list().toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> _delete(FileSystemEntity entity) async {
    try {
      if (await entity.exists()) await entity.delete(recursive: true);
    } catch (_) {}
  }
}

/// Runs [sweep] each time the app comes back from the background: on Android
/// that is the return from the share target, which has read the PDF by then.
/// iOS share extensions run over the app without backgrounding it, so their
/// copy waits for the next real return or launch.
class SweepOnReturn with WidgetsBindingObserver {
  final Future<void> Function() sweep;
  bool _wasInBackground = false;
  SweepOnReturn(this.sweep);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) _wasInBackground = true;
    if (state == AppLifecycleState.resumed && _wasInBackground) {
      _wasInBackground = false;
      sweep();
    }
  }
}
