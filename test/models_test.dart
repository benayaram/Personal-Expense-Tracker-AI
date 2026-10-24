import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moneywise/coach.dart';

void main() {
  test(
    'model discovery paginates and only offers supported Gemini generation models',
    () async {
      var calls = 0;
      final client = MockClient((r) async {
        calls++;
        expect(r.url.scheme, 'https');
        expect(r.url.host, 'generativelanguage.googleapis.com');
        expect(r.headers['x-goog-api-key'], 'test-key');
        expect(r.url.query, isNot(contains('test-key')));
        if (calls == 1) {
          return http.Response(
            jsonEncode({
              'models': [
                {
                  'name': 'models/gemini-2.5-flash',
                  'supportedGenerationMethods': ['generateContent'],
                },
                {
                  'name': 'models/embedding-only',
                  'supportedGenerationMethods': ['embedContent'],
                },
              ],
              'nextPageToken': 'next',
            }),
            200,
          );
        }
        expect(r.url.queryParameters['pageToken'], 'next');
        return http.Response(
          jsonEncode({
            'models': [
              {
                'name': 'models/gemini-2.5-pro',
                'supportedGenerationMethods': ['generateContent'],
              },
            ],
          }),
          200,
        );
      });
      expect(await listGeminiModels('test-key', client: client), [
        'gemini-2.5-flash',
        'gemini-2.5-pro',
      ]);
      expect(calls, 2);
      client.close();
    },
  );
  test(
    'model discovery rejects missing keys without sending a request',
    () async {
      final client = MockClient((_) async {
        fail('must not send');
      });
      await expectLater(
        listGeminiModels('', client: client),
        throwsA(isA<CoachException>()),
      );
      client.close();
    },
  );
  test('model discovery never exposes provider error contents', () async {
    final client = MockClient(
      (_) async => http.Response('private provider details', 403),
    );
    await expectLater(
      listGeminiModels('test', client: client),
      throwsA(
        isA<CoachException>().having(
          (e) => e.message,
          'message',
          isNot(contains('private provider details')),
        ),
      ),
    );
    client.close();
  });
}
