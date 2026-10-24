import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'coach.dart';
import 'domain.dart';
import 'store.dart';
import 'presentation.dart';
import 'voice.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MoneywiseApp(store: AppStore()..load()));
}

class MoneywiseApp extends StatelessWidget {
  final AppStore store;
  const MoneywiseApp({super.key, required this.store});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Moneywise',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff9562f5)),
      scaffoldBackgroundColor: const Color(0xfff9f8fc),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        margin: EdgeInsets.only(bottom: 16),
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(24)),
          side: BorderSide(color: Color(0xffefedf4)),
        ),
      ),
    ),
    home: HomeShell(store: store),
  );
}

class HomeShell extends StatefulWidget {
  final AppStore store;
  const HomeShell({super.key, required this.store});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int tab = 0;
  String search = '';
  EntryKind? filter;
  DateTime selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  bool coachBusy = false, listening = false;
  EntryKind reportKind = EntryKind.expense;
  String? coachAnswer;
  int coachEpoch = 0;
  final question = TextEditingController();
  AppStore get store => widget.store;
  Ledger get ledger => store.ledger;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    refreshCapture();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    Voice.cancel().catchError((_) {});
    Voice.stop().catchError((_) {});
    question.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refreshCapture();
    if (state == AppLifecycleState.paused) {
      Voice.cancel().catchError((_) {});
      Voice.stop().catchError((_) {});
    }
  }

  void message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> perform(Future<void> Function() work) async {
    try {
      await work();
    } catch (e) {
      message(
        e is FormatException
            ? e.message.toString()
            : 'Unable to complete this action. Your saved data has been preserved.',
      );
    }
  }

  Future<void> refreshCapture() async {}
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      if (!store.loaded) {
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: store.failure == null
                  ? const CircularProgressIndicator()
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(store.failure!),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: store.load,
                          child: const Text('Retry'),
                        ),
                        TextButton(
                          onPressed: restoreBackup,
                          child: const Text('Restore backup'),
                        ),
                        TextButton(
                          onPressed: () async {
                            if (await confirm(
                              'Reset local data?',
                              'This permanently deletes local records and settings. Exported backups are not affected.',
                            )) {
                              await perform(store.erase);
                            }
                          },
                          child: const Text('Reset local data'),
                        ),
                      ],
                    ),
            ),
          ),
        );
      }
      return Scaffold(
        appBar: AppBar(
          title: Text(['Moneywise', 'Report', 'My Plan', 'AI Coach'][tab]),
          actions: [
            IconButton(
              tooltip: 'Settings and privacy',
              onPressed: settings,
              icon: const Icon(Icons.settings_outlined),
            ),
          ],
        ),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                children: [
                  if (store.busy) const LinearProgressIndicator(),
                  Expanded(child: [dashboard, activity, plan, coach][tab]()),
                ],
              ),
            ),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        floatingActionButton: tab < 3
            ? FloatingActionButton(
                tooltip: tab == 2 ? 'Create goal' : 'Add entry',
                backgroundColor: violet,
                foregroundColor: Colors.white,
                shape: const CircleBorder(),
                onPressed: store.busy
                    ? null
                    : () => tab == 2 ? goalDialog() : editEntry(),
                child: const Icon(Icons.add),
              )
            : null,
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (v) => setState(() => tab = v),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              label: 'Report',
            ),
            NavigationDestination(
              icon: Icon(Icons.savings_outlined),
              label: 'Plan',
            ),
            NavigationDestination(
              icon: Icon(Icons.auto_awesome_outlined),
              label: 'Coach',
            ),
          ],
        ),
      );
    },
  );
  Widget panel(String title, List<Widget> children) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    ),
  );
  Widget amountRow(String label, int value, {Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(
          money(value),
          style: TextStyle(fontWeight: FontWeight.w600, color: color),
        ),
      ],
    ),
  );
  Widget empty(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Text(text),
  );
  Future<void> chooseMonth() async {
    final chosen = await showDatePicker(
      context: context,
      helpText: 'Choose report month',
      initialDate: selectedMonth,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (chosen != null) {
      setState(() => selectedMonth = DateTime(chosen.year, chosen.month));
    }
  }

  Widget dashboard() => ListView(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
    children: [
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xffa978ff), Color(0xff8553dc), Color(0xffbb9bf6)],
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.person_outline, color: Colors.white),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: chooseMonth,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            monthLabel(selectedMonth),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        const Icon(
                          Icons.expand_more,
                          color: Colors.white,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Spending alerts',
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    builder: (ctx) => SafeArea(
                      child: ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.all(24),
                        children: [
                          const Text(
                            'Current month spending alerts',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          ...ledger
                              .insights(DateTime.now())
                              .map(
                                (s) => ListTile(
                                  leading: const Icon(
                                    Icons.notifications_outlined,
                                    color: violet,
                                  ),
                                  title: Text(s),
                                ),
                              ),
                        ],
                      ),
                    ),
                  ),
                  icon: const Icon(
                    Icons.notifications_none,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 25),
            const Text(
              'Current balance',
              style: TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 8),
            FittedBox(
              child: Text(
                money(ledger.balance),
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .18),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Safe to spend · estimate  ${money(ledger.safeToSpend)}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 22),
      Row(
        children: [
          const Expanded(
            child: Text(
              'Your Money',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
          ),
          TextButton.icon(
            onPressed: () => setState(() => tab = 1),
            icon: const Icon(Icons.chevron_right),
            iconAlignment: IconAlignment.end,
            label: const Text('Details'),
          ),
        ],
      ),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SummaryTile(
              label: 'Income',
              amount: ledger.total(EntryKind.income, selectedMonth),
              icon: Icons.savings_outlined,
              color: const Color(0xff25a7eb),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SummaryTile(
              label: 'Expenses',
              amount: ledger.total(EntryKind.expense, selectedMonth),
              icon: Icons.account_balance_wallet_outlined,
              color: const Color(0xffff6e55),
            ),
          ),
        ],
      ),
      const SizedBox(height: 18),
      Material(
        color: ink,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => setState(() => tab = 3),
          child: const Padding(
            padding: EdgeInsets.all(17),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, color: Color(0xffc4a6ff)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your financial insights',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(Icons.arrow_forward, color: Colors.white, size: 18),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 22),
      Row(
        children: [
          const Expanded(
            child: Text(
              'Transactions',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
          ),
          TextButton(
            onPressed: () => setState(() => tab = 1),
            child: const Text('View all'),
          ),
        ],
      ),
      Text(
        monthLabel(selectedMonth),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 12),
      if (ledger.month(selectedMonth).isEmpty)
        panel('Start your money story', [
          const Text(
            'Set an opening balance under Plan, then add income or an expense. Categories are suggested automatically and can be edited.',
          ),
        ])
      else
        ...ledger
            .month(selectedMonth)
            .take(5)
            .map(
              (e) => Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 5,
                  ),
                  child: entryTile(e),
                ),
              ),
            ),
    ],
  );
  List<Widget> spendingChart(
    DateTime month, {
    EntryKind kind = EntryKind.expense,
  }) {
    final values = <String, int>{};
    for (final e in ledger.month(month).where((e) => e.kind == kind)) {
      values.update(e.category, (v) => v + e.paise, ifAbsent: () => e.paise);
    }
    final items = values.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final ordered = Map<String, int>.fromEntries(items);
    final total = values.values.fold(0, (int s, v) => s + v);
    final previous = <String, int>{};
    for (final e
        in ledger
            .month(DateTime(month.year, month.month - 1))
            .where((e) => e.kind == kind)) {
      previous.update(e.category, (v) => v + e.paise, ifAbsent: () => e.paise);
    }
    return [
      MoneyRing(
        values: ordered,
        label: kind == EntryKind.expense ? 'Total expenses' : 'Total income',
      ),
      if (total == 0) empty('No ${kind.name} records for this month.'),
      ...items.asMap().entries.map((item) {
        final e = item.value;
        final color = palette[item.key % palette.length];
        final old = previous[e.key] ?? 0;
        return Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xffeeeaf2)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: color.withValues(alpha: .1),
                    child: Icon(categoryIcon(e.key), color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.key,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          '${(e.value / total * 100).toStringAsFixed(1)}% of total',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          money(e.value),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        if (old > 0)
                          Text(
                            '${e.value >= old ? '+' : ''}${((e.value - old) / old * 100).toStringAsFixed(0)}% vs prior month',
                            style: TextStyle(
                              fontSize: 11,
                              color: e.value > old
                                  ? Colors.deepOrange
                                  : Colors.teal,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              LinearProgressIndicator(
                value: e.value / total,
                minHeight: 6,
                borderRadius: BorderRadius.circular(8),
                color: color,
                backgroundColor: color.withValues(alpha: .08),
              ),
            ],
          ),
        );
      }),
    ];
  }

  Widget entryTile(MoneyEntry e) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: CircleAvatar(
      backgroundColor: violet.withValues(alpha: .09),
      child: Icon(switch (e.kind) {
        EntryKind.income => Icons.south_west,
        EntryKind.expense => Icons.north_east,
        EntryKind.transfer => Icons.swap_horiz,
      }),
    ),
    title: Text(e.merchant),
    subtitle: Text(
      '${e.category} · ${dateLabel(e.date)}${e.kind == EntryKind.transfer ? ' · Excluded from totals' : ''}',
    ),
    trailing: Text(
      '${e.kind == EntryKind.expense
          ? '−'
          : e.kind == EntryKind.income
          ? '+'
          : ''}${money(e.paise)}',
    ),
    onTap: () => editEntry(existing: e),
  );
  Widget activity() {
    final entries = ledger
        .month(selectedMonth)
        .where(
          (e) =>
              (filter == null || e.kind == filter) &&
              '${e.merchant} ${e.category}'.toLowerCase().contains(
                search.toLowerCase(),
              ),
        )
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Previous month',
              onPressed: () => setState(
                () => selectedMonth = DateTime(
                  selectedMonth.year,
                  selectedMonth.month - 1,
                ),
              ),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Center(
                child: TextButton(
                  onPressed: chooseMonth,
                  child: Text(monthLabel(selectedMonth)),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Next month',
              onPressed: () => setState(
                () => selectedMonth = DateTime(
                  selectedMonth.year,
                  selectedMonth.month + 1,
                ),
              ),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        SegmentedButton<EntryKind>(
          segments: const [
            ButtonSegment(value: EntryKind.expense, label: Text('Expenses')),
            ButtonSegment(value: EntryKind.income, label: Text('Income')),
          ],
          selected: {reportKind},
          onSelectionChanged: (v) => setState(() => reportKind = v.first),
        ),
        const SizedBox(height: 20),
        panel(
          reportKind == EntryKind.expense ? 'Expenses report' : 'Income report',
          spendingChart(selectedMonth, kind: reportKind),
        ),
        panel('Income vs expenses', [
          amountRow('Income', ledger.total(EntryKind.income, selectedMonth)),
          amountRow('Expenses', ledger.total(EntryKind.expense, selectedMonth)),
          amountRow(
            'Net income',
            ledger.total(EntryKind.income, selectedMonth) -
                ledger.total(EntryKind.expense, selectedMonth),
          ),
          const Text(
            'Recorded transactions only. Current and prior months may contain incomplete data.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ]),
        const Text(
          'All transactions',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        TextField(
          decoration: const InputDecoration(
            labelText: 'Search entries',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (v) => setState(() => search = v),
        ),
        Wrap(
          spacing: 6,
          children: [
            ChoiceChip(
              label: const Text('All'),
              selected: filter == null,
              onSelected: (_) => setState(() => filter = null),
            ),
            ...EntryKind.values.map(
              (k) => ChoiceChip(
                label: Text(k.name),
                selected: filter == k,
                onSelected: (_) => setState(() => filter = k),
              ),
            ),
          ],
        ),
        if (entries.isEmpty)
          empty('No matching entries in this month.')
        else
          ...entries.map(
            (e) => Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: entryTile(e),
              ),
            ),
          ),
      ],
    );
  }

  Widget plan() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      panel('Savings goals', [
        const Text(
          'Goal progress is tracked separately from your spendable funds.',
        ),
        if (ledger.goals.isEmpty)
          empty('Start with an emergency fund or a future purchase.'),
        ...ledger.goals.asMap().entries.map((e) {
          final goal = e.value;
          final ratio = (goal.saved / goal.target).clamp(0.0, 1.0);
          final remaining = (goal.target - goal.saved).clamp(0, goal.target);
          final color = palette[e.key % palette.length];
          return Container(
            margin: const EdgeInsets.only(top: 16, bottom: 8),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xffeeeaf2)),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: color.withValues(alpha: .1),
                            child: Icon(categoryIcon(goal.name), color: color),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              goal.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 17,
                              ),
                            ),
                          ),
                          PopupMenuButton<String>(
                            tooltip: 'Goal actions',
                            onSelected: (v) async {
                              if (v == 'edit') {
                                await goalDialog(index: e.key);
                              } else if (await confirm(
                                'Delete goal?',
                                'Transactions will stay unchanged.',
                              )) {
                                await perform(
                                  () => store.change(
                                    (l) => l.goals.removeAt(e.key),
                                  ),
                                );
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'edit',
                                child: Text('Edit goal'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete goal'),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      Text(
                        money(goal.saved),
                        style: const TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'of ${money(goal.target)} · ${(ratio * 100).round()}% saved',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 18),
                      LinearProgressIndicator(
                        value: ratio,
                        minHeight: 9,
                        borderRadius: BorderRadius.circular(12),
                        color: color,
                        backgroundColor: color.withValues(alpha: .09),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          Text(
                            'Due ${dateLabel(goal.deadline)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          Text(
                            '${money(remaining)} left',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .09),
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(24),
                    ),
                  ),
                  child: Text(
                    remaining == 0
                        ? 'Goal reached — keep building good habits.'
                        : '${money(goal.monthlyRequired(DateTime.now()))}/month needed to reach your target.',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
        TextButton.icon(
          onPressed: goalDialog,
          icon: const Icon(Icons.add),
          label: const Text('Create goal'),
        ),
      ]),
      panel('Category budgets', [
        if (ledger.budgets.isEmpty)
          empty('Set a monthly limit for a category.'),
        ...ledger.budgets.entries.map((e) {
          final spent = ledger.spending(DateTime.now())[e.key] ?? 0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                amountRow(e.key, e.value),
                LinearProgressIndicator(
                  value: (spent / e.value).clamp(0.0, 1.0),
                  color: spent > e.value ? Colors.red : null,
                ),
                Text(
                  '${money(spent)} spent · ${money((e.value - spent).abs())} ${spent > e.value ? 'over' : 'left'}',
                ),
                TextButton(
                  onPressed: () => budgetDialog(category: e.key),
                  child: const Text('Edit budget'),
                ),
              ],
            ),
          );
        }),
        TextButton.icon(
          onPressed: budgetDialog,
          icon: const Icon(Icons.add),
          label: const Text('Add budget'),
        ),
      ]),
      panel('Opening balance', [
        amountRow('Before your first recorded entry', ledger.openingBalance),
        const Text(
          'Money you already had before tracking began. This changes the tracked balance without counting as income.',
        ),
        TextButton(
          onPressed: () async {
            final values = await amountDialog(
              'Opening balance',
              ['Starting balance'],
              [ledger.openingBalance],
              allowZero: true,
            );
            if (values != null) {
              await perform(
                () => store.change((l) => l.openingBalance = values[0]),
              );
            }
          },
          child: const Text('Set opening balance'),
        ),
      ]),
      panel('Monthly commitments', [
        amountRow('Reserved for upcoming bills', ledger.reservedBills),
        amountRow('Planned savings', ledger.plannedSavings),
        const Text(
          'These reserves reduce safe-to-spend. They do not move money or record expenses.',
        ),
        TextButton(onPressed: reserveDialog, child: const Text('Set amounts')),
      ]),
      panel('What if?', [
        const Text(
          'Explore how a monthly saving amount builds up. Assumes no interest, fees, withdrawals, or changes to income.',
        ),
        TextButton(
          onPressed: whatIfDialog,
          child: const Text('Try a savings scenario'),
        ),
      ]),
      panel('Bills and subscriptions', [
        const Text(
          'Monthly reminders appear here when you open the app. These do not automatically create expenses or send background alerts. Reserve bills above and record payments separately.',
        ),
        if (ledger.bills.isEmpty)
          empty('Add rent, loan payments or subscriptions.'),
        ...ledger.bills.map(
          (b) => ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(b.name),
            subtitle: Text(
              '${money(b.paise)} · next due ${dateLabel(b.nextDue(DateTime.now()))}',
            ),
            trailing: IconButton(
              tooltip: 'Delete bill',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                if (await confirm(
                  'Delete recurring bill?',
                  'Recorded transactions will be kept.',
                )) {
                  await perform(
                    () => store.change(
                      (l) => l.bills.removeWhere((v) => v.id == b.id),
                    ),
                  );
                }
              },
            ),
          ),
        ),
        TextButton(
          onPressed: billDialog,
          child: const Text('Add recurring bill'),
        ),
      ]),
      panel('Forecast', [
        const Text(
          'Scenario based on this month’s recorded income and expenses. Repeats those amounts each month; actual income and spending can differ.',
        ),
        ...List.generate(
          3,
          (i) => amountRow(
            'In ${i + 1} month${i == 0 ? '' : 's'} · estimate',
            ledger.balance +
                (i + 1) *
                    (ledger.total(EntryKind.income, DateTime.now()) -
                        ledger.total(EntryKind.expense, DateTime.now())),
          ),
        ),
      ]),
      panel('Debt planner', [
        const Text(
          'Compare a fixed monthly repayment against your outstanding balance and interest rate.',
        ),
        TextButton(
          onPressed: debtDialog,
          child: const Text('Estimate debt payoff'),
        ),
      ]),
    ],
  );
  Widget coach() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      panel('Your weekly check-in', [
        Wrap(
          spacing: 8,
          children: [
            TextButton.icon(
              onPressed: () =>
                  readAnswer(ledger.insights(DateTime.now()).join(' ')),
              icon: const Icon(Icons.volume_up_outlined),
              label: const Text('Listen to insights'),
            ),
            TextButton.icon(
              onPressed: () => perform(Voice.stop),
              icon: const Icon(Icons.stop),
              label: const Text('Stop audio'),
            ),
          ],
        ),
        const Text('Local insights · calculated on your device'),
        const SizedBox(height: 12),
        ...ledger
            .insights(DateTime.now())
            .map(
              (s) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.lightbulb_outline),
                title: Text(s),
              ),
            ),
      ]),
      panel('Ask your AI coach', [
        const Text(
          'Optional cloud AI. With your consent, category totals, budgets, goal names and your question are sent directly to Google Gemini. No separate server is needed. Merchant names and notification text stay on your device.',
        ),
        const SizedBox(height: 12),
        if (store.geminiKey.isEmpty) ...[
          const Text(
            'Cloud coaching is not connected. Local insights above work without an API key.',
          ),
          TextButton(
            onPressed: coachSettings,
            child: const Text('Connect Gemini'),
          ),
        ] else ...[
          TextField(
            controller: question,
            maxLength: 500,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'How can I save more this month?',
            ),
          ),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: coachBusy
                    ? null
                    : (listening ? cancelVoice : listenQuestion),
                icon: Icon(
                  listening ? Icons.stop_circle_outlined : Icons.mic_none,
                ),
                label: Text(listening ? 'Stop listening' : 'Voice question'),
              ),
              if (listening)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Listening…'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: coachBusy ? null : askCoach,
            icon: const Icon(Icons.auto_awesome),
            label: Text(coachBusy ? 'Thinking…' : 'Share summary and ask'),
          ),
          if (coachBusy) const LinearProgressIndicator(),
          if (coachAnswer != null)
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: () => readAnswer(coachAnswer!),
                  icon: const Icon(Icons.volume_up_outlined),
                  label: const Text('Read answer aloud'),
                ),
              ],
            ),
          if (coachAnswer != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: SelectableText(coachAnswer!),
            ),
        ],
        const SizedBox(height: 12),
        const Text(
          'Suggestions are estimates from incomplete records. Review them before making financial decisions. No money is moved automatically.',
        ),
      ]),
    ],
  );
  Future<bool> confirm(String title, String body) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      ) ??
      false;
  Future<void> editEntry({
    MoneyEntry? existing,
    Map<String, dynamic>? capture,
  }) async {
    final merchant = TextEditingController(
      text: existing?.merchant ?? capture?['merchant'] as String? ?? '',
    );
    final amount = TextEditingController(
      text: existing != null
          ? (existing.paise / 100).toStringAsFixed(2)
          : capture?['paise'] != null
          ? ((capture!['paise'] as num) / 100).toStringAsFixed(2)
          : '',
    );
    var kind =
        existing?.kind ??
        (capture?['kind'] == 'income' ? EntryKind.income : EntryKind.expense);
    var category = existing?.category ?? suggestCategory(merchant.text);
    var date =
        existing?.date ??
        (capture?['timestamp'] != null
            ? DateTime.fromMillisecondsSinceEpoch(
                (capture!['timestamp'] as num).toInt(),
              )
            : DateTime.now());
    if (!ledger.categories.contains(category)) {
      category = ledger.categories.first;
    }
    final form = GlobalKey<FormState>();
    var submitting = false;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: Text(existing == null ? 'Add entry' : 'Edit entry'),
          content: SizedBox(
            width: 440,
            child: Form(
              key: form,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<EntryKind>(
                      initialValue: kind,
                      decoration: const InputDecoration(labelText: 'Type'),
                      items: EntryKind.values
                          .map(
                            (k) =>
                                DropdownMenuItem(value: k, child: Text(k.name)),
                          )
                          .toList(),
                      onChanged: submitting
                          ? null
                          : (v) => update(() => kind = v!),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: amount,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Amount (INR)',
                      ),
                      validator: (v) => parseMoney(v ?? '') == null
                          ? 'Enter a positive amount with up to 2 decimals.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: merchant,
                      maxLength: 80,
                      decoration: const InputDecoration(
                        labelText: 'Merchant / description',
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Enter a description.'
                          : null,
                      onChanged: (v) {
                        if (existing == null) {
                          update(() => category = suggestCategory(v));
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: ValueKey(category),
                      initialValue: category,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: ledger.categories
                          .map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                          )
                          .toList(),
                      onChanged: (v) => update(() => category = v!),
                    ),
                    TextButton(
                      onPressed: submitting
                          ? null
                          : () async {
                              final name = await textInput(
                                'New category',
                                'Category name',
                              );
                              if (name != null &&
                                  name.trim().isNotEmpty &&
                                  !ledger.categories.contains(name.trim())) {
                                await perform(
                                  () => store.change(
                                    (l) => l.categories.add(name.trim()),
                                  ),
                                );
                                if (ctx.mounted &&
                                    ledger.categories.contains(name.trim())) {
                                  update(() => category = name.trim());
                                }
                              }
                            },
                      child: const Text('Create category'),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(dateLabel(date)),
                      trailing: const Icon(Icons.calendar_today_outlined),
                      onTap: () async {
                        final chosen = await showDatePicker(
                          context: ctx,
                          initialDate: date,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                        );
                        if (chosen != null) update(() => date = chosen);
                      },
                    ),
                    if (capture != null)
                      const Text(
                        'Confirm the amount, direction and category. A bank and payment app may report the same transaction.',
                      ),
                    if (kind == EntryKind.transfer)
                      const Text(
                        'Transfers between your own accounts are excluded from income and expenses.',
                      ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            if (existing != null)
              TextButton(
                onPressed: submitting
                    ? null
                    : () async {
                        if (!await confirm(
                          'Delete entry?',
                          'This cannot be undone.',
                        )) {
                          return;
                        }
                        update(() => submitting = true);
                        try {
                          await store.change(
                            (l) => l.entries.removeWhere(
                              (e) => e.id == existing.id,
                            ),
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                        } catch (_) {
                          update(() => submitting = false);
                          message('Delete failed. Please retry.');
                        }
                      },
                child: const Text('Delete'),
              ),
            TextButton(
              onPressed: submitting ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: submitting
                  ? null
                  : () async {
                      if (!form.currentState!.validate()) return;
                      update(() => submitting = true);
                      final candidate = MoneyEntry(
                        id: existing?.id ?? newId(),
                        merchant: merchant.text.trim(),
                        category: category,
                        paise: parseMoney(amount.text)!,
                        date: date,
                        kind: kind,
                        sourceId:
                            existing?.sourceId ?? capture?['id'] as String?,
                      );
                      try {
                        await store.change((l) {
                          if (existing != null) {
                            l.entries.removeWhere((e) => e.id == existing.id);
                          }
                          if (!l.add(candidate)) {
                            throw StateError('Already imported');
                          }
                        });
                        if (capture != null) {
                          await store.acknowledge(capture['id'] as String);
                          await refreshCapture();
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (_) {
                        if (ctx.mounted) update(() => submitting = false);
                        message(
                          'Could not save, or this notification was already imported. Review Activity before retrying.',
                        );
                      }
                    },
              child: Text(submitting ? 'Saving…' : 'Save'),
            ),
          ],
        ),
      ),
    );
    // Controllers are released after the dialog exit animation has finished.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    merchant.dispose();
    amount.dispose();
  }

  Future<String?> textInput(
    String title,
    String label, {
    String initial = '',
  }) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLength: 60,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Done'),
          ),
        ],
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    controller.dispose();
    return result;
  }

  Future<void> reserveDialog() async {
    final values = await amountDialog(
      'Monthly commitments',
      ['Upcoming bills', 'Planned savings'],
      [ledger.reservedBills, ledger.plannedSavings],
      allowZero: true,
    );
    if (values != null) {
      await perform(
        () => store.change((l) {
          l.reservedBills = values[0];
          l.plannedSavings = values[1];
        }),
      );
    }
  }

  Future<List<int>?> amountDialog(
    String title,
    List<String> labels,
    List<int> initial, {
    bool allowZero = false,
  }) async {
    final controls = initial
        .map((v) => TextEditingController(text: (v / 100).toStringAsFixed(2)))
        .toList();
    final form = GlobalKey<FormState>();
    final result = await showDialog<List<int>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                labels.length,
                (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextFormField(
                    controller: controls[i],
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: '${labels[i]} (INR)',
                    ),
                    validator: (v) =>
                        (allowZero &&
                                RegExp(
                                  r'^0(\.0{1,2})?$',
                                ).hasMatch(v?.trim() ?? '')) ||
                            parseMoney(v ?? '') != null
                        ? null
                        : 'Enter a valid ${allowZero ? 'nonnegative' : 'positive'} amount.',
                  ),
                ),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(
                  ctx,
                  controls.map((c) => parseMoney(c.text) ?? 0).toList(),
                );
              }
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    for (final c in controls) {
      c.dispose();
    }
    return result;
  }

  Future<void> budgetDialog({String? category}) async {
    final selected =
        category ??
        await showDialog<String>(
          context: context,
          builder: (ctx) => SimpleDialog(
            title: const Text('Choose category'),
            children: ledger.categories
                .map(
                  (c) => SimpleDialogOption(
                    onPressed: () => Navigator.pop(ctx, c),
                    child: Text(c),
                  ),
                )
                .toList(),
          ),
        );
    if (selected == null || !mounted) return;
    final values = await amountDialog(
      'Budget for $selected',
      ['Monthly limit (0 removes)'],
      [ledger.budgets[selected] ?? 0],
      allowZero: true,
    );
    if (values != null) {
      await perform(
        () => store.change((l) {
          if (values[0] == 0) {
            l.budgets.remove(selected);
          } else {
            l.budgets[selected] = values[0];
          }
        }),
      );
    }
  }

  Future<void> goalDialog({int? index}) async {
    final old = index == null ? null : ledger.goals[index];
    final name = await textInput(
      'Savings goal',
      'Goal name',
      initial: old?.name ?? 'Emergency fund',
    );
    if (name == null || name.trim().isEmpty || !mounted) return;
    final values = await amountDialog(
      'Target and saved so far',
      ['Target', 'Already saved'],
      [old?.target ?? 0, old?.saved ?? 0],
      allowZero: true,
    );
    if (values == null || !mounted) return;
    if (values[0] <= 0) {
      message('The target must be positive.');
      return;
    }
    final now = DateTime.now();
    final deadline = await showDatePicker(
      context: context,
      initialDate: old != null && old.deadline.isAfter(now)
          ? old.deadline
          : DateTime(now.year + 1, now.month, now.day),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 50),
    );
    if (deadline == null) return;
    await perform(
      () => store.change((l) {
        final goal = Goal(name.trim(), values[0], values[1], deadline);
        if (index == null) {
          l.goals.add(goal);
        } else {
          l.goals[index] = goal;
        }
      }),
    );
  }

  Future<void> billDialog() async {
    final name = await textInput('Recurring bill', 'Bill or subscription name');
    if (name == null || name.trim().isEmpty || !mounted) return;
    final amount = await amountDialog('Monthly bill', ['Amount'], [0]);
    if (amount == null || !mounted) return;
    final dayText = await textInput(
      'Monthly due date',
      'Day of month (1–31)',
      initial: '1',
    );
    final day = int.tryParse(dayText ?? '');
    if (day == null || day < 1 || day > 31) {
      if (dayText != null) message('Enter a day from 1 to 31.');
      return;
    }
    await perform(
      () => store.change(
        (l) => l.bills.add(RecurringBill(newId(), name.trim(), amount[0], day)),
      ),
    );
  }

  Future<void> whatIfDialog() async {
    final v = await amountDialog(
      'Savings scenario',
      ['Monthly contribution'],
      [200000],
    );
    if (v == null || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Your savings scenario'),
        content: Text(
          '${money(v[0])} each month becomes ${money(v[0] * 12)} in 12 months and ${money(v[0] * 36)} in 3 years.\n\nNo investment returns are assumed. This does not change your savings plan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> debtDialog() async {
    final values = await amountDialog(
      'Debt estimate',
      ['Outstanding debt', 'Monthly payment'],
      [0, 0],
    );
    if (values == null || !mounted) return;
    final rate = await textInput(
      'Annual interest rate',
      'APR percent, e.g. 12',
      initial: '12',
    );
    if (rate == null || !mounted) return;
    final apr = double.tryParse(rate);
    if (apr == null || !apr.isFinite || apr < 0 || apr > 100) {
      message('Enter an annual rate from 0 to 100.');
      return;
    }
    final result = debtMonths(values[0], values[1], apr);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Estimated debt payoff'),
        content: Text(
          result == null
              ? 'This payment does not cover the estimated interest or payoff exceeds 100 years. Increase the payment.'
              : 'Approximately $result months, assuming a fixed rate, monthly interest and no fees or new borrowing. Confirm actual terms with your lender.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> askCoach() async {
    if (question.text.trim().isEmpty) {
      message('Enter a question first.');
      return;
    }
    if (!await confirm(
      'Share your summary?',
      'Your question, goal names and category totals will be sent to Google Gemini directly. Avoid including account numbers or personal information.',
    )) {
      return;
    }
    setState(() => coachBusy = true);
    final epoch = coachEpoch;
    try {
      final answer = await requestCoaching(
        apiKey: store.geminiKey,
        model: store.geminiModel,
        ledger: ledger,
        question: question.text.trim(),
      );
      if (mounted && epoch == coachEpoch) setState(() => coachAnswer = answer);
    } on CoachException catch (e) {
      message(e.message);
    } catch (_) {
      message(
        'Could not reach Gemini. Your entries and local insights still work offline.',
      );
    } finally {
      if (mounted) setState(() => coachBusy = false);
    }
  }

  Future<void> listenQuestion() async {
    if (!await confirm(
      'Voice input',
      'Your device speech service will transcribe your question and may process audio online. Microphone access is requested only for this action. Review the text before sending anything to Gemini.',
    )) {
      return;
    }
    if (!mounted) return;
    setState(() => listening = true);
    try {
      final text = await Voice.listen();
      if (mounted && text.isNotEmpty) {
        question.text = text.length > 500 ? text.substring(0, 500) : text;
        if (text.length > 500) {
          message(
            'Voice text was limited to 500 characters. Please review it.',
          );
        }
      }
    } on PlatformException catch (e) {
      if (e.code != 'CANCELLED') {
        message(
          e.message ??
              'Voice input is unavailable. Type your question instead.',
        );
      }
    } catch (_) {
      message('Voice input is unavailable on this device. You can still type.');
    } finally {
      if (mounted) setState(() => listening = false);
    }
  }

  Future<void> cancelVoice() async {
    await perform(Voice.cancel);
    if (mounted) setState(() => listening = false);
  }

  Future<void> readAnswer(String text) async {
    try {
      await Voice.speak(text);
    } on PlatformException catch (e) {
      if (e.code != 'CANCELLED') {
        message(e.message ?? 'Speech output is unavailable.');
      }
    } catch (_) {
      message(
        'Speech output is unavailable on this device. The text is still available.',
      );
    }
  }

  Future<void> coachSettings() async {
    final apiKeyController = TextEditingController(text: store.geminiKey);
    final model = TextEditingController(text: store.geminiModel);
    final form = GlobalKey<FormState>();
    var saving = false, visible = false, loading = false, custom = false;
    String? loadError;
    var models = <String>{
      store.geminiModel,
      'gemini-2.5-flash',
      'gemini-2.5-flash-lite',
      'gemini-2.5-pro',
    }.toList();
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: const Text('Gemini settings'),
          content: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your key stays encrypted on this phone and is excluded from financial backups. Gemini usage may have quotas or charges.',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: apiKeyController,
                    obscureText: !visible,
                    enableSuggestions: false,
                    autocorrect: false,
                    maxLength: 512,
                    decoration: InputDecoration(
                      labelText: 'Gemini API key',
                      suffixIcon: IconButton(
                        tooltip: visible ? 'Hide API key' : 'Show API key',
                        onPressed: () => update(() => visible = !visible),
                        icon: Icon(
                          visible
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                    validator: (v) => (v?.trim().isEmpty ?? true)
                        ? 'Enter your API key.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey(
                      '${models.join(',')}|${custom ? 'custom' : model.text}',
                    ),
                    initialValue: custom ? 'custom' : model.text,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Select Gemini model',
                    ),
                    items: [
                      ...models.map(
                        (m) => DropdownMenuItem(
                          value: m,
                          child: Text(m, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                      const DropdownMenuItem(
                        value: 'custom',
                        child: Text('Custom model…'),
                      ),
                    ],
                    onChanged: (v) => update(() {
                      custom = v == 'custom';
                      if (!custom) model.text = v!;
                    }),
                  ),
                  if (custom)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: TextFormField(
                        controller: model,
                        maxLength: 100,
                        decoration: const InputDecoration(
                          labelText: 'Custom Gemini model',
                        ),
                        validator: (v) =>
                            RegExp(
                              r'^gemini-[A-Za-z0-9._-]+$',
                            ).hasMatch(v?.trim() ?? '')
                            ? null
                            : 'Enter a Gemini model name.',
                      ),
                    ),
                  TextButton.icon(
                    onPressed: loading || saving
                        ? null
                        : () async {
                            update(() {
                              loading = true;
                              loadError = null;
                            });
                            try {
                              final available = await listGeminiModels(
                                apiKeyController.text.trim(),
                              );
                              if (ctx.mounted) {
                                update(() {
                                  models = <String>{
                                    model.text,
                                    ...available,
                                  }.toList();
                                });
                              }
                            } catch (_) {
                              if (ctx.mounted) {
                                update(
                                  () => loadError =
                                      'Could not load models. Check the key, internet and API access. You can still select or enter a model.',
                                );
                              }
                            } finally {
                              if (ctx.mounted) update(() => loading = false);
                            }
                          },
                    icon: const Icon(Icons.refresh),
                    label: Text(
                      loading ? 'Loading models…' : 'Load models from Google',
                    ),
                  ),
                  if (loadError != null)
                    Text(
                      loadError!,
                      style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                    ),
                  const Text(
                    'Preset names are suggestions, not proof of availability. Load the models supported by your key or enter a custom model.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            if (store.geminiKey.isNotEmpty)
              TextButton(
                onPressed: saving || loading
                    ? null
                    : () async {
                        update(() => saving = true);
                        try {
                          await store.configureCoach(store.geminiModel, '');
                          if (mounted) {
                            setState(() {
                              coachEpoch++;
                              coachAnswer = null;
                            });
                          }
                          await Voice.stop().catchError((_) {});
                          if (ctx.mounted) Navigator.pop(ctx);
                        } catch (_) {
                          if (ctx.mounted) update(() => saving = false);
                          message('Could not remove key. Please retry.');
                        }
                      },
                child: const Text('Remove key'),
              ),
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving || loading
                  ? null
                  : () async {
                      if (!form.currentState!.validate()) return;
                      update(() => saving = true);
                      try {
                        await store.configureCoach(
                          model.text.trim(),
                          apiKeyController.text.trim(),
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (_) {
                        if (ctx.mounted) update(() => saving = false);
                        message(
                          'Could not save Gemini settings. Please retry.',
                        );
                      }
                    },
              child: Text(saving ? 'Saving…' : 'Save'),
            ),
          ],
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    apiKeyController.dispose();
    model.dispose();
  }

  Future<void> settings() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Settings & privacy',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.lock_outline),
              title: Text('Your data stays local by default'),
              subtitle: Text(
                'Encrypted device storage. Android cloud backup is disabled. Keep your own backup; uninstalling or losing your phone can lose your records. No bank credentials or payment permissions are requested.',
              ),
            ),
            ListTile(
              title: const Text('Gemini API settings'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(ctx);
                coachSettings();
              },
            ),
            ListTile(
              title: const Text('Export backup to clipboard'),
              subtitle: const Text(
                'Contains private financial records as plaintext.',
              ),
              onTap: () async {
                if (await confirm(
                  'Copy financial backup?',
                  'The clipboard may be accessible to your keyboard or other apps. Store this backup securely and clear the clipboard after use.',
                )) {
                  await Clipboard.setData(ClipboardData(text: ledger.encode()));
                  message(
                    'Backup copied. Save it securely, then clear your clipboard.',
                  );
                }
              },
            ),
            ListTile(
              title: const Text('Restore backup'),
              subtitle: const Text(
                'Replaces all current financial records after confirmation.',
              ),
              onTap: () {
                Navigator.pop(ctx);
                restoreBackup();
              },
            ),
            ListTile(
              title: const Text('Delete all local data'),
              textColor: Theme.of(context).colorScheme.error,
              onTap: () async {
                if (await confirm(
                  'Permanently delete your data?',
                  'All entries, goals, budgets, captures and AI settings will be removed. Notification capture will be paused. External backups and AI provider records are not deleted.',
                )) {
                  await perform(store.erase);
                  await refreshCapture();
                  if (mounted) {
                    setState(() {
                      coachEpoch++;
                      coachAnswer = null;
                    });
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                }
              },
            ),
            const ListTile(
              title: Text('Moneywise 1.1.0'),
              subtitle: Text(
                'INR · Android · Private finance companion\nEstimates support planning; they do not guarantee savings.',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> restoreBackup() async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore backup'),
        content: TextField(
          controller: controller,
          maxLines: 8,
          decoration: const InputDecoration(
            labelText: 'Paste Moneywise JSON backup',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Check backup'),
          ),
        ],
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    controller.dispose();
    if (text == null) return;
    try {
      if (text.length > 10000000) {
        throw const FormatException('Backup too large');
      }
      final restored = Ledger.decode(text);
      validateLedger(restored);
      if (!mounted ||
          !await confirm(
            'Replace current records?',
            'Restore ${restored.entries.length} entries and ${restored.goals.length} goals? This replaces your current ledger.',
          )) {
        return;
      }
      await store.restore(restored);
      message('Backup restored.');
    } catch (_) {
      message(
        'Backup could not be restored. Current records have been preserved.',
      );
    }
  }
}

String dateLabel(DateTime d) => '${d.day}/${d.month}/${d.year}';
