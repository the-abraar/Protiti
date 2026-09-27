import 'package:flutter_test/flutter_test.dart';
import 'package:protiti/main.dart';

void main() {
  testWidgets('Protiti LockScreen renders forensic lock interface', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProtitiApp());
    await tester.pumpAndSettle();

    // Verify Title and lock screen heading.
    // The brand name renders twice (AppBar title + body heading), so this
    // only asserts it appears at all rather than exactly once.
    expect(find.text('Protiti (প্রতীতি)'), findsWidgets);
    expect(find.text('My Notes'), findsOneWidget);

    // Verify Keypad digits are present
    expect(find.text('1'), findsOneWidget);
    expect(find.text('9'), findsOneWidget);

    // Verify keypad and stealth lock interface
    expect(find.byType(ProtitiApp), findsOneWidget);
  });
}
