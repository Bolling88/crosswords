import 'package:crossword_core/crossword_core.dart';
import 'package:crossword_ui/crossword_ui.dart';
import 'package:flutter_test/flutter_test.dart';

/// 2x4 grid. Across word "across" cells: (0,1),(0,2),(0,3),(1,3) — it redirects
/// down at the last cell. (0,0) is a clue pointing right into the word.
CrosswordPuzzle _puzzle() {
  const across = Word(
    id: 'across',
    direction: Direction.right,
    cells: [(0, 1), (0, 2), (0, 3), (1, 3)],
  );
  return const CrosswordPuzzle(
    rows: 2,
    cols: 4,
    cells: {
      (0, 0): ClueCell(arrows: [
        ClueArrow(
          direction: Direction.right,
          shape: ArrowShape.straightRight,
          wordId: 'across',
        ),
      ]),
      (0, 1): AnswerCell(value: 'A'),
      (0, 2): AnswerCell(value: 'B'),
      (0, 3): AnswerCell(value: 'C'),
      (1, 0): BlockCell(),
      (1, 1): BlockCell(),
      (1, 2): BlockCell(),
      (1, 3): AnswerCell(value: 'D'),
    },
    words: [across],
    title: 't',
    languageCode: 'sv',
  );
}

/// 2x3 grid with two independent across words, w1 on row 0 and w2 on row 1.
CrosswordPuzzle _twoWordPuzzle() {
  const w1 = Word(
    id: 'w1',
    direction: Direction.right,
    cells: [(0, 1), (0, 2)],
  );
  const w2 = Word(
    id: 'w2',
    direction: Direction.right,
    cells: [(1, 1), (1, 2)],
  );
  return const CrosswordPuzzle(
    rows: 2,
    cols: 3,
    cells: {
      (0, 0): ClueCell(arrows: [
        ClueArrow(
          direction: Direction.right,
          shape: ArrowShape.straightRight,
          wordId: 'w1',
        ),
      ]),
      (0, 1): AnswerCell(value: 'A'),
      (0, 2): AnswerCell(value: 'B'),
      (1, 0): ClueCell(arrows: [
        ClueArrow(
          direction: Direction.right,
          shape: ArrowShape.straightRight,
          wordId: 'w2',
        ),
      ]),
      (1, 1): AnswerCell(value: 'C'),
      (1, 2): AnswerCell(value: 'D'),
    },
    words: [w1, w2],
    title: 't',
    languageCode: 'sv',
  );
}

/// 1x1 grid with a single answer cell that belongs to no word.
CrosswordPuzzle _loneCellPuzzle() {
  return const CrosswordPuzzle(
    rows: 1,
    cols: 1,
    cells: {
      (0, 0): AnswerCell(value: 'X'),
    },
    words: [],
    title: 't',
    languageCode: 'sv',
  );
}

void main() {
  const engine = CrosswordEngine();

  group('selectCell', () {
    test('activating a clue selects the word and highlights it', () {
      final next = engine.selectCell(CrosswordState(puzzle: _puzzle()), 0, 0);

      expect(next.activeWordId, 'across');
      expect(next.selectedCell, (0, 1));
      expect(next.currentDirection, Direction.right);
      expect(
        next.highlightedCells,
        {(0, 1), (0, 2), (0, 3), (1, 3)},
      );
    });

    test('selecting an answer cell activates its word at that cell', () {
      final next = engine.selectCell(CrosswordState(puzzle: _puzzle()), 0, 2);

      expect(next.activeWordId, 'across');
      expect(next.selectedCell, (0, 2));
    });

    test('a cell with no word becomes a lone selection', () {
      final next =
          engine.selectCell(CrosswordState(puzzle: _loneCellPuzzle()), 0, 0);

      expect(next.selectedCell, (0, 0));
      expect(next.activeWordId, isNull);
      expect(next.highlightedCells, {(0, 0)});
    });

    test('block and missing cells are ignored', () {
      final state = CrosswordState(puzzle: _puzzle());
      expect(engine.selectCell(state, 1, 0), state); // block
      expect(engine.selectCell(state, 5, 5), state); // off-grid
    });
  });

  group('inputLetter', () {
    test('records the letter and advances within the word', () {
      final active = engine.selectCell(CrosswordState(puzzle: _puzzle()), 0, 0);
      final next = engine.inputLetter(active, 'X');

      expect(next.userInputs[(0, 1)], 'X');
      expect(next.selectedCell, (0, 2));
    });

    test('filling the last cell jumps back to a skipped gap', () {
      // Active word, caret on the last cell (1,3), with (0,3) still empty.
      final state = CrosswordState(
        puzzle: _puzzle(),
        activeWordId: 'across',
        selectedCell: (1, 3),
        userInputs: const {(0, 1): 'A', (0, 2): 'B'},
        highlightedCells: const {(0, 1), (0, 2), (0, 3), (1, 3)},
      );
      final next = engine.inputLetter(state, 'D');

      expect(next.userInputs[(1, 3)], 'D');
      expect(next.selectedCell, (0, 3));
    });

    test('completing a word advances to the next unfinished word', () {
      final state = CrosswordState(
        puzzle: _twoWordPuzzle(),
        activeWordId: 'w1',
        selectedCell: (0, 2),
        userInputs: const {(0, 1): 'A'},
        highlightedCells: const {(0, 1), (0, 2)},
      );
      final next = engine.inputLetter(state, 'B');

      expect(next.userInputs[(0, 2)], 'B');
      expect(next.activeWordId, 'w2');
      expect(next.selectedCell, (1, 1));
    });
  });

  group('backspace', () {
    test('clears the selected cell when it has a letter', () {
      final state = CrosswordState(
        puzzle: _puzzle(),
        activeWordId: 'across',
        selectedCell: (0, 2),
        userInputs: const {(0, 2): 'B'},
      );
      final next = engine.backspace(state);

      expect(next.userInputs.containsKey((0, 2)), isFalse);
      expect(next.selectedCell, (0, 2));
    });

    test('steps back and clears the previous cell when empty', () {
      final state = CrosswordState(
        puzzle: _puzzle(),
        activeWordId: 'across',
        selectedCell: (0, 2),
        userInputs: const {(0, 1): 'A'},
      );
      final next = engine.backspace(state);

      expect(next.userInputs.containsKey((0, 1)), isFalse);
      expect(next.selectedCell, (0, 1));
    });
  });

  group('moveSelection', () {
    test('arrow-right lands on the next answer cell', () {
      final active = engine.selectCell(CrosswordState(puzzle: _puzzle()), 0, 1);
      final next = engine.moveSelection(active, 0, 1);

      expect(next.selectedCell, (0, 2));
    });

    test('running off the grid keeps the current selection', () {
      final active = engine.selectCell(CrosswordState(puzzle: _puzzle()), 0, 1);
      final next = engine.moveSelection(active, -1, 0); // up, off-grid

      expect(next.selectedCell, active.selectedCell);
    });
  });
}
