import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moneywise/coach.dart';
import 'package:moneywise/domain.dart';

void main() {
  Future<String> ask(
    http.Client client, {
    String key = 'unit-test-not-a-real-key',
    String model = 'gemini-2.5-flash',
    Duration timeout = const Duration(seconds: 1),
  }) => requestCoaching(
    apiKey: key,
    model: model,
    ledger: Ledger(),
    question: 'How can I save?',
    client: client,
    timeout: timeout,
  );
  test('calls Google directly and excludes merchants and source IDs', () async {
    final ledger = Ledger();
    ledger.add(
      MoneyEntry(
        id: 'private-entry-id',
        merchant: 'Private Merchant',
        category: 'Dining',
        paise: 125005,
        date: DateTime.now(),
        kind: EntryKind.expense,
        sourceId: 'private-notification-id',
      ),
    );
    final client = MockClient((request) async {
      expect(request.url.host, 'generativelanguage.googleapis.com');
      expect(request.url.scheme, 'https');
      expect(request.url.query, isEmpty);
      expect(request.headers['x-goog-api-key'], 'unit-test-not-a-real-key');
      for (final value in [
        'Private Merchant',
        'private-notification-id',
        'private-entry-id',
      ]) {
        expect(request.body, isNot(contains(value)));
      }
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final summary = jsonDecode(body['contents'][0]['parts'][0]['text']);
      expect(summary['summary']['categorySpendingPaise']['Dining'], 125005);
      expect(
        body['systemInstruction']['parts'][0]['text'],
        contains('100 paise = INR 1'),
      );
      return http.Response(
        jsonEncode({
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': 'Review dining spending.'},
                ],
              },
            },
          ],
        }),
        200,
      );
    });
    expect(
      await requestCoaching(
        apiKey: 'unit-test-not-a-real-key',
        model: 'gemini-2.5-flash',
        ledger: ledger,
        question: 'How can I save?',
        client: client,
      ),
      'Review dining spending.',
    );
    client.close();
  });
  test('provider errors never disclose response content or API key', () async {
    final client = MockClient(
      (_) async => http.Response('private-provider-error', 403),
    );
    await expectLater(
      ask(client),
      throwsA(
        isA<CoachException>().having(
          (e) => e.message,
          'message',
          isNot(contains('private-provider-error')),
        ),
      ),
    );
    client.close();
  });
  test('usage limits keep a useful offline fallback message', () async {
    final client = MockClient((_) async => http.Response('', 429));
    await expectLater(
      ask(client),
      throwsA(
        isA<CoachException>().having(
          (e) => e.message,
          'message',
          contains('local insights still work'),
        ),
      ),
    );
    client.close();
  });
  test('empty or blocked model response fails clearly', () async {
    final client = MockClient(
      (_) async => http.Response('{"candidates":[]}', 200),
    );
    await expectLater(ask(client), throwsA(isA<CoachException>()));
    client.close();
  });
  test(
    'invalid model cannot redirect financial summaries to another host',
    () async {
      final client = MockClient((_) async {
        fail('No request may be made');
      });
      await expectLater(
        ask(client, model: 'https://other.example'),
        throwsA(isA<CoachException>()),
      );
      await expectLater(ask(client, key: ''), throwsA(isA<CoachException>()));
      client.close();
    },
  );
  test(
    'slow requests time out rather than blocking the app indefinitely',
    () async {
      final client = MockClient((_) => Completer<http.Response>().future);
      await expectLater(
        ask(client, timeout: const Duration(milliseconds: 10)),
        throwsA(isA<TimeoutException>()),
      );
      client.close();
    },
  );
}
