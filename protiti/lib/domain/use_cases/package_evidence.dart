import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:path_provider/path_provider.dart';
import '../models/evidence.dart';

class PackageEvidenceUseCase {
  Future<String> execute(List<Evidence> evidence) async {
    final archive = Archive();
    final summaryBuffer = StringBuffer();
    
    summaryBuffer.writeln('PROTITI EVIDENCE REPORT');
    summaryBuffer.writeln('Generated: ${DateTime.now().toIso8601String()}');
    summaryBuffer.writeln('----------------------------------------');
    
    for (var item in evidence) {
      summaryBuffer.writeln('ID: ${item.id}');
      summaryBuffer.writeln('Type: ${item.type}');
      summaryBuffer.writeln('Description: ${item.description}');
      summaryBuffer.writeln('Date: ${item.createdAt.toIso8601String()}');
      summaryBuffer.writeln('----------------------------------------');
      
      if (item.filePath != null) {
        final file = File(item.filePath!);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          final fileName = item.filePath!.split('/').last;
          archive.addFile(ArchiveFile(fileName, bytes.length, bytes));
        }
      }
    }
    
    final reportBytes = summaryBuffer.toString().codeUnits;
    archive.addFile(ArchiveFile('summary_report.txt', reportBytes.length, reportBytes));
    
    final zipEncoder = ZipFileEncoder();
    final tempDir = await getTemporaryDirectory();
    final zipPath = '${tempDir.path}/evidence_package_${DateTime.now().millisecondsSinceEpoch}.zip';
    
    zipEncoder.create(zipPath);
    for (final file in archive) {
      if (file.isFile) {
        zipEncoder.addArchiveFile(file);
      }
    }
    zipEncoder.close();
    
    return zipPath;
  }
}
