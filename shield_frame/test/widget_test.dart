import 'package:flutter_test/flutter_test.dart';
import 'package:shield_frame/main.dart';

void main() {
  testWidgets('Protiti LockScreen renders forensic lock interface', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ShieldFrameApp());
    await tester.pumpAndSettle();

    // Verify Title and Vault Authentication header
    expect(find.text('Protiti (প্রতীতি)'), findsOneWidget);
    expect(find.text('Forensic Vault Authentication'), findsOneWidget);

    // Verify Keypad digits are present
    expect(find.text('1'), findsOneWidget);
    expect(find.text('9'), findsOneWidget);

    // Verify keypad and stealth lock interface
    expect(find.byType(ShieldFrameApp), findsOneWidget);
  });
}
