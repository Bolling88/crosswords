import 'dart:convert';
import 'dart:io';

import 'package:crossword_api/crossword_api.dart';
import 'package:crossword_core/crossword_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late CrosswordPuzzle puzzle;

  setUp(() {
    final raw = File('test/fixtures/generation_response_9x9.json')
        .readAsStringSync();
    final res = CrosswordGenerationResponse.fromJson(
        jsonDecode(raw) as Map<String, dynamic>);
    puzzle = GeneratedPuzzleMapper.map(res, title: 'Test');
  });

  test('grid dimensions and language', () {
    expect(puzzle.rows, 9);
    expect(puzzle.cols, 9);
    expect(puzzle.languageCode, 'sv');
    expect(puzzle.title, 'Test');
  });

  // Slot 0 starts at (1,0) with word ÅSIKT; first letter at (1,0) is 'Å'.
  test('answer cell letter comes from grid_cells at slot 0 start', () {
    final cell = puzzle.cells[(1, 0)];
    expect(cell, isA<AnswerCell>());
    expect((cell as AnswerCell).value, 'Å');
  });

  test('clue cells become ClueCell with arrows', () {
    expect(puzzle.cells[(0, 0)], isA<ClueCell>());
  });

  test('slot 0 word ÅSIKT is built right from (1,0)', () {
    final word = puzzle.wordById('0');
    expect(word, isNotNull);
    expect(word?.direction, Direction.right);
    expect(word?.cells.first, (1, 0));
    expect(word?.cells.length, 5);
  });

  test('clue at (0,0) for rightward word starting (1,0) is bentDownThenRight',
      () {
    final clue = puzzle.cells[(0, 0)];
    expect(clue, isA<ClueCell>());
    final arrows = (clue as ClueCell).arrows;
    final arrow = arrows.firstWhere((a) => a.wordId == '0');
    expect(arrow.direction, Direction.right);
    expect(arrow.shape, ArrowShape.bentDownThenRight);
  });
}
