import 'dart:convert';
import 'dart:io';

import 'package:crossword_api/crossword_api.dart';
import 'package:crossword_core/crossword_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('generate delegates to the repository', () async {
    final body =
        File('test/fixtures/generation_response_9x9.json').readAsStringSync();
    final service = PuzzleGenerationService(
      repository: CrosswordGenerationRepository(
        remoteDataSource: CrosswordGenerationRemoteDataSource(
          client: MockClient(
            (req) async => http.Response.bytes(
              utf8.encode(body),
              200,
              headers: {'content-type': 'application/json'},
            ),
          ),
        ),
      ),
    );

    final puzzle = await service.generate(
      width: 9,
      height: 9,
      maxWordLen: 6,
      title: 'X',
    );
    expect(puzzle.rows, 9);
  });

  test('loadTestPuzzle uses the injected loader', () async {
    final fake = CrosswordPuzzle(
      rows: 1,
      cols: 1,
      cells: const {},
      words: const [],
      title: 'bundled',
      languageCode: 'sv',
    );
    final service = PuzzleGenerationService(
      repository: CrosswordGenerationRepository(
        remoteDataSource: CrosswordGenerationRemoteDataSource(
          client: MockClient(
            (req) async => http.Response('{}', 500),
          ),
        ),
      ),
      loadTestPuzzleFn: () async => fake,
    );

    final puzzle = await service.loadTestPuzzle();
    expect(puzzle.title, 'bundled');
  });
}
