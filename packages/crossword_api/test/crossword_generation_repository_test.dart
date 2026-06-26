import 'dart:io';

import 'package:crossword_api/crossword_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _CapturingRemoteDataSource implements CrosswordGenerationRemoteDataSource {
  CrosswordGenerationRequest? captured;

  @override
  Future<CrosswordGenerationResponse> generate(
    CrosswordGenerationRequest request,
  ) async {
    captured = request;
    return const CrosswordGenerationResponse(
      success: false,
      failureReason: 'test',
    );
  }
}

void main() {
  test('repository forwards every field into the request DTO', () async {
    final remote = _CapturingRemoteDataSource();
    final repository = CrosswordGenerationRepository(remoteDataSource: remote);

    try {
      await repository.generate(
        width: 17,
        height: 13,
        maxWordLen: 8,
        title: 'T',
        seedWords: ['KATT'],
        languageCode: 'sv',
        randomSeed: 42,
        maxSeconds: 60,
        pictureCols: 8,
        pictureRows: 6,
      );
    } catch (_) {
      // Mapper may throw on the minimal failure response; we only assert the
      // captured request below.
    }

    final captured = remote.captured;
    expect(captured, isNotNull);
    expect(captured?.width, 17);
    expect(captured?.height, 13);
    expect(captured?.maxWordLen, 8);
    expect(captured?.seedWords, ['KATT']);
    expect(captured?.languageCode, 'sv');
    expect(captured?.randomSeed, 42);
    expect(captured?.maxSeconds, 60);
    expect(captured?.pictureCols, 8);
    expect(captured?.pictureRows, 6);
  });


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
