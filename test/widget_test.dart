import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneywise/main.dart';
import 'package:moneywise/domain.dart';
import 'package:moneywise/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          AppStore.native,
          (call) async => call.method == 'pending'
              ? '[]'
              : call.method == 'enabled'
              ? false
              : null,
        );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async => null,
        );
  });
  testWidgets('add transaction, persist, and reopen editing', (tester) async {
    final store = AppStore()..loaded = true;
    await tester.pumpWidget(MoneywiseApp(store: store));
    expect(find.text('Safe to spend · estimate'), findsOneWidget);
    await tester.tap(find.text('Add entry'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Amount (INR)'),
      '250.50',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Merchant / description'),
      'Zomato',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(store.ledger.entries.single.paise, 25050);
    expect(store.ledger.entries.single.category, 'Dining');
    expect(store.ledger.balance, -25050);
    await tester.tap(find.text('Activity').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Zomato'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Zomato'), findsOneWidget);
    await tester.tap(find.text('Zomato'));
    await tester.pumpAndSettle();
    expect(find.text('Edit entry'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });
  testWidgets('invalid amount is blocked without saving', (tester) async {
    final store = AppStore()..loaded = true;
    await tester.pumpWidget(MoneywiseApp(store: store));
    await tester.tap(find.text('Add entry'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(
      find.text('Enter a positive amount with up to 2 decimals.'),
      findsOneWidget,
    );
    expect(store.ledger.entries, isEmpty);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });
  testWidgets('storage failure shows retry instead of an empty ledger', (
    tester,
  ) async {
    final store = AppStore()..failure = 'Cannot open saved records';
    await tester.pumpWidget(MoneywiseApp(store: store));
    expect(find.text('Cannot open saved records'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Add entry'), findsNothing);
  });
  testWidgets('small phone and large text support the main tabs', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final store = AppStore()..loaded = true;
    store.ledger.add(
      MoneyEntry(
        id: 'income',
        merchant: 'Salary',
        category: 'Salary',
        paise: 6000000,
        date: DateTime.now(),
        kind: EntryKind.income,
      ),
    );
    store.ledger.add(
      MoneyEntry(
        id: 'expense',
        merchant: 'Groceries',
        category: 'Groceries',
        paise: 3250000,
        date: DateTime.now(),
        kind: EntryKind.expense,
      ),
    );
    store.ledger.budgets['Groceries'] = 3000000;
    store.ledger.goals.add(
      Goal(
        'Emergency fund',
        12000000,
        4500000,
        DateTime.now().add(const Duration(days: 365)),
      ),
    );
    await tester.pumpWidget(MoneywiseApp(store: store));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    for (final label in ['Activity', 'Plan', 'Coach', 'Home']) {
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: label);
    }
  });
  testWidgets('Gemini key can be configured and removed inside the app', (
    tester,
  ) async {
    final store = AppStore()..loaded = true;
    await tester.pumpWidget(MoneywiseApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Settings and privacy'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gemini API settings'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Gemini API key'),
      'unit-test-not-a-real-key',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(store.geminiKey, 'unit-test-not-a-real-key');
    expect(store.ledger.encode(), isNot(contains('unit-test-not-a-real-key')));
    await tester.tap(find.byTooltip('Settings and privacy'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gemini API settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove key'));
    await tester.pumpAndSettle();
    expect(store.geminiKey, isEmpty);
  });
}
