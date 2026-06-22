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

  test('puzzle.id is non-null and starts with the grid dimensions prefix', () {
    expect(puzzle.id, isNotNull);
    expect(puzzle.id, startsWith('gen-9x9-'));
  });

  test('puzzle.id matches compact hash format (no raw solution letters)', () {
    expect(puzzle.id, matches(RegExp(r'^gen-9x9-[0-9a-f]{8}$')));
  });

  test('mapping the same response twice produces the same id (deterministic)',
      () {
    final raw =
        File('test/fixtures/generation_response_9x9.json').readAsStringSync();
    final res = CrosswordGenerationResponse.fromJson(
        jsonDecode(raw) as Map<String, dynamic>);
    final puzzle2 = GeneratedPuzzleMapper.map(res, title: 'Test');
    expect(puzzle2.id, equals(puzzle.id));
  });

  // ── FIX 3: empty grid throws ─────────────────────────────────────────────
  test('throws CrosswordGenerationException for empty grid (no rows)', () {
    const emptyResponse = CrosswordGenerationResponse(
      success: true,
      gridCells: [],
      slots: [],
    );
    expect(
      () => GeneratedPuzzleMapper.map(emptyResponse, title: 'X'),
      throwsA(isA<CrosswordGenerationException>()),
    );
  });

  // ── FIX 2: answer cell with null letter throws ────────────────────────────
  test('throws CrosswordGenerationException for answer cell with null letter',
      () {
    // A minimal 1x1 grid with a single answer cell whose letter is null.
    const response = CrosswordGenerationResponse(
      success: true,
      gridCells: [
        [
          GenerationGridCellDto(
            kind: 'answer',
            row: 0,
            col: 0,
            // letter intentionally omitted (defaults to null)
          ),
        ],
      ],
      slots: [],
    );
    expect(
      () => GeneratedPuzzleMapper.map(response, title: 'X'),
      throwsA(isA<CrosswordGenerationException>()),
    );
  });

  // ── FIX 4: unknown direction throws ──────────────────────────────────────
  test('throws CrosswordGenerationException for unknown slot direction', () {
    // A 1x1 clue cell whose slot uses direction 'left'.
    const response = CrosswordGenerationResponse(
      success: true,
      gridCells: [
        [
          GenerationGridCellDto(
            kind: 'clue',
            row: 0,
            col: 0,
            clueTags: [GenerationClueTagDto(id: 0, arrow: '←')],
          ),
        ],
      ],
      slots: [
        GenerationSlotDto(
          slotId: 0,
          startRow: 0,
          startCol: 1,
          direction: 'left', // unknown direction
          length: 1,
          clueRow: 0,
          clueCol: 0,
        ),
      ],
    );
    expect(
      () => GeneratedPuzzleMapper.map(response, title: 'X'),
      throwsA(isA<CrosswordGenerationException>()),
    );
  });

  // ── FIX 5: clue tag references missing slot throws ────────────────────────
  test('throws CrosswordGenerationException for clue tag with missing slot',
      () {
    // A 1x1 clue cell whose tag.id has no matching slot in the slots list.
    const response = CrosswordGenerationResponse(
      success: true,
      gridCells: [
        [
          GenerationGridCellDto(
            kind: 'clue',
            row: 0,
            col: 0,
            clueTags: [GenerationClueTagDto(id: 99, arrow: '→')],
          ),
        ],
      ],
      slots: [], // slot 99 is absent
    );
    expect(
      () => GeneratedPuzzleMapper.map(response, title: 'X'),
      throwsA(isA<CrosswordGenerationException>()),
    );
  });
}
