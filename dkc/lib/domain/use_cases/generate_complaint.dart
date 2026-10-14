import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import '../models/evidence.dart';
import 'pdf_text.dart';

/// Result of generating a GD dossier: the PDF bytes, held only in memory,
/// plus the metadata needed to persist a [Complaint] record.
class GeneratedComplaint {
  final Uint8List pdfBytes;
  final String dossierId;
  final String generatedText;

  GeneratedComplaint({
    required this.pdfBytes,
    required this.dossierId,
    required this.generatedText,
  });
}

/// Police Cyber Support for Women. Source: the Bangladesh Police portal,
/// https://police.portal.gov.bd/pages/static-pages/6922df86933eb65569e228c0
/// (last updated Dec 2023). TODO(owner): verify the number and address with PCSW.
const pcswPhone = '01320000888';
const pcswEmail = 'cybersupport.women@police.gov.bd';

/// What a SHA-256 in this PDF does and does not show. Kept to what anyone
/// can check for themselves.
const hashExplanation =
    'About the SHA-256 values: each one is a fingerprint of the exact file (or, for a typed note, its exact text) '
    'as the phone gave it to Protiti, taken before Protiti changed or encrypted anything. Anyone who has the same '
    'file can recompute it (for example with "sha256sum" on a computer) and compare. A match shows the file is '
    'unchanged since it was saved in Protiti. It does not show who made the file, where it came from or that what it '
    'shows is true. A gallery file can differ from the copy in the gallery if the phone removed data such as location '
    'when handing it over. Times come from this phone\'s clock, which whoever holds the phone can change.';

class GenerateComplaintUseCase {
  /// Dossier IDs must match the schema in
  /// `legal/e_gd_schema_mapping.md`: `^PROTITI-[A-Z0-9]{8}-[0-9]{4}$`.
  static String _generateDossierId() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random.secure();
    final code = List.generate(8, (_) => chars[rand.nextInt(chars.length)]).join();
    final seq = (1000 + rand.nextInt(9000)).toString();
    return 'PROTITI-$code-$seq';
  }

  static final _utc = DateFormat('yyyy-MM-dd HH:mm:ss');

  static const _sourceNames = {
    'camera': 'Camera photo taken in Protiti',
    'gallery': 'Photo imported from the gallery',
    'screenshot': 'Screenshot imported from the gallery',
    'note': 'Note typed in Protiti',
    'audio': 'Audio recorded in Protiti',
  };

  /// The lines the PDF shows for one item, in order. Every claim here comes
  /// from what was stored when she saved the item.
  @visibleForTesting
  static List<String> evidenceLines(int number, Evidence e) => [
        '$number. ${_sourceNames[e.captureSource] ?? 'Type: ${e.type} (source not recorded by older version)'}',
        'Saved: ${_utc.format(e.capturedAt)} UTC, by this phone\'s clock',
        'Description: ${e.description}',
        if (e.platform != null) 'App or platform: ${e.platform}',
        if (e.url != null) 'Link: ${e.url}',
        e.sha256 != null
            ? 'SHA-256: ${e.sha256}'
            : 'SHA-256: not recorded (saved by an older version of the app, before original files were hashed)',
      ];

  Future<GeneratedComplaint> execute(
    List<Evidence> evidence,
    Map<String, dynamic> answers, {
    @visibleForTesting bool compress = true,
  }) async {
    final pdf = pw.Document(compress: compress);

    final dossierId = _generateDossierId();
    // Standard cyber complaints route straight to the e-GD portal path;
    // PCSW/999/CID routing needs the severity intake this wizard doesn't
    // collect yet, so it isn't claimed here.
    const triageRoute = 'EGD_DIRECT';

    String answer(String key, String fallback) {
      final value = (answers[key] as String?)?.trim() ?? '';
      return value.isEmpty ? fallback : value;
    }

    final title = answer('title', 'General Diary Complaint');
    final description = answer('description', 'No description provided.');
    final policeStation = answer('station', 'Officer-in-Charge');
    final generatedAt = DateTime.now().toUtc();

    final items = <pw.Widget>[];
    for (var i = 0; i < evidence.length; i++) {
      final lines = evidenceLines(i + 1, evidence[i]);
      items.add(pw.SizedBox(height: 8));
      for (var j = 0; j < lines.length; j++) {
        final widgets = await pdfText(lines[j], fontSize: j == 0 ? 11 : 9.5, bold: j == 0, width: pdfContentWidth - 12);
        items.addAll(widgets.map((w) => pw.Padding(padding: pw.EdgeInsets.only(left: j == 0 ? 0 : 12), child: w)));
      }
    }

    final body = [
      pw.Header(
        level: 0,
        child: pw.Text(
          'General Diary (GD) Complaint: Draft',
          style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
        ),
      ),
      pw.Text(
        'Dossier ID: $dossierId',
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
      ),
      pw.SizedBox(height: 12),
      pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey700),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        ),
        child: pw.Text(
          'This is an offline draft made by the Protiti app for manual submission. Bangladesh Police do not offer a '
          'public API for GD submission from third-party apps, so this document has NOT been sent to '
          'gd.police.gov.bd or any government system. Present this PDF (printed or digital) to the Duty Officer at '
          'the relevant Thana, or contact Police Cyber Support for Women (PCSW) at $pcswPhone / $pcswEmail.',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800),
        ),
      ),
      pw.SizedBox(height: 16),
      ...await pdfText('To: The Officer-in-Charge, $policeStation'),
      pw.SizedBox(height: 8),
      ...await pdfText('Subject: $title', bold: true),
      pw.SizedBox(height: 16),
      pw.Text('Dear Sir/Madam,'),
      pw.SizedBox(height: 8),
      pw.Text('I, the undersigned, hereby report the following incident:'),
      pw.SizedBox(height: 12),
      ...await pdfText(description),
      pw.SizedBox(height: 20),
      pw.Text(
        'EVIDENCE LISTED (${evidence.length} item${evidence.length == 1 ? '' : 's'}):',
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
      ),
      if (evidence.isEmpty) pw.Text('No evidence listed.'),
      ...items,
      pw.SizedBox(height: 16),
      pw.Text(hashExplanation, style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey800)),
      pw.SizedBox(height: 20),
      pw.Text(
        'Generated by the Protiti app on this phone. Not reviewed by a lawyer.',
        style: const pw.TextStyle(color: PdfColors.grey, fontSize: 9),
      ),
      pw.Text(
        'Generated: ${_utc.format(generatedAt)} UTC, by this phone\'s clock',
        style: const pw.TextStyle(color: PdfColors.grey, fontSize: 9),
      ),
      pw.Text(
        'Triage Route: $triageRoute',
        style: const pw.TextStyle(color: PdfColors.grey, fontSize: 9),
      ),
    ];

    pdf.addPage(pw.MultiPage(pageFormat: PdfPageFormat.a4, build: (_) => body));

    final generatedText =
        'To: $policeStation\nSubject: $title\n\n$description\n\nEvidence listed: ${evidence.length}';

    return GeneratedComplaint(
      pdfBytes: await pdf.save(),
      dossierId: dossierId,
      generatedText: generatedText,
    );
  }
}
