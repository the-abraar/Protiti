import 'dart:io';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import '../models/evidence.dart';

import 'dart:convert';
import 'package:crypto/crypto.dart';

class GenerateComplaintUseCase {
  Future<String> execute(
    List<Evidence> evidence,
    Map<String, dynamic> answers,
  ) async {
    final pdf = pw.Document();

    final title = answers['title'] ?? 'General Diary Complaint';
    final description = answers['description'] ?? 'No description provided.';
    final policeStation = answers['station'] ?? 'Officer-in-Charge';
    final timestamp = DateTime.now().toIso8601String();

    // Generate SHA-256 hash for evidence
    List<Map<String, String>> hashedEvidence = [];
    for (var e in evidence) {
      final input = '${e.id}_${e.type}_${e.description}';
      final hash = sha256.convert(utf8.encode(input)).toString();
      hashedEvidence.add({
        'type': e.type,
        'description': e.description,
        'hash': hash,
      });
    }

    // Generate a master verification hash
    final masterInput =
        '$title|$description|$policeStation|$timestamp|${hashedEvidence.map((e) => e['hash']).join(',')}';
    final masterHash = sha256.convert(utf8.encode(masterInput)).toString();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Text(
                'Formal General Diary (GD) Complaint',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 16),
            pw.Text('To: The Officer-in-Charge, $policeStation'),
            pw.SizedBox(height: 8),
            pw.Text(
              'Subject: $title',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 16),
            pw.Text('Dear Sir/Madam,'),
            pw.SizedBox(height: 8),
            pw.Text(
              'I, the undersigned, hereby report the following incident:',
            ),
            pw.SizedBox(height: 12),
            pw.Paragraph(text: description),
            pw.SizedBox(height: 20),
            pw.Text(
              'EVIDENCE ATTACHED (Cryptographically Hashed):',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16),
            ),
            pw.SizedBox(height: 10),
            if (hashedEvidence.isEmpty) pw.Text('No evidence attached.'),
            ...hashedEvidence
                .map(
                  (e) => pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 8),
                    child: pw.Bullet(
                      text:
                          'Type: ${e['type']?.toUpperCase()} | Desc: ${e['description']}\nSHA-256: ${e['hash']}',
                    ),
                  ),
                ),
            pw.SizedBox(height: 30),
            pw.Center(
              child: pw.Column(
                children: [
                  pw.BarcodeWidget(
                    data: masterHash,
                    barcode: pw.Barcode.qrCode(),
                    width: 100,
                    height: 100,
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Scan to verify digital integrity',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 30),
            pw.Text(
              'Generated securely via Protiti Forensic Vault',
              style: const pw.TextStyle(color: PdfColors.grey, fontSize: 10),
            ),
            pw.Text(
              'Timestamp: $timestamp',
              style: const pw.TextStyle(color: PdfColors.grey, fontSize: 10),
            ),
            pw.Text(
              'Verification Hash: $masterHash',
              style: const pw.TextStyle(color: PdfColors.grey, fontSize: 8),
            ),
          ];
        },
      ),
    );

    final tempDir = await getTemporaryDirectory();
    final file = File(
      '${tempDir.path}/GD_Complaint_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await file.writeAsBytes(await pdf.save());

    return file.path;
  }
}
