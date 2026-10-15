import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:protiti/domain/models/evidence.dart';
import 'package:protiti/ui/features/complaint/complaint_wizard_screen.dart';
import 'package:protiti/ui/features/vault/vault_provider.dart';

import 'helpers/app_harness.dart';
import 'helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final storage = FakeSecureStorage();
  setUp(
    () => storage
      ..store.clear()
      ..install(),
  );
  tearDown(storage.uninstall);

  testWidgets('she chooses which evidence goes into the PDF', (tester) async {
    final repo = FakeEvidenceRepository([
      Evidence(
        id: 'a',
        type: 'screenshot',
        description: 'Threat message',
        createdAt: DateTime(2026, 10, 1),
      ),
      Evidence(
        id: 'b',
        type: 'audio',
        description: 'Voice note',
        createdAt: DateTime(2026, 10, 2),
      ),
    ]);
    await tester.binding.setSurfaceSize(const Size(420, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      harness(
        Scaffold(
          body: ChangeNotifierProvider(
            create: (_) => VaultProvider(repo, isDecoy: false),
            child: const ComplaintWizardScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue').first);
    await tester.pumpAndSettle();

    expect(find.textContaining('2 of 2 items'), findsOneWidget);
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Voice note'));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 of 2 items'), findsOneWidget);
    expect(
      tester
          .widget<CheckboxListTile>(
            find.widgetWithText(CheckboxListTile, 'Voice note'),
          )
          .value,
      isFalse,
    );
    expect(
      tester
          .widget<CheckboxListTile>(
            find.widgetWithText(CheckboxListTile, 'Threat message'),
          )
          .value,
      isTrue,
    );
  });

  for (final decoy in [false, true]) {
    testWidgets(
      'every field takes a Bangla keyboard and learns nothing (decoy: $decoy)',
      (tester) async {
        await tester.pumpWidget(
          harness(
            Scaffold(
              body: ChangeNotifierProvider(
                create: (_) =>
                    VaultProvider(FakeEvidenceRepository(), isDecoy: decoy),
                child: ComplaintWizardScreen(isDecoy: decoy),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final fields = tester.widgetList<TextField>(find.byType(TextField));
        expect(fields, isNotEmpty);
        for (final f in fields) {
          expect(f.keyboardType, isNot(TextInputType.visiblePassword));
          expect(
            (
              f.enableSuggestions,
              f.autocorrect,
              f.enableIMEPersonalizedLearning,
            ),
            (false, false, false),
          );
        }
      },
    );
  }
}
