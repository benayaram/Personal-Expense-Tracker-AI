import 'package:flutter_test/flutter_test.dart';
import 'package:moneywise/domain.dart';

void main() {
  final now = DateTime(2026, 10, 23);
  MoneyEntry entry(
    String id,
    EntryKind kind,
    int paise, {
    DateTime? date,
    String? source,
  }) => MoneyEntry(
    id: id,
    merchant: 'Cafe',
    category: 'Dining',
    paise: paise,
    date: date ?? now,
    kind: kind,
    sourceId: source,
  );
  test('parses exact paise and rejects malformed amounts', () {
    expect(money(-1), '−₹0.01');
    expect(money(9007199254740993), '₹90071992547409.93');
    expect(parseMoney('1250.05'), 125005);
    expect(parseMoney('0.01'), 1);
    for (final value in [
      '0',
      '-1',
      'NaN',
      '1.001',
      '1e3',
      '1,000',
      '1000000000',
      '',
    ]) {
      expect(parseMoney(value), isNull, reason: value);
    }
  });
  test('transfers excluded; month filter preserves all time balance', () {
    final l = Ledger(reservedBills: 750000, plannedSavings: 1000000);
    l.add(entry('1', EntryKind.income, 6000000));
    l.add(entry('2', EntryKind.expense, 3250000));
    l.add(entry('3', EntryKind.transfer, 500000));
    l.add(entry('4', EntryKind.expense, 10000, date: DateTime(2026, 9, 30)));
    expect(l.total(EntryKind.expense, now), 3250000);
    expect(l.balance, 2740000);
    expect(l.safeToSpend, 990000);
  });
  test('negative safe to spend remains visible', () {
    expect(Ledger(reservedBills: 10000).safeToSpend, -10000);
  });
  test('stable source IDs prevent retry imports', () {
    final l = Ledger();
    expect(
      l.add(entry('a', EntryKind.expense, 100, source: 'notification-1')),
      isTrue,
    );
    expect(
      l.add(entry('b', EntryKind.expense, 100, source: 'notification-1')),
      isFalse,
    );
    expect(l.add(entry('a', EntryKind.expense, 100)), isFalse);
    expect(l.entries.length, 1);
  });
  test('versioned backup round trips the complete ledger', () {
    final l = Ledger(
      budgets: {'Dining': 400000},
      reservedBills: 123,
      plannedSavings: 456,
      goals: [Goal('Emergency', 12000000, 4500000, DateTime(2027, 10))],
    );
    l.add(entry('a', EntryKind.expense, 1234));
    expect(Ledger.decode(l.encode()).encode(), l.encode());
    expect(() => Ledger.decode('{"version":99}'), throwsFormatException);
  });
  test('budget warnings use recorded overspending', () {
    final l = Ledger(budgets: {'Dining': 400000});
    l.add(entry('a', EntryKind.expense, 580000));
    expect(l.insights(now).first, contains('₹1800.00 over budget'));
  });
  test('goal contribution handles complete and overdue goals', () {
    expect(
      Goal('Future', 120000, 0, DateTime(2027, 10)).monthlyRequired(now),
      10000,
    );
    expect(Goal('Done', 100, 100, now).monthlyRequired(now), 0);
    expect(Goal('Past', 100, 0, DateTime(2020)).monthlyRequired(now), 100);
  });
  test('debt calculation handles zero interest and insufficient payments', () {
    expect(debtMonths(120000, 10000, 0), 12);
    expect(debtMonths(120000, 100, 12), isNull);
    expect(debtMonths(120000, 11000, 12), 12);
    expect(debtMonths(100, 10, double.nan), isNull);
  });
  test(
    'restores reject zero budgets, negative entries and repeated categories',
    () {
      expect(
        () => validateLedger(Ledger(budgets: {'Dining': 0})),
        throwsFormatException,
      );
      expect(
        () => validateLedger(
          Ledger(entries: [entry('x', EntryKind.expense, -100)]),
        ),
        throwsFormatException,
      );
      expect(
        () => validateLedger(Ledger(categories: ['Dining', 'Dining'])),
        throwsFormatException,
      );
    },
  );
  test('category suggestions support known merchants', () {
    expect(suggestCategory('Zomato'), 'Dining');
    expect(suggestCategory('Uber'), 'Travel');
    expect(suggestCategory('Local shop'), 'Other');
  });
  test('monthly bills clamp short months and roll forward after due date', () {
    final bill = RecurringBill('rent', 'Rent', 10000, 31);
    expect(bill.nextDue(DateTime(2026, 2, 1)), DateTime(2026, 2, 28));
    expect(bill.nextDue(DateTime(2026, 4, 30)), DateTime(2026, 4, 30));
    expect(
      const RecurringBill('b', 'Bill', 100, 10).nextDue(DateTime(2026, 12, 11)),
      DateTime(2027, 1, 10),
    );
  });
  test(
    'opening balance affects available funds but never inflates income reports',
    () {
      final ledger = Ledger(openingBalance: 100000);
      expect(ledger.balance, 100000);
      expect(ledger.total(EntryKind.income, now), 0);
      expect(Ledger.decode(ledger.encode()).openingBalance, 100000);
    },
  );
}
