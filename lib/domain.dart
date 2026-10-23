import 'dart:convert';

enum EntryKind { expense, income, transfer }

class MoneyEntry {
  final String id, merchant, category;
  final int paise;
  final DateTime date;
  final EntryKind kind;
  final String? sourceId;
  const MoneyEntry({
    required this.id,
    required this.merchant,
    required this.category,
    required this.paise,
    required this.date,
    required this.kind,
    this.sourceId,
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'merchant': merchant,
    'category': category,
    'paise': paise,
    'date': date.toIso8601String(),
    'kind': kind.name,
    'sourceId': sourceId,
  };
  factory MoneyEntry.fromJson(Map<String, dynamic> j) => MoneyEntry(
    id: j['id'] as String,
    merchant: j['merchant'] as String,
    category: j['category'] as String,
    paise: j['paise'] as int,
    date: DateTime.parse(j['date'] as String),
    kind: EntryKind.values.byName(j['kind'] as String),
    sourceId: j['sourceId'] as String?,
  );
}

int? parseMoney(String input) {
  final s = input.trim();
  if (!RegExp(r'^\d{1,9}(\.\d{1,2})?$').hasMatch(s)) return null;
  final parts = s.split('.');
  final amount =
      int.parse(parts[0]) * 100 +
      (parts.length == 2 ? int.parse(parts[1].padRight(2, '0')) : 0);
  return amount > 0 ? amount : null;
}

String money(int paise) {
  final value = paise.abs();
  return '${paise < 0 ? '−' : ''}₹${value ~/ 100}.${(value % 100).toString().padLeft(2, '0')}';
}

String suggestCategory(String merchant) {
  final s = merchant.toLowerCase();
  if (RegExp('swiggy|zomato|restaurant|cafe').hasMatch(s)) return 'Dining';
  if (RegExp('uber|ola|metro|petrol').hasMatch(s)) return 'Travel';
  if (RegExp('grocery|blinkit|supermarket').hasMatch(s)) return 'Groceries';
  if (RegExp('electric|airtel|jio|rent').hasMatch(s)) return 'Bills';
  return 'Other';
}

class Goal {
  final String name;
  final int target, saved;
  final DateTime deadline;
  const Goal(this.name, this.target, this.saved, this.deadline);
  int monthlyRequired(DateTime now) {
    final months = (deadline.year - now.year) * 12 + deadline.month - now.month;
    final remaining = target - saved;
    return remaining <= 0 ? 0 : (remaining / (months > 0 ? months : 1)).ceil();
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'target': target,
    'saved': saved,
    'deadline': deadline.toIso8601String(),
  };
  factory Goal.fromJson(Map<String, dynamic> j) => Goal(
    j['name'] as String,
    j['target'] as int,
    j['saved'] as int,
    DateTime.parse(j['deadline'] as String),
  );
}

class RecurringBill {
  final String id, name;
  final int paise, day;
  const RecurringBill(this.id, this.name, this.paise, this.day);
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'paise': paise,
    'day': day,
  };
  factory RecurringBill.fromJson(Map<String, dynamic> j) => RecurringBill(
    j['id'] as String,
    j['name'] as String,
    j['paise'] as int,
    j['day'] as int,
  );
  DateTime nextDue(DateTime now) {
    var due = DateTime(
      now.year,
      now.month,
      day > DateTime(now.year, now.month + 1, 0).day
          ? DateTime(now.year, now.month + 1, 0).day
          : day,
    );
    if (due.isBefore(DateTime(now.year, now.month, now.day))) {
      final last = DateTime(now.year, now.month + 2, 0).day;
      due = DateTime(now.year, now.month + 1, day > last ? last : day);
    }
    return due;
  }
}

class Ledger {
  final List<MoneyEntry> entries;
  final List<String> categories;
  final Map<String, int> budgets;
  final List<Goal> goals;
  final List<RecurringBill> bills;
  int reservedBills, plannedSavings, openingBalance;
  Ledger({
    List<MoneyEntry>? entries,
    List<String>? categories,
    Map<String, int>? budgets,
    List<Goal>? goals,
    List<RecurringBill>? bills,
    this.openingBalance = 0,
    this.reservedBills = 0,
    this.plannedSavings = 0,
  }) : entries = entries ?? [],
       categories =
           categories ??
           [
             'Groceries',
             'Dining',
             'Travel',
             'Shopping',
             'Bills',
             'Health',
             'Salary',
             'Other',
           ],
       budgets = budgets ?? {},
       goals = goals ?? [],
       bills = bills ?? [];
  List<MoneyEntry> month(DateTime now) =>
      entries
          .where((e) => e.date.year == now.year && e.date.month == now.month)
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
  int total(EntryKind kind, DateTime now) => month(
    now,
  ).where((e) => e.kind == kind).fold(0, (sum, e) => sum + e.paise);
  int get balance => entries.fold(
    openingBalance,
    (sum, e) =>
        sum +
        switch (e.kind) {
          EntryKind.income => e.paise,
          EntryKind.expense => -e.paise,
          EntryKind.transfer => 0,
        },
  );
  int get safeToSpend => balance - reservedBills - plannedSavings;
  Map<String, int> spending(DateTime now) {
    final result = <String, int>{};
    for (final e in month(now).where((e) => e.kind == EntryKind.expense)) {
      result.update(e.category, (v) => v + e.paise, ifAbsent: () => e.paise);
    }
    return result;
  }

  bool add(MoneyEntry e) {
    if (e.paise <= 0 ||
        entries.any(
          (v) =>
              v.id == e.id || (e.sourceId != null && e.sourceId == v.sourceId),
        )) {
      return false;
    }
    entries.add(e);
    return true;
  }

