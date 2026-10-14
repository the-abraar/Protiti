import 'dart:ui' as ui;
import 'package:flutter/painting.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Bundled in assets/fonts (SIL OFL 1.1), so Bangla looks the same on every phone.
const banglaFontFamily = 'NotoSansBengali';

/// A4 (21 cm) minus its 2 cm margins.
const pdfContentWidth = 17 * PdfPageFormat.cm;

/// Paragraph text for the PDF. The pdf package's built-in font covers only
/// Latin-1, and the package does not shape Bengali with any font, so
/// conjuncts and vowel signs come out broken. Latin-1 text stays real PDF
/// text (hashes can be copied); anything else is laid out and shaped by
/// Flutter and placed as one image per line, so pages can still break
/// between lines.
Future<List<pw.Widget>> pdfText(
  String text, {
  double fontSize = 11,
  bool bold = false,
  double width = pdfContentWidth,
  double scale = 3,
}) async {
  if (text.codeUnits.every((c) => c < 0x100)) {
    // span: a long description flows onto the next page instead of failing.
    return [
      pw.Text(text,
          overflow: pw.TextOverflow.span,
          style: pw.TextStyle(fontSize: fontSize, fontWeight: bold ? pw.FontWeight.bold : null)),
    ];
  }
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: banglaFontFamily,
        fontFamilyFallback: const ['Roboto'],
        fontSize: fontSize * scale,
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        height: 1.5,
        color: const Color(0xFF000000),
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: width * scale);

  final lines = painter.computeLineMetrics();
  final out = <pw.Widget>[];
  for (var i = 0; i < lines.length; i++) {
    final top = lines[i].baseline - lines[i].ascent;
    final bottom = i + 1 < lines.length ? lines[i + 1].baseline - lines[i + 1].ascent : painter.height;
    final height = (bottom - top).ceil();
    if (height <= 0) continue;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..translate(0, -top);
    painter.paint(canvas, Offset.zero);
    final image = await recorder.endRecording().toImage((width * scale).ceil(), height);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    out.add(pw.Image(pw.MemoryImage(png!.buffer.asUint8List()), width: width, height: height / scale));
  }
  painter.dispose();
  return out;
}
