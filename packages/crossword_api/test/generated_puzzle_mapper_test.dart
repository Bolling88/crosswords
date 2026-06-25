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

  // ── Answer cell with null letter is an unused/open grid position ──────────
  // The generator routinely emits answer cells that belong to no word (empty
  // word_ids, null letter). These are inert open positions, not malformed
  // data, so they map to BlockCell rather than throwing.
  test('answer cell with null letter maps to BlockCell (not an error)', () {
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
    final puzzle = GeneratedPuzzleMapper.map(response, title: 'X');
    expect(puzzle.cells[(0, 0)], isA<BlockCell>());
  });

  // A null-letter answer cell alongside a real lettered answer cell must not
  // abort the whole mapping — this is the shape every live response has.
  test('null-letter answer cell coexists with lettered answer cells', () {
    const response = CrosswordGenerationResponse(
      success: true,
      gridCells: [
        [
          GenerationGridCellDto(
            kind: 'answer',
            row: 0,
            col: 0,
            // unused open cell, no letter
          ),
          GenerationGridCellDto(
            kind: 'answer',
            row: 0,
            col: 1,
            letter: 'A',
          ),
        ],
      ],
      slots: [],
    );
    final puzzle = GeneratedPuzzleMapper.map(response, title: 'X');
    expect(puzzle.cells[(0, 0)], isA<BlockCell>());
    expect(puzzle.cells[(0, 1)], isA<AnswerCell>());
    expect((puzzle.cells[(0, 1)] as AnswerCell).value, 'A');
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

  // Cell (5,0) carries two rightward clues: slot 6 starts at row 4 (above),
  // slot 8 starts at row 5. Top-first ordering puts slot 6 first.
  test('two-clue box (5,0) orders arrows top-first by word start', () {
    final clue = puzzle.cells[(5, 0)] as ClueCell;
    expect(clue.arrows.length, 2);
    expect(clue.arrows[0].wordId, '6');
    expect(clue.arrows[1].wordId, '8');
  });

  // Cell (5,7): slot 21 starts at row 4 (above), slot 23 at row 6.
  test('two-clue box (5,7) orders arrows top-first by word start', () {
    final clue = puzzle.cells[(5, 7)] as ClueCell;
    expect(clue.arrows.length, 2);
    expect(clue.arrows[0].wordId, '21');
    expect(clue.arrows[1].wordId, '23');
  });

  // Clue (0,7) sits diagonally NE of its word start (1,6); the word runs right.
  test('diagonal clue (0,7) resolves to diagonalSwThenRight', () {
    final clue = puzzle.cells[(0, 7)] as ClueCell;
    final arrow = clue.arrows.firstWhere((a) => a.wordId == '1');
    expect(arrow.shape, ArrowShape.diagonalSwThenRight);
  });

  // Guards the sort itself: the clue tags are emitted BOTTOM-first (slot 100
  // starts at row 2, below the clue) then TOP (slot 200 starts at row 0,
  // above the clue). Without the top-first sort in _arrowsFor the arrows would
  // keep emission order and arrows.first would be slot 100; the sort must
  // reorder so arrows.first is the smaller-startRow slot 200.
  test('arrows are re-sorted top-first when tags arrive bottom-first', () {
    const response = CrosswordGenerationResponse(
      success: true,
      gridCells: [
        [
          GenerationGridCellDto(
            kind: 'clue',
            row: 1,
            col: 1,
            clueTags: [
              GenerationClueTagDto(id: 100, arrow: '↓'), // bottom word, FIRST
              GenerationClueTagDto(id: 200, arrow: '→'), // top word, SECOND
            ],
          ),
        ],
      ],
      slots: [
        // Below the clue (start (2,1)): down word, larger startRow.
        GenerationSlotDto(
          slotId: 100,
          startRow: 2,
          startCol: 1,
          direction: 'down',
          length: 1,
          clueRow: 1,
          clueCol: 1,
        ),
        // Above the clue (start (0,1)): right word, smaller startRow.
        GenerationSlotDto(
          slotId: 200,
          startRow: 0,
          startCol: 1,
          direction: 'right',
          length: 1,
          clueRow: 1,
          clueCol: 1,
        ),
      ],
    );
    final localPuzzle = GeneratedPuzzleMapper.map(response, title: 'X');
    final clue = localPuzzle.cells[(1, 1)] as ClueCell;
    expect(clue.arrows.length, 2);
    // Top word (slot 200) comes first despite being emitted second.
    expect(clue.arrows.first.wordId, '200');
    expect(clue.arrows.last.wordId, '100');
  });
}
