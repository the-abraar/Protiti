import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:protiti/domain/models/evidence.dart';
import 'package:protiti/ui/features/vault/vault_provider.dart';
import 'package:protiti/ui/features/vault/vault_screen.dart';

import 'helpers/app_harness.dart';
import 'helpers/fakes.dart';

/// Words that would tell an abuser what the second PIN is, in English and Bangla.
final _revealing = RegExp(r'decoy|vault|duress|ভল্ট|ডিকয়|ডুরেস|ছদ্ম|জবরদস্তি', caseSensitive: false);

Iterable<String> _strings(WidgetTester tester) sync* {
  for (final w in tester.allWidgets) {
    if (w is RichText) yield w.text.toPlainText();
    if (w is Tooltip) yield w.message ?? '';
    if (w is IconButton) yield w.tooltip ?? '';
  }
}

Evidence _item(String id, String text, {bool decoy = false}) =>
    Evidence(id: id, type: 'text', description: text, createdAt: DateTime(2026, 10, 1), isDecoy: decoy);

Widget _vault(FakeEvidenceRepository repo, {required bool decoy, Locale locale = const Locale('en')}) => harness(
      ChangeNotifierProvider(
        create: (_) => VaultProvider(repo, isDecoy: decoy),
        child: VaultScreen(isDecoy: decoy),
      ),
      locale: locale,
    );

/// App bar title and actions, tab labels and icons, and the button label.
List<Object?> _chrome(WidgetTester tester) => [
      for (final t in tester.widgetList<Text>(find.descendant(of: find.byType(AppBar), matching: find.byType(Text))))
        t.data,
      for (final b in tester.widgetList<IconButton>(find.descendant(of: find.byType(AppBar), matching: find.byType(IconButton))))
        b.tooltip,
      for (final i in tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar)).items) ...[
        i.label,
        (i.icon as Icon).icon,
      ],
      for (final t in tester.widgetList<Text>(find.descendant(of: find.byType(FloatingActionButton), matching: find.byType(Text))))
        t.data,
    ];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final storage = FakeSecureStorage();
  setUp(() => storage
    ..store.clear()
    ..install());
  tearDown(storage.uninstall);

  for (final locale in const [Locale('en'), Locale('bn')]) {
    testWidgets('second-PIN view says nothing about a decoy, vault or duress (${locale.languageCode})', (tester) async {
      final repo = FakeEvidenceRepository([_item('n1', 'Weekly groceries', decoy: true)]);
      await tester.pumpWidget(_vault(repo, decoy: true, locale: locale));
      await tester.pumpAndSettle();

      final seen = <String>[..._strings(tester)];
      for (final icon in [Icons.edit_note, Icons.health_and_safety_outlined, Icons.help_outline]) {
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
      for (final shown in ['Weekly groceries', 'National Emergency Services', 'Opens as a calculator']) {
        expect(seen.any((s) => s.contains(shown)), isTrue, reason: shown);
      }
    });
  }

  testWidgets('real and second-PIN views have the same chrome, with no banner', (tester) async {
    await tester.pumpWidget(_vault(FakeEvidenceRepository([_item('e1', 'Threat message')]), decoy: false));
    await tester.pumpAndSettle();
    final real = _chrome(tester);

    await tester.pumpWidget(_vault(FakeEvidenceRepository([_item('n1', 'Groceries', decoy: true)]), decoy: true));
    await tester.pumpAndSettle();
    expect(_chrome(tester), real);
    expect(find.textContaining('innocent'), findsNothing);
  });

  testWidgets('evidence is deleted only after confirming', (tester) async {
    final repo = FakeEvidenceRepository([_item('e1', 'Threat message'), _item('e2', 'Fake profile')]);
    await tester.pumpWidget(_vault(repo, decoy: false));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Delete').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repo.deleted, isEmpty);

    await tester.tap(find.byTooltip('Delete').first);
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Delete')));
    await tester.pumpAndSettle();
    expect(repo.deleted, ['e1']);
    expect(find.text('Threat message'), findsNothing);
    expect(find.text('Fake profile'), findsOneWidget);
  });
}
