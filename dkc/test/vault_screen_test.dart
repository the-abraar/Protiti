import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:protiti/domain/models/evidence.dart';
import 'package:protiti/ui/features/auth/lock_screen.dart';
import 'package:protiti/ui/features/vault/vault_provider.dart';
import 'package:protiti/ui/features/vault/vault_screen.dart';

import 'helpers/app_harness.dart';
import 'helpers/fakes.dart';

/// Words that would tell an abuser what the second PIN is, in English and Bangla.
/// The brand counts: searching it finds the public docs that explain the decoy (N3).
final _revealing = RegExp(
  r'decoy|vault|duress|protiti|ভল্ট|ডিকয়|ডুরেস|ছদ্ম|জবরদস্তি|প্রতীতি',
  caseSensitive: false,
);

Iterable<String> _strings(WidgetTester tester) sync* {
  for (final w in tester.allWidgets) {
    if (w is RichText) yield w.text.toPlainText();
    if (w is Tooltip) yield w.message ?? '';
    if (w is IconButton) yield w.tooltip ?? '';
  }
}

Evidence _item(String id, String text, {bool decoy = false}) => Evidence(
  id: id,
  type: 'text',
  description: text,
  createdAt: DateTime(2026, 10, 1),
  isDecoy: decoy,
);

Widget _vault(
  FakeEvidenceRepository repo, {
  required bool decoy,
  Locale locale = const Locale('en'),
  PickImage? pickImage,
}) => harness(
  ChangeNotifierProvider(
    create: (_) => VaultProvider(repo, isDecoy: decoy, pickImage: pickImage),
    child: VaultScreen(isDecoy: decoy),
  ),
  locale: locale,
);

