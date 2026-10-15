import 'dart:convert';
import 'dart:io';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:protiti/domain/models/evidence.dart';
import 'package:protiti/domain/use_cases/generate_complaint.dart';
import 'package:protiti/domain/use_cases/pdf_text.dart';

final _hash =
    'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';

Evidence _photo() => Evidence(
  id: 'p',
  type: 'image',
  description: 'Threat in Messenger',
  filePath: '/docs/p.enc',
  url: 'https://facebook.com/x',
  metadata: {
    ...Evidence.captureMetadata(
      source: 'screenshot',
      sha256: _hash,
      capturedAt: DateTime.utc(2026, 10, 14, 3, 30),
    ),
    'platform': 'Facebook',
  },
  createdAt: DateTime(2026, 10, 14),
);

/// A row saved before Oct 2026: the hash it kept is of the ciphertext.
Evidence _old() => Evidence(
  id: 'o',
  type: 'image',
  description: 'Old photo',
  filePath: '/docs/o.enc',
  metadata: {
    'sha256_checksum': 'ff' * 32,
    'capture_device_timestamp': '2026-09-01T04:00:00.000Z',
  },
  createdAt: DateTime(2026, 9, 1),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'each item lists its source, phone-clock time, details and the SHA-256 of the original',
    () {
      expect(GenerateComplaintUseCase.evidenceLines(1, _photo()), [
        '1. Screenshot imported from the gallery',
        "Saved: 2026-10-14 03:30:00 UTC, by this phone's clock",
        'Description: Threat in Messenger',
        'App or platform: Facebook',
        'Link: https://facebook.com/x',
        'SHA-256: $_hash',
      ]);
    },
  );

  test(
    'an older item says its hash was not recorded instead of showing the ciphertext hash',
    () {
      final lines = GenerateComplaintUseCase.evidenceLines(2, _old());
      expect(lines.first, startsWith('2. Type: image (source not recorded'));
      expect(
        lines,
        contains("Saved: 2026-09-01 04:00:00 UTC, by this phone's clock"),
      );
      expect(lines.last, startsWith('SHA-256: not recorded'));
      expect(lines.join(), isNot(contains('ff' * 32)));
    },
  );

  test(
    'the PDF carries the real hashes, says what they prove, and claims no verification',
    () async {
      final result = await GenerateComplaintUseCase().execute(
        [_photo(), _old()],
        {
          'title': 'Extortion',
          'description': 'He threatened me.',
          'station': 'Dhanmondi',
        },
        compress: false,
      );
      final pdf = latin1.decode(result.pdfBytes);

      expect(pdf, startsWith('%PDF'));
      expect(pdf, contains(_hash));
      expect(pdf, contains(pcswEmail));
      expect(pdf, isNot(contains('pcsw@police.gov.bd')));
      for (final word in ['fingerprint', 'recompute', 'clock']) {
        expect(pdf, contains(word), reason: word);
      }
      for (final claim in [
        'Cryptographically',
        'cryptographically',
        'verify digital integrity',
        'Forensic',
        'schema-compliant',
      ]) {
        expect(pdf, isNot(contains(claim)), reason: claim);
      }
      expect(
        pdf,
        isNot(contains('/Subtype/Image')),
        reason: 'Latin text stays text',
      );
      expect(
        pdf,
        isNot(contains('Triage')),
        reason: 'no internal jargon (N13)',
      );
      // The ID is also the shared file's name, so it names no app (N13).
      expect(result.dossierId, matches(RegExp(r'^GD-[A-Z0-9]{8}-[0-9]{4}$')));
    },
  );

  test('Bangla goes in as shaped line images, one per line', () async {
    final result = await GenerateComplaintUseCase().execute([], {
      'description': 'সে আমার ব্যক্তিগত ছবি ছড়িয়ে দেওয়ার হুমকি দিচ্ছে।',
    }, compress: false);
    expect(latin1.decode(result.pdfBytes), contains('/Subtype/Image'));
  });

  test(
    'a description or item longer than a page flows onto more pages, in English and Bangla',
    () async {
      final long = Evidence(
        id: 'l',
        type: 'text',
        description: 'word ' * 3000,
        createdAt: DateTime(2026, 10, 1),
      );
      final en = await GenerateComplaintUseCase().execute(
        [long],
        {'description': 'He wrote again. ' * 400},
      );
      final bn = await GenerateComplaintUseCase().execute([], {
        'description': 'সে আবার হুমকি দিয়েছে। ' * 400,
      });
      expect(
        RegExp(
          '/Type ?/Page[^s]',
        ).allMatches(latin1.decode(en.pdfBytes)).length,
        greaterThan(1),
      );
      expect(
        RegExp(
          '/Type ?/Page[^s]',
        ).allMatches(latin1.decode(bn.pdfBytes)).length,
        greaterThan(1),
      );
    },
  );

  test(
    'pdfText keeps Latin-1 as text and splits other text into line images',
    () async {
      expect(await pdfText('SHA-256: $_hash'), [isA<pw.Text>()]);
      final lines = await pdfText('ক্ষমা ' * 60, width: 200);
      expect(lines.length, greaterThan(3));
      expect(lines, everyElement(isA<pw.Image>()));
    },
  );

  test(
    'the bundled font is registered under the family pdfText asks for, and shapes conjuncts',
    () async {
      expect(
        File('pubspec.yaml').readAsStringSync(),
        contains('family: $banglaFontFamily'),
      );
      final font = File(
        'assets/fonts/NotoSansBengali-Regular.ttf',
      ).readAsBytesSync();
      await (FontLoader(
        banglaFontFamily,
      )..addFont(Future.value(ByteData.sublistView(font)))).load();
      double width(String s) => (TextPainter(
        text: TextSpan(
          text: s,
          style: const TextStyle(fontFamily: banglaFontFamily, fontSize: 40),
        ),
        textDirection: TextDirection.ltr,
      )..layout()).width;
      // Shaped, ক + ্ + ষ is one conjunct glyph, narrower than the two letters side by side.
      expect(width('ক্ষ'), lessThan(width('ক') + width('ষ')));
    },
  );
}
