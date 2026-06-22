import 'dart:convert';
import 'dart:io';

import 'package:crossword_api/crossword_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const request = CrosswordGenerationRequest(
    width: 9, height: 9, maxWordLen: 6,
  );

  test('posts to the generate endpoint and parses a success body', () async {
    final body =
        File('test/fixtures/generation_response_9x9.json').readAsStringSync();
    late http.Request captured;
    final client = MockClient((req) async {
      captured = req;
      return http.Response(body, 200,
          headers: {'content-type': 'application/json'});
    });

    final source = CrosswordGenerationRemoteDataSource(client: client);
    final res = await source.generate(request);

    expect(captured.method, 'POST');
    expect(captured.url.toString(),
        'https://api.ikors.se/crossword-puzzles/generate');
    expect((jsonDecode(captured.body) as Map)['width'], 9);
    expect(res.success, isTrue);
  });

  test('throws on non-200', () async {
    final client = MockClient((req) async => http.Response('nope', 500));
    final source = CrosswordGenerationRemoteDataSource(client: client);
    await expectLater(
      source.generate(request),
      throwsA(isA<CrosswordGenerationException>()),
    );
  });

  test('throws on success:false carrying the failure reason', () async {
    final client = MockClient((req) async => http.Response(
        jsonEncode({'success': false, 'failure_reason': 'no fit', 'random_seed': 1, 'stats': {}}),
        200));
    final source = CrosswordGenerationRemoteDataSource(client: client);
    await expectLater(
      source.generate(request),
      throwsA(predicate((e) =>
          e is CrosswordGenerationException && e.message.contains('no fit'))),
    );
  });
}
