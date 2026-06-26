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

  // ── Picture cells: ragged grid_cells must not shrink the puzzle width ─────
  // A picture cell spans rowspan×colspan grid positions but the backend emits
  // it as a SINGLE origin entry and omits the covered positions. A row holding
  // a picture therefore has fewer entries than the grid is wide, so deriving
  // cols from `gridCells.first.length` undercounts the width by colspan-1 and
  // the rightmost columns never render. Width must come from cell coordinates.
  test('picture colspan does not shrink puzzle width (ragged first row)', () {
    const response = CrosswordGenerationResponse(
      success: true,
      gridCells: [
        // Row 0: 2x2 picture at (0,0) collapses cols 0-1 into one entry, then
        // real cells at cols 2 and 3 → 3 entries for a 4-wide grid.
        [
          GenerationGridCellDto(
            kind: 'picture',
            row: 0,
            col: 0,
            rowspan: 2,
            colspan: 2,
          ),
          GenerationGridCellDto(kind: 'answer', row: 0, col: 2, letter: 'A'),
          GenerationGridCellDto(kind: 'answer', row: 0, col: 3, letter: 'B'),
        ],
        // Row 1: cols 0-1 covered by the picture's rowspan → only cols 2-3.
        [
          GenerationGridCellDto(kind: 'answer', row: 1, col: 2, letter: 'C'),
          GenerationGridCellDto(kind: 'answer', row: 1, col: 3, letter: 'D'),
        ],
      ],
      slots: [],
    );
    final puzzle = GeneratedPuzzleMapper.map(response, title: 'X');
    expect(puzzle.cols, 4);
    expect(puzzle.rows, 2);
    // The cells that previously fell outside the clipped width are present.
    expect(puzzle.cells[(0, 3)], isA<AnswerCell>());
    expect(puzzle.cells[(1, 3)], isA<AnswerCell>());
  });

  // ── Picture cells map to ImageCell across their whole span ───────────────
  // The origin entry is the only one the backend emits; the mapper must
  // materialize the span-covered positions too so they render under the image
  // overlay instead of as blank holes, and so a word path that illegally
  // crosses the image is caught by validation.
  test('picture origin maps to an origin ImageCell carrying its span', () {
    const response = CrosswordGenerationResponse(
      success: true,
      gridCells: [
        [
          GenerationGridCellDto(
            kind: 'picture',
            row: 0,
            col: 0,
            rowspan: 2,
            colspan: 2,
          ),
          GenerationGridCellDto(kind: 'answer', row: 0, col: 2, letter: 'A'),
        ],
      ],
      slots: [],
    );
    final puzzle = GeneratedPuzzleMapper.map(response, title: 'X');
    final origin = puzzle.cells[(0, 0)];
    expect(origin, isA<ImageCell>());
    expect((origin as ImageCell).isOrigin, isTrue);
    expect(origin.spanRows, 2);
    expect(origin.spanCols, 2);
  });

  test('picture-covered positions map to non-origin ImageCells', () {
    const response = CrosswordGenerationResponse(
      success: true,
      gridCells: [
        [
          GenerationGridCellDto(
            kind: 'picture',
            row: 0,
            col: 0,
            rowspan: 2,
            colspan: 2,
          ),
          GenerationGridCellDto(kind: 'answer', row: 0, col: 2, letter: 'A'),
        ],
      ],
      slots: [],
    );
    final puzzle = GeneratedPuzzleMapper.map(response, title: 'X');
    for (final pos in const [(0, 1), (1, 0), (1, 1)]) {
      final cell = puzzle.cells[pos];
      expect(cell, isA<ImageCell>(), reason: 'covered $pos should be ImageCell');
      expect((cell as ImageCell).isOrigin, isFalse);
    }
  });

  test('word path crossing a picture span throws', () {
    const response = CrosswordGenerationResponse(
      success: true,
      gridCells: [
        [
          GenerationGridCellDto(
            kind: 'picture',
            row: 0,
            col: 0,
            rowspan: 1,
            colspan: 2,
          ),
        ],
      ],
      slots: [
        // A rightward word starting inside the image span.
        GenerationSlotDto(
          slotId: 1,
          startRow: 0,
          startCol: 0,
          direction: 'right',
          length: 2,
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

  // Real backend response (11×11, 3×3 picture at (0,0)) captured from
  // POST /crossword-puzzles/generate with picture_cols/rows = 3. Guards the end
  // -to-end fix: ragged grid_cells must not clip the width, and the picture
  // span must materialize as ImageCells.
  test('real picture response maps to full 11x11 grid with an ImageCell span',
      () {
    final raw = File('test/fixtures/generation_response_picture_11x11.json')
        .readAsStringSync();
    final res = CrosswordGenerationResponse.fromJson(
        jsonDecode(raw) as Map<String, dynamic>);
    final picturePuzzle = GeneratedPuzzleMapper.map(res, title: 'Pic');

    // Width must not be clipped to the ragged first row's entry count (9).
    expect(picturePuzzle.cols, 11);
    expect(picturePuzzle.rows, 11);

    // The previously-clipped rightmost column now holds real cells.
    expect(picturePuzzle.cells.containsKey((0, 10)), isTrue);

    // The 3×3 picture at (0,0): origin plus eight covered ImageCells.
    final origin = picturePuzzle.cells[(0, 0)];
    expect(origin, isA<ImageCell>());
    expect((origin as ImageCell).isOrigin, isTrue);
    expect(origin.spanRows, 3);
    expect(origin.spanCols, 3);
    for (var r = 0; r < 3; r++) {
      for (var c = 0; c < 3; c++) {
        final cell = picturePuzzle.cells[(r, c)];
        expect(cell, isA<ImageCell>(), reason: 'picture cell ($r,$c)');
        expect((cell as ImageCell).isOrigin, (r == 0 && c == 0));
      }
    }

    // The standalone arrow at (3,0) spans 2 rows; (4,0) is omitted from the
    // response, so the mapper must materialize it rather than leave a hole the
    // grid would paint as a transparent gap.
    expect(picturePuzzle.cells[(3, 0)], isA<BlockCell>());
    expect(picturePuzzle.cells.containsKey((4, 0)), isTrue,
        reason: 'arrow-covered (4,0) must not be a hole');
    expect(picturePuzzle.cells[(4, 0)], isA<BlockCell>());
  });

  test('arrow cell materializes its whole span as BlockCells', () {
    const response = CrosswordGenerationResponse(
      success: true,
      gridCells: [
        [
          GenerationGridCellDto(
            kind: 'arrow',
            row: 0,
            col: 0,
            rowspan: 2,
            colspan: 1,
          ),
          GenerationGridCellDto(kind: 'answer', row: 0, col: 1, letter: 'A'),
        ],
      ],
      slots: [],
    );
    final puzzle = GeneratedPuzzleMapper.map(response, title: 'X');
    expect(puzzle.cells[(0, 0)], isA<BlockCell>());
    expect(puzzle.cells[(1, 0)], isA<BlockCell>(),
        reason: 'arrow-covered (1,0) must be materialized, not a hole');
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

  // ── Fix 1: null-letter cell covered by a word path is a corrupt puzzle ───
  // The slot's path spans (0,0) which has a null letter → BlockCell, while the
  // word still claims that position. The mapper must detect this and throw.
  test(
      'throws CrosswordGenerationException when a word path covers a BlockCell '
      '(null-letter answer cell on a slot path)', () {
    const response = CrosswordGenerationResponse(
      success: true,
      gridCells: [
        [
          GenerationGridCellDto(
            kind: 'answer',
            row: 0,
            col: 0,
            // null letter → will become BlockCell
          ),
          GenerationGridCellDto(
            kind: 'answer',
            row: 0,
            col: 1,
            letter: 'A',
          ),
        ],
      ],
      slots: [
        GenerationSlotDto(
          slotId: 1,
          startRow: 0,
          startCol: 0,
          direction: 'right',
          length: 2,
          clueRow: 0,
          clueCol: 0,
        ),
      ],
    );
    expect(
      () => GeneratedPuzzleMapper.map(response, title: 'X'),
      throwsA(
        isA<CrosswordGenerationException>().having(
          (e) => e.toString(),
          'message',
          contains('(0, 0)'),
        ),
      ),
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
