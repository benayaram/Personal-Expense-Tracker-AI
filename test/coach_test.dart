import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moneywise/coach.dart';
import 'package:moneywise/domain.dart';

void main() {
  test('coaching egress excludes merchants and source IDs', () async {
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
      expect(request.url.toString(), 'https://coach.example/v1/coach');
      expect(request.headers['Authorization'], 'Bearer server-access-only');
      expect(request.body, isNot(contains('Private Merchant')));
      expect(request.body, isNot(contains('private-notification-id')));
      expect(request.body, isNot(contains('private-entry-id')));
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['summary']['categorySpendingPaise']['Dining'], 125005);
      return http.Response('{"answer":"Review dining spending."}', 200);
    });
    expect(
      await requestCoaching(
        url: 'https://coach.example',
        token: 'server-access-only',
        ledger: ledger,
        question: 'How can I save?',
        client: client,
      ),
      'Review dining spending.',
    );
    client.close();
  });
  test(
    'provider failure is surfaced without leaking response content',
    () async {
      final client = MockClient(
        (_) async => http.Response('private-provider-error', 503),
      );
      await expectLater(
        requestCoaching(
          url: 'https://coach.example',
          token: 'test',
          ledger: Ledger(),
          question: 'Help',
          client: client,
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.toString(),
            'message',
            isNot(contains('private-provider-error')),
          ),
        ),
      );
      client.close();
    },
  );
  test('HTTP coaching destinations are rejected before sending data', () async {
    final client = MockClient((_) async {
      fail('No request may be sent over HTTP');
    });
    await expectLater(
      requestCoaching(
        url: 'http://coach.example',
        token: 'test',
        ledger: Ledger(),
        question: 'Help',
        client: client,
      ),
      throwsFormatException,
    );
    client.close();
  });
}
