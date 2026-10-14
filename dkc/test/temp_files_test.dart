import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protiti/data/services/temp_files.dart';

void main() {
  test('the sweep removes playback copies and GD PDFs, and nothing else', () async {
    final temp = Directory.systemTemp.createTempSync('protiti_tmp_');
    final systemTemp = Directory.systemTemp.createTempSync('protiti_sys_');
    addTearDown(() {
      temp.deleteSync(recursive: true);
      systemTemp.deleteSync(recursive: true);
    });
    File touch(String path) => File(path)..createSync(recursive: true);
    final gone = [
      touch('${temp.path}/playback/a.m4a'),
      touch('${temp.path}/share/PROTITI-AB12CD34-1234.pdf'),
      touch('${temp.path}/GD_Complaint_1760400000000.pdf'),
      touch('${systemTemp.path}/PROTITI-AB12CD34-1234.pdf'),
    ];
    final kept = [
      touch('${temp.path}/image_picker_42.jpg'),
      touch('${temp.path}/share/notes.txt'),
      touch('${systemTemp.path}/other.pdf'),
    ];

    await TempFiles.sweepIn(temp, systemTemp);

    for (final f in gone) {
      expect(f.existsSync(), isFalse, reason: f.path);
    }
    expect(Directory('${temp.path}/playback').existsSync(), isFalse);
    for (final f in kept) {
      expect(f.existsSync(), isTrue, reason: f.path);
    }
  });

  test('it sweeps on return from the background, not after an overlay', () {
    var sweeps = 0;
    final observer = SweepOnReturn(() async => sweeps++);

    observer.didChangeAppLifecycleState(AppLifecycleState.inactive);
    observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(sweeps, 0);

    for (final s in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused]) {
      observer.didChangeAppLifecycleState(s);
    }
    observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
    observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(sweeps, 1);
  });
}
