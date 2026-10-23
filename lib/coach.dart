import 'dart:convert';

import 'package:http/http.dart' as http;

import 'domain.dart';

Future<String> requestCoaching({
  required String url,
  required String token,
  required Ledger ledger,
  required String question,
  http.Client? client,
}) async {
  final uri = Uri.parse('$url/v1/coach');
  if (uri.scheme != 'https' || uri.host.isEmpty) {
    throw const FormatException('Configure an HTTPS coaching server first.');
  }
  final ownClient = client == null;
  final transport = client ?? http.Client();
  try {
    final now = DateTime.now();
    // Share category totals only, never notification text, merchants, or account identifiers.
    final response = await transport
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'question': question,
            'summary': {
              'currency': 'INR',
              'monthIncomePaise': ledger.total(EntryKind.income, now),
              'monthExpensesPaise': ledger.total(EntryKind.expense, now),
              'trackedBalancePaise': ledger.balance,
              'reservedBillsPaise': ledger.reservedBills,
              'plannedSavingsPaise': ledger.plannedSavings,
              'categorySpendingPaise': ledger.spending(now),
              'budgetsPaise': ledger.budgets,
              'goals': ledger.goals
                  .map(
                    (g) => {
                      'name': g.name,
                      'targetPaise': g.target,
                      'savedPaise': g.saved,
                      'monthlyRequiredPaise': g.monthlyRequired(now),
                    },
                  )
                  .toList(),
            },
          }),
        )
        .timeout(const Duration(seconds: 25));
    if (response.statusCode != 200) {
      throw StateError(
        'Coaching is unavailable (${response.statusCode}). Your local plan still works.',
      );
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final answer = data['answer'];
    if (answer is! String || answer.isEmpty) {
      throw const FormatException(
        'The coaching server returned an invalid answer.',
      );
    }
    return answer;
  } finally {
    if (ownClient) transport.close();
  }
}
