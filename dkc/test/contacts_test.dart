import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protiti/domain/models/contact.dart';
import 'package:protiti/domain/use_cases/trigger_panic.dart';
import 'package:protiti/ui/core/widgets/explain_permission.dart';
import 'package:protiti/ui/features/settings/contacts_screen.dart';

import 'helpers/app_harness.dart';
import 'helpers/fakes.dart';

void main() {
  test('Bangladeshi mobile numbers are validated and normalised', () {
    for (final ok in ['01712345678', '+8801712345678', '8801712345678', '017-1234 5678', '০১৭১২৩৪৫৬৭৮']) {
      expect(TrustedContact.normalizePhone(ok), '+8801712345678', reason: ok);
    }
    for (final bad in ['', '999', '01212345678', '0171234567', '017123456789', '+447700900123', 'abc']) {
      expect(TrustedContact.normalizePhone(bad), isNull, reason: bad);
    }
  });

  testWidgets('add, edit and delete a contact, then send a test SMS', (tester) async {
    final repo = FakeContactRepository();
    final sms = FakeSms();
    await tester.pumpWidget(harness(ContactsScreen(repository: repo, sendSms: sms.call)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add contact'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Ayesha');
    await tester.enterText(find.widgetWithText(TextField, 'Mobile number'), '12345');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Bangladeshi mobile number'), findsOneWidget);
    expect(repo.contacts, isEmpty);

    await tester.enterText(find.widgetWithText(TextField, 'Mobile number'), '01712345678');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(repo.contacts.single.phone, '+8801712345678');
    expect(find.text('+8801712345678'), findsOneWidget);

    await tester.tap(find.text('Ayesha'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Ayesha Apa');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(repo.contacts.single.name, 'Ayesha Apa');

    await tester.tap(find.byTooltip('Send test SMS'));
    await tester.pumpAndSettle();
    expect(sms.sent.single.$1, ['+8801712345678']);
    expect(sms.sent.single.$2, ContactsScreen.testMessage);
    expect(find.text('Test text sent to Ayesha Apa.'), findsOneWidget);

    sms.answer = SmsStatus.failed;
    await tester.tap(find.byTooltip('Send test SMS'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Not sent'), findsOneWidget);

    await tester.tap(find.byTooltip('Remove'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Remove')));
    await tester.pumpAndSettle();
    expect(repo.contacts, isEmpty);
  });

  testWidgets('the OS permission prompt only follows the explanation and Continue', (tester) async {
    var asked = 0;
    late BuildContext ctx;
    await tester.pumpWidget(harness(Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    })));
    Future<bool> ask() async {
      asked++;
      return true;
    }

    var result = explainThenRequest(ctx, title: 'Why', body: 'Because', request: ask);
    await tester.pumpAndSettle();
    expect(find.text('Because'), findsOneWidget);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(await result, isFalse);
    expect(asked, 0);

    result = explainThenRequest(ctx, title: 'Why', body: 'Because', request: ask);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(await result, isTrue);
    expect(asked, 1);
  });
}
