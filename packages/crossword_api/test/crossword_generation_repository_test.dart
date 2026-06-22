import 'dart:io';

import 'package:crossword_api/crossword_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  CrosswordGenerationRepository repoWith(MockClient client) =>
      CrosswordGenerationRepository(
        remoteDataSource: CrosswordGenerationRemoteDataSource(client: client),
      );

  test('returns a mapped CrosswordPuzzle on success', () async {
    final body =
        File('test/fixtures/generation_response_9x9.json').readAsStringSync();
    final repo = repoWith(
      MockClient(
        (req) async => http.Response(
          body,
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );

    final puzzle = await repo.generate(
      width: 9,
      height: 9,
      maxWordLen: 6,
      title: 'Nytt korsord',
    );

    expect(puzzle.rows, 9);
    expect(puzzle.title, 'Nytt korsord');
    expect(puzzle.wordById('0'), isNotNull);
  });

  test('propagates CrosswordGenerationException on failure', () async {
    final repo = repoWith(MockClient((req) async => http.Response('x', 500)));
    await expectLater(
      repo.generate(width: 9, height: 9, maxWordLen: 6, title: 'x'),
      throwsA(isA<CrosswordGenerationException>()),
    );
  });
}
