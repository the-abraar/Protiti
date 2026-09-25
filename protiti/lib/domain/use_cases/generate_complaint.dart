import 'dart:io';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import '../models/evidence.dart';

class GenerateComplaintUseCase {
  Future<String> execute(List<Evidence> evidence, Map<String, dynamic> answers) async {
    final pdf = pw.Document();
    
    final title = answers['title'] ?? 'General Diary Complaint';
    final description = answers['description'] ?? 'No description provided.';
    final policeStation = answers['station'] ?? 'Officer-in-Charge';
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Text('Formal General Diary (GD) Complaint', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 16),
            pw.Text('To: The Officer-in-Charge, $policeStation'),
            pw.SizedBox(height: 8),
            pw.Text('Subject: $title', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 16),
            pw.Text('Dear Sir/Madam,'),
            pw.SizedBox(height: 8),
            pw.Text('I, the undersigned, hereby report the following incident:'),
            pw.SizedBox(height: 12),
            pw.Paragraph(text: description),
            pw.SizedBox(height: 20),
            pw.Text('EVIDENCE ATTACHED:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
            pw.SizedBox(height: 10),
            ...evidence.map((e) => pw.Bullet(
              text: 'Type: ${e.type.toUpperCase()} | Desc: ${e.description} | Hash ID: ${e.id}',
            )).toList(),
            pw.SizedBox(height: 30),
            pw.Text('Generated securely via Protiti Forensic Vault', style: const pw.TextStyle(color: PdfColors.grey, fontSize: 10)),
            pw.Text('Timestamp: ${DateTime.now().toIso8601String()}', style: const pw.TextStyle(color: PdfColors.grey, fontSize: 10)),
          ];
        }
      )
    );
    
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/GD_Complaint_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());
    
    return file.path;
  }
}