/// App bar title and actions, tab labels and icons, and the button label.
List<Object?> _chrome(WidgetTester tester) => [
  for (final t in tester.widgetList<Text>(
    find.descendant(of: find.byType(AppBar), matching: find.byType(Text)),
  ))
    t.data,
  for (final b in tester.widgetList<IconButton>(
    find.descendant(of: find.byType(AppBar), matching: find.byType(IconButton)),
  ))
    b.tooltip,
  for (final i
      in tester
          .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
          .items) ...[i.label, (i.icon as Icon).icon],
  for (final t in tester.widgetList<Text>(
    find.descendant(
      of: find.byType(FloatingActionButton),
      matching: find.byType(Text),
    ),
  ))
    t.data,
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final storage = FakeSecureStorage();
  setUp(
    () => storage
      ..store.clear()
      ..install(),
  );
  tearDown(storage.uninstall);

  for (final locale in const [Locale('en'), Locale('bn')]) {
    testWidgets(
      'second-PIN view says nothing about a decoy, vault or duress (${locale.languageCode})',
      (tester) async {
        final repo = FakeEvidenceRepository([
          _item('n1', 'Weekly groceries', decoy: true),
        ]);
        await tester.pumpWidget(_vault(repo, decoy: true, locale: locale));
        await tester.pumpAndSettle();

        final seen = <String>[..._strings(tester)];
        for (final icon in [
          Icons.edit_note,
          Icons.health_and_safety_outlined,
          Icons.help_outline,
        ]) {
          await tester.tap(find.byIcon(icon));
          await tester.pump(const Duration(milliseconds: 300));
          seen.addAll(_strings(tester));
        }
        await tester.tap(find.byIcon(Icons.settings_outlined));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
        seen.addAll(_strings(tester));

        expect(seen.where(_revealing.hasMatch), isEmpty);
        expect(seen.where((s) => s.contains('01700000000')), isEmpty);
        // The scan really visited the grid, the safety tab and settings.
        for (final shown in [
          'Weekly groceries',
          'National Emergency Services',
          'Opens as a calculator',
        ]) {
          expect(seen.any((s) => s.contains(shown)), isTrue, reason: shown);
        }
      },
    );
  }

  testWidgets(
    'real and second-PIN views have the same chrome, with no banner',
    (tester) async {
      await tester.pumpWidget(
        _vault(
          FakeEvidenceRepository([_item('e1', 'Threat message')]),
          decoy: false,
        ),
      );
      await tester.pumpAndSettle();
      final real = _chrome(tester);

      await tester.pumpWidget(
        _vault(
          FakeEvidenceRepository([_item('n1', 'Groceries', decoy: true)]),
          decoy: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(_chrome(tester), real);
      expect(find.textContaining('innocent'), findsNothing);
    },
  );

  testWidgets('evidence is deleted only after confirming', (tester) async {
    final repo = FakeEvidenceRepository([
      _item('e1', 'Threat message'),
      _item('e2', 'Fake profile'),
    ]);
    await tester.pumpWidget(_vault(repo, decoy: false));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Delete').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repo.deleted, isEmpty);

    await tester.tap(find.byTooltip('Delete').first);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Delete'),
      ),
    );
    await tester.pumpAndSettle();
    expect(repo.deleted, ['e1']);
    expect(find.text('Threat message'), findsNothing);
    expect(find.text('Fake profile'), findsOneWidget);
  });

  testWidgets(
    'the camera she opened does not lock the vault; leaving the app otherwise does (B18)',
    (tester) async {
      final root = installTempPaths();
      addTearDown(() => root.deleteSync(recursive: true));
      addTearDown(
        () => tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        ),
      );
      final camera = Completer<XFile?>();
      await tester.pumpWidget(
        _vault(
          FakeEvidenceRepository(),
          decoy: false,
          pickImage: (_) => camera.future,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add File'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Secure Camera Capture'));
      await tester.pumpAndSettle();

      // Frames stop while paused, so check what she sees when she comes back.
      Future<void> leaveAndReturn() async {
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
      }

      await leaveAndReturn();
      expect(find.byType(LockScreen), findsNothing);
      camera.complete(null);
      await tester.pumpAndSettle();
      expect(find.byType(VaultScreen), findsOneWidget);

      await leaveAndReturn();
      expect(find.byType(LockScreen), findsOneWidget);
      expect(find.byType(VaultScreen), findsNothing);
    },
  );

  testWidgets(
    'the note field takes any keyboard, learns nothing, and saves a text item with its source',
    (tester) async {
      final repo = FakeEvidenceRepository();
      await tester.pumpWidget(_vault(repo, decoy: false));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add File'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add Text Note'));
      await tester.pumpAndSettle();

      final fields = tester
          .widgetList<TextField>(find.byType(TextField))
          .toList();
      expect(fields, hasLength(3));
      for (final f in fields) {
        expect(
          f.keyboardType,
          isNot(TextInputType.visiblePassword),
          reason: 'hides the language switch on many IMEs',
        );
        expect(f.enableIMEPersonalizedLearning, isFalse);
        expect(f.enableSuggestions, isFalse);
      }
      await tester.enterText(
        find.widgetWithText(TextField, 'Evidence Description'),
        'হুমকির বার্তা',
      );
      await tester.enterText(
        find.widgetWithText(
          TextField,
          'App or platform, e.g. Facebook (optional)',
        ),
        'Facebook',
      );
      await tester.enterText(
        find.widgetWithText(
          TextField,
          'Link to the post or profile (optional)',
        ),
        'https://fb.com/x',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final note = repo.items.single;
      expect(
        (note.type, note.captureSource, note.platform, note.url),
        ('text', 'note', 'Facebook', 'https://fb.com/x'),
      );
      expect(
        note.sha256,
        sha256.convert(utf8.encode('হুমকির বার্তা')).toString(),
      );
    },
  );

  testWidgets('a photo is saved first, then she can add the platform and link', (
    tester,
  ) async {
    final root = installTempPaths();
    addTearDown(() => root.deleteSync(recursive: true));
    final repo = FakeEvidenceRepository();
    final photo = File('${root.path}/tmp/image_picker_7.jpg')
      ..writeAsBytesSync([0xFF, 0xD8, 1, 2]);
    await tester.pumpWidget(
      _vault(repo, decoy: false, pickImage: (_) async => XFile(photo.path)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add File'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('Secure Camera Capture'));
      for (var i = 0; i < 50 && repo.items.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await tester.pumpAndSettle();
    expect(
      repo.items.single.description,
      'Camera photo',
      reason: 'saved before the details dialog',
    );

    await tester.enterText(
      find.widgetWithText(
        TextField,
        'App or platform, e.g. Facebook (optional)',
      ),
      'Imo',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    // The capture flow started inside runAsync, so its next step runs on the real event loop.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    final row = repo.items.single;
    expect(
      (row.description, row.platform, row.captureSource),
      ('Camera photo', 'Imo', 'camera'),
    );
    expect(row.sha256, sha256.convert([0xFF, 0xD8, 1, 2]).toString());
  });

  testWidgets(
    'details show the source, the phone-clock time and the SHA-256, or say it was not recorded',
    (tester) async {
      final hash = 'ab' * 32;
      final repo = FakeEvidenceRepository([
        Evidence(
          id: 'n',
          type: 'text',
          description: 'Threat message',
          createdAt: DateTime(2026, 10, 1),
          metadata: Evidence.captureMetadata(
            source: 'note',
            sha256: hash,
            capturedAt: DateTime.utc(2026, 10, 1, 4, 5, 6),
          ),
        ),
        _item('old', 'Older note'),
      ]);
      await tester.pumpWidget(_vault(repo, decoy: false));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Threat message'));
      await tester.pumpAndSettle();
      for (final shown in [
        'Typed note',
        '2026-10-01 04:05:06',
        hash,
        "Saved at (this phone's clock, UTC)",
      ]) {
        expect(find.text(shown), findsOneWidget, reason: shown);
      }
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Details').last);
      await tester.pumpAndSettle();
      expect(
        find.text('Not recorded (saved by an older version)'),
        findsOneWidget,
      );
    },
  );
}
