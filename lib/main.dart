import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'coach.dart';
import 'domain.dart';
import 'store.dart';

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
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff087f5b)),
      scaffoldBackgroundColor: const Color(0xfff6f8f6),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        margin: EdgeInsets.only(bottom: 12),
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
  List<Map<String, dynamic>> captures = [];
  bool notificationAccess = false, coachBusy = false;
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
    question.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refreshCapture();
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

  Future<void> refreshCapture() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final pending = await store.pending();
      final enabled =
          await AppStore.native.invokeMethod<bool>('enabled') ?? false;
      if (mounted) {
        setState(() {
          captures = pending;
          notificationAccess = enabled;
        });
      }
    } catch (_) {
      message(
        'Notification capture could not be loaded. Manual entry is available.',
      );
    }
  }

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
          title: Text(
            ['Moneywise', 'Activity', 'Your plan', 'Money coach'][tab],
          ),
          actions: [
            IconButton(
              tooltip: 'Capture inbox',
              icon: Badge(
                isLabelVisible: captures.isNotEmpty,
                label: Text('${captures.length}'),
                child: const Icon(Icons.notifications_outlined),
              ),
              onPressed: captureInbox,
            ),
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
        floatingActionButton: tab < 2
            ? FloatingActionButton.extended(
                onPressed: store.busy ? null : () => editEntry(),
                icon: const Icon(Icons.add),
                label: const Text('Add entry'),
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
              label: 'Activity',
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
  Widget dashboard() => ListView(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
    children: [
      Card(
        color: Theme.of(context).colorScheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Safe to spend · estimate'),
              const SizedBox(height: 8),
              Text(
                money(ledger.safeToSpend),
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Tracked balance minus reserved bills and planned savings. Add an opening balance and keep entries current.',
              ),
              TextButton(
                onPressed: reserveDialog,
                child: const Text('Adjust your plan'),
              ),
            ],
          ),
        ),
      ),
      panel('This month', [
        amountRow('Income', ledger.total(EntryKind.income, DateTime.now())),
        amountRow('Expenses', ledger.total(EntryKind.expense, DateTime.now())),
        amountRow('Tracked balance · all time', ledger.balance),
      ]),
      panel('Spending by category', spendingChart(DateTime.now())),
      if (captures.isNotEmpty)
        panel('Ready to review', [
          Text(
            '${captures.length} notification candidates. Nothing is added without your confirmation.',
          ),
          TextButton(
            onPressed: captureInbox,
            child: const Text('Review captures'),
          ),
        ]),
      panel(
        'Recent activity',
        ledger.entries.isEmpty
            ? [
                empty(
                  'Start with your opening balance or your first transaction.',
                ),
              ]
            : ((ledger.entries.toList()
                    ..sort((a, b) => b.date.compareTo(a.date)))
                  .take(4)
                  .map(entryTile)
                  .toList()),
      ),
    ],
  );
  List<Widget> spendingChart(DateTime month) {
    final items = ledger.spending(month).entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = items.fold(0, (int s, e) => s + e.value);
    if (total == 0) {
      return [empty('Your spending chart appears after your first expense.')];
    }
    return [
      Semantics(
        label: 'Category spending chart. Total ${money(total)}',
        child: SizedBox(
          height: 140,
          width: double.infinity,
          child: CustomPaint(
            painter: SpendingPainter(items.map((e) => e.value).toList()),
          ),
        ),
      ),
      const SizedBox(height: 12),
      ...items.asMap().entries.map(
        (e) => Row(
          children: [
            Container(
              width: 10,
              height: 10,
              color: chartColors[e.key % chartColors.length],
            ),
            const SizedBox(width: 8),
            Expanded(child: amountRow(e.value.key, e.value.value)),
          ],
        ),
      ),
    ];
  }

  Widget entryTile(MoneyEntry e) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: CircleAvatar(
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
              (filter == null || filter == e.kind) &&
              '${e.merchant} ${e.category}'.toLowerCase().contains(
                search.toLowerCase(),
              ),
        )
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
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
                child: Text(
                  '${selectedMonth.year} / ${selectedMonth.month.toString().padLeft(2, '0')}',
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
        TextField(
          decoration: const InputDecoration(
            labelText: 'Search entries',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (v) => setState(() => search = v),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
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
        const SizedBox(height: 12),
        Card(
          child: ExpansionTile(
            title: const Text('Monthly report'),
            children: [
              panel('Spending overview', [
                amountRow(
                  'Income',
                  ledger.total(EntryKind.income, selectedMonth),
                ),
                amountRow(
                  'Previous month expenses',
                  ledger.total(
                    EntryKind.expense,
                    DateTime(selectedMonth.year, selectedMonth.month - 1),
                  ),
                ),
                amountRow(
                  'Expenses',
                  ledger.total(EntryKind.expense, selectedMonth),
                ),
                ...spendingChart(selectedMonth),
              ]),
            ],
          ),
        ),
        if (entries.isEmpty)
          empty('No matching entries in this month.')
        else
          ...entries.map(entryTile),
      ],
    );
  }

  Widget plan() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
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
      panel('Savings goals', [
        const Text(
          'Progress is recorded manually. Goal balances are informational and do not change your tracked balance.',
        ),
        if (ledger.goals.isEmpty)
          empty('Start with an emergency fund or a future purchase.'),
        ...ledger.goals.asMap().entries.map(
          (e) => ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(e.value.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(
                  value: (e.value.saved / e.value.target).clamp(0.0, 1.0),
                ),
                Text(
                  '${money(e.value.saved)} of ${money(e.value.target)} · due ${dateLabel(e.value.deadline)}',
                ),
                Text(
                  '${money(e.value.monthlyRequired(DateTime.now()))}/month needed',
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Edit goal',
                  onPressed: () => goalDialog(index: e.key),
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'Delete goal',
                  onPressed: () async {
                    if (await confirm(
                      'Delete goal?',
                      'Transactions will stay unchanged.',
                    )) {
                      await perform(
                        () => store.change((l) => l.goals.removeAt(e.key)),
                      );
                    }
                  },
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
        ),
        TextButton.icon(
          onPressed: goalDialog,
          icon: const Icon(Icons.add),
          label: const Text('Create goal'),
        ),
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
          FilledButton.icon(
            onPressed: coachBusy ? null : askCoach,
            icon: const Icon(Icons.auto_awesome),
            label: Text(coachBusy ? 'Thinking…' : 'Share summary and ask'),
          ),
          if (coachBusy) const LinearProgressIndicator(),
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

  Future<void> coachSettings() async {
    final apiKeyController = TextEditingController();
    final model = TextEditingController(text: store.geminiModel);
    final form = GlobalKey<FormState>();
    var saving = false;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: const Text('Connect Gemini'),
          content: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Use your own Gemini API key for this personal app. It is encrypted on this phone and excluded from backups. Requests go directly to Google when you ask for advice. API usage may have quotas or charges.',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: apiKeyController,
                    obscureText: true,
                    enableSuggestions: false,
                    autocorrect: false,
                    maxLength: 512,
                    decoration: InputDecoration(
                      labelText: store.geminiKey.isEmpty
                          ? 'Gemini API key'
                          : 'New key (blank keeps current)',
                    ),
                    validator: (v) =>
                        store.geminiKey.isEmpty && (v?.trim().isEmpty ?? true)
                        ? 'Enter your API key.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: model,
                    maxLength: 100,
                    decoration: const InputDecoration(
                      labelText: 'Gemini model',
                    ),
                    validator: (v) =>
                        RegExp(
                          r'^gemini-[A-Za-z0-9._-]+$',
                        ).hasMatch(v?.trim() ?? '')
                        ? null
                        : 'Enter a Gemini model name.',
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Use a model available to your Google project. Notification capture and local insights do not depend on Gemini.',
                  ),
                ],
              ),
            ),
          ),
          actions: [
            if (store.geminiKey.isNotEmpty)
              TextButton(
                onPressed: saving
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
                          if (ctx.mounted) Navigator.pop(ctx);
                        } catch (_) {
                          if (ctx.mounted) update(() => saving = false);
                          message('Could not remove the key. Please retry.');
                        }
                      },
                child: const Text('Remove key'),
              ),
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!form.currentState!.validate()) return;
                      update(() => saving = true);
                      try {
                        await store.configureCoach(
                          model.text.trim(),
                          apiKeyController.text.trim().isEmpty
                              ? store.geminiKey
                              : apiKeyController.text.trim(),
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (_) {
                        if (ctx.mounted) update(() => saving = false);
                        message(
                          'Could not save the Gemini settings. Please retry.',
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

  Future<void> captureInbox() async {
    await refreshCapture();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(ctx).height * .8,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Capture inbox',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              const Text(
                'Optional Android notification access can expose notifications from other apps. Moneywise only processes supported bank/payment alerts on-device. Candidates need review; cash and missing alerts need manual entry.',
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await permissionDialog();
                },
                child: Text(
                  notificationAccess
                      ? 'Manage notification access'
                      : 'Enable notification capture',
                ),
              ),
              if (captures.isEmpty)
                empty(
                  'No pending captures. New supported alerts appear here after permission is enabled.',
                ),
              ...captures.map(
                (c) => Card(
                  child: ListTile(
                    title: Text(
                      '${c['merchant']} · ${money((c['paise'] as num).toInt())}',
                    ),
                    subtitle: Text(
                      '${c['kind']} · ${dateLabel(DateTime.fromMillisecondsSinceEpoch((c['timestamp'] as num).toInt()))}\nReview for duplicate payment alerts.',
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      editEntry(capture: c);
                    },
                    trailing: IconButton(
                      tooltip: 'Dismiss capture',
                      icon: const Icon(Icons.close),
                      onPressed: () async {
                        await perform(
                          () => store.acknowledge(c['id'] as String),
                        );
                        await refreshCapture();
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> permissionDialog() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      message('Notification capture is available on Android only.');
      return;
    }
    if (!await confirm(
      'Allow notification capture?',
      'Android grants notification access broadly. Moneywise filters supported bank and payment apps, stores only parsed transaction candidates in encrypted local storage, and never sends notification text to AI. You can revoke access in Android settings at any time.',
    )) {
      return;
    }
    await perform(() => AppStore.native.invokeMethod<void>('settings'));
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
              title: const Text('Notification access'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(ctx);
                permissionDialog();
              },
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
              title: Text('Moneywise 1.0.0'),
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
const chartColors = [
  Color(0xff087f5b),
  Color(0xff6c5ce7),
  Color(0xffe17055),
  Color(0xff0984e3),
  Color(0xffb58b00),
  Color(0xff636e72),
];

class SpendingPainter extends CustomPainter {
  final List<int> values;
  SpendingPainter(this.values);
  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold(0, (int a, b) => a + b);
    if (total == 0) return;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: math.min(size.width, size.height) / 2 - 12,
    );
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] / total * math.pi * 2;
      canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..color = chartColors[i % chartColors.length]
          ..style = PaintingStyle.stroke
          ..strokeWidth = 20,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(SpendingPainter oldDelegate) =>
      !listEquals(values, oldDelegate.values);
}