  List<String> insights(DateTime now) {
    final result = <String>[];
    for (final item in spending(now).entries) {
      final budget = budgets[item.key];
      if (budget != null && item.value > budget) {
        result.add(
          '${item.key} is ${money(item.value - budget)} over budget. Review recent purchases and set a realistic limit.',
        );
      }
    }
    if (safeToSpend < 0) {
      result.add(
        'Your tracked balance does not cover planned bills and savings. Review commitments before new spending.',
      );
    }
    if (entries.isEmpty) {
      result.add(
        'Set your opening balance under Plan, then record income and expenses to build a useful plan.',
      );
    }
    if (goals.isEmpty) {
      result.add(
        'Create an emergency fund goal based on your essential monthly expenses.',
      );
    }
    if (result.isEmpty) {
      result.add(
        'You are within your recorded budgets. Review upcoming bills before moving money to savings.',
      );
    }
    return result;
  }

  String encode() => jsonEncode({
    'version': 1,
    'entries': entries.map((e) => e.toJson()).toList(),
    'bills': bills.map((b) => b.toJson()).toList(),
    'categories': categories,
    'budgets': budgets,
    'goals': goals.map((g) => g.toJson()).toList(),
    'openingBalance': openingBalance,
    'reservedBills': reservedBills,
    'plannedSavings': plannedSavings,
  });
  factory Ledger.decode(String s) {
    final j = jsonDecode(s) as Map<String, dynamic>;
    if (j['version'] != 1) {
      throw const FormatException('Unsupported data version');
    }
    return Ledger(
      entries: (j['entries'] as List)
          .map((e) => MoneyEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      categories: List<String>.from(j['categories']),
      budgets: Map<String, int>.from(j['budgets']),
      bills: ((j['bills'] as List?) ?? [])
          .map((b) => RecurringBill.fromJson(Map<String, dynamic>.from(b)))
          .toList(),
      goals: (j['goals'] as List)
          .map((g) => Goal.fromJson(Map<String, dynamic>.from(g)))
          .toList(),
      openingBalance: (j['openingBalance'] as int?) ?? 0,
      reservedBills: j['reservedBills'] as int,
      plannedSavings: j['plannedSavings'] as int,
    );
  }
}

int? debtMonths(int principalPaise, int paymentPaise, double annualRate) {
  if (principalPaise <= 0 ||
      paymentPaise <= 0 ||
      !annualRate.isFinite ||
      annualRate < 0 ||
      annualRate > 100) {
    return null;
  }
  final rate = annualRate / 1200;
  if (paymentPaise <= principalPaise * rate) return null;
  double remaining = principalPaise.toDouble();
  for (var month = 1; month <= 1200; month++) {
    remaining = remaining * (1 + rate) - paymentPaise;
    if (remaining <= 0.0001) return month;
  }
  return null;
}

void validateLedger(Ledger l) {
  if (l.categories.isEmpty ||
      l.categories.length > 500 ||
      l.categories.toSet().length != l.categories.length ||
      l.categories.any((c) => c.trim().isEmpty || c.length > 60) ||
      l.openingBalance < 0 ||
      l.openingBalance > 99999999999 ||
      l.reservedBills < 0 ||
      l.plannedSavings < 0 ||
      l.reservedBills > 99999999999 ||
      l.plannedSavings > 99999999999 ||
      l.entries.length > 100000 ||
      l.goals.length > 500 ||
      l.entries.map((e) => e.id).toSet().length != l.entries.length ||
      l.entries
              .where((e) => e.sourceId != null)
              .map((e) => e.sourceId)
              .toSet()
              .length !=
          l.entries.where((e) => e.sourceId != null).length) {
    throw const FormatException('Invalid ledger');
  }
  for (final e in l.entries) {
    if (e.id.isEmpty ||
        e.id.length > 128 ||
        (e.sourceId != null && e.sourceId!.length > 128) ||
        e.merchant.trim().isEmpty ||
        e.merchant.length > 80 ||
        !l.categories.contains(e.category) ||
        e.paise <= 0 ||
        e.paise > 99999999999 ||
        e.date.year < 2000 ||
        e.date.isAfter(DateTime.now().add(const Duration(days: 1)))) {
      throw const FormatException('Invalid transaction');
    }
  }
  for (final g in l.goals) {
    if (g.name.trim().isEmpty ||
        g.name.length > 60 ||
        g.target <= 0 ||
        g.saved < 0 ||
        g.target > 99999999999 ||
        g.saved > 99999999999 ||
        g.deadline.year < 2000 ||
        g.deadline.year > 2200) {
      throw const FormatException('Invalid savings goal');
    }
  }
  if (l.bills.length > 500 ||
      l.bills.map((b) => b.id).toSet().length != l.bills.length ||
      l.bills.any(
        (b) =>
            b.id.isEmpty ||
            b.name.trim().isEmpty ||
            b.name.length > 60 ||
            b.paise <= 0 ||
            b.paise > 99999999999 ||
            b.day < 1 ||
            b.day > 31,
      )) {
    throw const FormatException('Invalid recurring bills');
  }
  if (l.budgets.entries.any(
    (e) =>
        !l.categories.contains(e.key) || e.value <= 0 || e.value > 99999999999,
  )) {
    throw const FormatException('Invalid budgets');
  }
  if (l.encode().length > 10000000) {
    throw const FormatException(
      'Local ledger capacity reached (10 MB). Keep a backup and archive older records before adding more.',
    );
  }
}
