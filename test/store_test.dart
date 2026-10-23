import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneywise/domain.dart';
import 'package:moneywise/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final persisted = <String, String>{};
  var failWrites = false;
  setUp(() {
    persisted.clear();
    failWrites = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async {
            final args = Map<String, dynamic>.from(call.arguments as Map);
            switch (call.method) {
              case 'read':
                return persisted[args['key']];
              case 'write':
                if (failWrites) throw PlatformException(code: 'disk-full');
                persisted[args['key'] as String] = args['value'] as String;
                return null;
              case 'deleteAll':
                persisted.clear();
                return null;
              default:
                return null;
            }
          },
        );
  });
  test('committed entries survive a new store instance', () async {
    final a = AppStore();
    await a.load();
    await a.change(
      (l) => l.add(
        MoneyEntry(
          id: 'one',
          merchant: 'Income',
          category: 'Salary',
          paise: 500000,
          date: DateTime.now(),
          kind: EntryKind.income,
        ),
      ),
    );
    final b = AppStore();
    await b.load();
    expect(b.ledger.entries.single.paise, 500000);
    expect(b.ledger.balance, 500000);
  });
  test(
    'failed write preserves committed in-memory and persisted state',
    () async {
      final a = AppStore();
      await a.load();
      await a.change((l) => l.plannedSavings = 100);
      failWrites = true;
      await expectLater(
        a.change((l) => l.plannedSavings = 200),
        throwsA(isA<PlatformException>()),
      );
      expect(a.ledger.plannedSavings, 100);
      expect(a.busy, false);
      final b = AppStore();
      await b.load();
      expect(b.ledger.plannedSavings, 100);
    },
  );
  test('corrupt persisted data is never silently overwritten', () async {
    persisted['ledger.v1'] = '{bad-json';
    final a = AppStore();
    await a.load();
    expect(a.loaded, false);
    expect(a.failure, isNotNull);
    await expectLater(
      a.change((l) => l.plannedSavings = 100),
      throwsStateError,
    );
    expect(persisted['ledger.v1'], '{bad-json');
  });
  test('invalid modifications are rejected before persistence', () async {
    final a = AppStore();
    await a.load();
    await expectLater(
      a.change((l) => l.budgets['Dining'] = 0),
      throwsFormatException,
    );
    expect(a.ledger.budgets, isEmpty);
    expect(persisted['ledger.v1'], isNull);
  });
  test('validated backup can explicitly recover a corrupted store', () async {
    persisted['ledger.v1'] = '{bad-json';
    final a = AppStore();
    await a.load();
    expect(a.loaded, false);
    await a.restore(Ledger(plannedSavings: 10000));
    expect(a.loaded, true);
    expect(a.failure, isNull);
    final b = AppStore();
    await b.load();
    expect(b.ledger.plannedSavings, 10000);
  });
  test(
    'personal Gemini key survives restart but is excluded from ledger backup',
    () async {
      final a = AppStore();
      await a.load();
      await a.configureCoach('gemini-2.5-flash', 'unit-test-not-a-real-key');
      expect(a.ledger.encode(), isNot(contains('unit-test-not-a-real-key')));
      final b = AppStore();
      await b.load();
      expect(b.geminiKey, 'unit-test-not-a-real-key');
      expect(b.geminiModel, 'gemini-2.5-flash');
    },
  );
  test('removing Gemini key preserves financial data', () async {
    final a = AppStore();
    await a.load();
    await a.change((l) => l.openingBalance = 12345);
    await a.configureCoach('gemini-2.5-flash', 'unit-test-not-a-real-key');
    await a.configureCoach('gemini-2.5-flash', '');
    final b = AppStore();
    await b.load();
    expect(b.geminiKey, isEmpty);
    expect(b.ledger.balance, 12345);
  });
}
