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

/// 1x3 grid: clue, a seed cell with given letter 'A', and one normal cell.
CrosswordPuzzle _seedPuzzle() {
  const w = Word(
    id: 'w',
    direction: Direction.right,
    cells: [(0, 1), (0, 2)],
  );
  return const CrosswordPuzzle(
    rows: 1,
    cols: 3,
    cells: {
      (0, 0): ClueCell(arrows: [
        ClueArrow(
          direction: Direction.right,
          shape: ArrowShape.straightRight,
          wordId: 'w',
        ),
      ]),
      (0, 1): AnswerCell(value: 'A', isSeed: true),
      (0, 2): AnswerCell(value: 'B'),
    },
    words: [w],
    seedPositions: {(0, 1)},
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

/// 3x4 grid where a redirected word h1 (cells (0,1),(0,2),(1,2),(2,2), bending
/// down) and a straight word h2 (cells (2,2),(2,3)) share the cell (2,2): h1
/// passes through it vertically, h2 horizontally.
CrosswordPuzzle _overlapPuzzle() {
  const h1 = Word(
    id: 'h1',
    direction: Direction.right,
    cells: [(0, 1), (0, 2), (1, 2), (2, 2)],
  );
  const h2 = Word(
    id: 'h2',
    direction: Direction.right,
    cells: [(2, 2), (2, 3)],
  );
  return const CrosswordPuzzle(
    rows: 3,
    cols: 4,
    cells: {
      (0, 0): ClueCell(arrows: [
        ClueArrow(
          direction: Direction.right,
          shape: ArrowShape.straightRight,
          wordId: 'h1',
        ),
      ]),
      (0, 1): AnswerCell(value: 'A'),
      (0, 2): AnswerCell(value: 'B'),
      (0, 3): BlockCell(),
      (1, 0): BlockCell(),
      (1, 1): BlockCell(),
      (1, 2): AnswerCell(value: 'C'),
      (1, 3): BlockCell(),
      (2, 0): BlockCell(),
      (2, 1): ClueCell(arrows: [
        ClueArrow(
          direction: Direction.right,
          shape: ArrowShape.straightRight,
          wordId: 'h2',
        ),
      ]),
      (2, 2): AnswerCell(value: 'D'),
      (2, 3): AnswerCell(value: 'E'),
    },
    words: [h1, h2],
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

    test('re-selecting the current cell toggles to the crossing word', () {
      // First tap selects the horizontal word h2 at the shared cell (2,2).
      final selected =
          engine.selectCell(CrosswordState(puzzle: _overlapPuzzle()), 2, 2);
      expect(selected.activeWordId, 'h2');
      expect(selected.currentDirection, Direction.right);

      // Re-tapping the same cell toggles to the vertical word h1 there.
      final toggled = engine.selectCell(selected, 2, 2);
      expect(toggled.activeWordId, 'h1');
      expect(toggled.selectedCell, (2, 2));
      expect(toggled.currentDirection, Direction.down);
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

  group('inputLetter correctness', () {
    test('typing the last correct letter marks the puzzle solved', () {
      final state = CrosswordState(
        puzzle: _puzzle(),
        activeWordId: 'across',
        selectedCell: (1, 3),
        userInputs: const {(0, 1): 'A', (0, 2): 'B', (0, 3): 'C'},
        highlightedCells: const {(0, 1), (0, 2), (0, 3), (1, 3)},
      );

      expect(engine.inputLetter(state, 'D').isSolved, isTrue);
      expect(engine.inputLetter(state, 'X').isSolved, isFalse);
    });

    test('autocheck marks a wrong letter immediately', () {
      final active = engine.selectCell(CrosswordState(puzzle: _puzzle()), 0, 1);
      final next = engine.inputLetter(active, 'X', autocheck: true);

      expect(next.incorrectCells, {(0, 1)});
    });

    test('without autocheck wrong letters enter unmarked', () {
      final active = engine.selectCell(CrosswordState(puzzle: _puzzle()), 0, 1);

      expect(engine.inputLetter(active, 'X').incorrectCells, isEmpty);
    });

    test('editing a marked cell clears its mark', () {
      final marked = CrosswordState(
        puzzle: _puzzle(),
        activeWordId: 'across',
        selectedCell: (0, 1),
        userInputs: const {(0, 1): 'X'},
        incorrectCells: const {(0, 1)},
        highlightedCells: const {(0, 1), (0, 2), (0, 3), (1, 3)},
      );
      final next = engine.inputLetter(marked, 'A');

      expect(next.incorrectCells, isEmpty);
      expect(next.userInputs[(0, 1)], 'A');
    });

    test('typing on a revealed cell advances without overwriting', () {
      final state = CrosswordState(
        puzzle: _puzzle(),
        activeWordId: 'across',
        selectedCell: (0, 1),
        userInputs: const {(0, 1): 'A'},
        revealedCells: const {(0, 1)},
        highlightedCells: const {(0, 1), (0, 2), (0, 3), (1, 3)},
      );
      final next = engine.inputLetter(state, 'Z');

      expect(next.userInputs[(0, 1)], 'A');
      expect(next.selectedCell, (0, 2));
    });

    test('typing on a seed cell advances without writing', () {
      final state = CrosswordState(
        puzzle: _seedPuzzle(),
        activeWordId: 'w',
        selectedCell: (0, 1),
        highlightedCells: const {(0, 1), (0, 2)},
      );
      final next = engine.inputLetter(state, 'Z');

      expect(next.userInputs.containsKey((0, 1)), isFalse);
      expect(next.selectedCell, (0, 2));
    });

    test('autocheck confirms the word when its last letter lands correct', () {
      final state = CrosswordState(
        puzzle: _twoWordPuzzle(),
        activeWordId: 'w1',
        selectedCell: (0, 2),
        userInputs: const {(0, 1): 'A'},
        highlightedCells: const {(0, 1), (0, 2)},
      );
      final next = engine.inputLetter(state, 'B', autocheck: true);

      expect(next.confirmedWordId, 'w1');
      expect(next.confirmedWordToken, 1);
    });

    test('plain unchecked typing never confirms a word', () {
      final state = CrosswordState(
        puzzle: _twoWordPuzzle(),
        activeWordId: 'w1',
        selectedCell: (0, 2),
        userInputs: const {(0, 1): 'A'},
        highlightedCells: const {(0, 1), (0, 2)},
      );

      expect(engine.inputLetter(state, 'B').confirmedWordToken, 0);
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

    test('at the first empty cell of a word it is a no-op', () {
      final state = CrosswordState(
        puzzle: _puzzle(),
        activeWordId: 'across',
        selectedCell: (0, 1),
      );

      expect(engine.backspace(state), state);
    });
  });

  group('solved & filled', () {
    test('computeSolved is true only when every letter matches', () {
      final solved = CrosswordState(
        puzzle: _puzzle(),
        userInputs: const {(0, 1): 'A', (0, 2): 'B', (0, 3): 'C', (1, 3): 'D'},
      );
      final wrong = CrosswordState(
        puzzle: _puzzle(),
        userInputs: const {(0, 1): 'X', (0, 2): 'B', (0, 3): 'C', (1, 3): 'D'},
      );
      final missing = CrosswordState(
        puzzle: _puzzle(),
        userInputs: const {(0, 1): 'A'},
      );

      expect(engine.computeSolved(solved, solved.userInputs), isTrue);
      expect(engine.computeSolved(wrong, wrong.userInputs), isFalse);
      expect(engine.computeSolved(missing, missing.userInputs), isFalse);
    });

    test('seed cells count as given-correct', () {
      final state = CrosswordState(
        puzzle: _seedPuzzle(),
        userInputs: const {(0, 2): 'B'},
      );

      expect(engine.computeSolved(state, state.userInputs), isTrue);
      expect(engine.isFilled(state), isTrue);
    });

    test('isFilled counts any letters, right or wrong', () {
      final wrongButFull = CrosswordState(
        puzzle: _puzzle(),
        userInputs: const {(0, 1): 'X', (0, 2): 'X', (0, 3): 'X', (1, 3): 'X'},
      );

      expect(engine.isFilled(wrongButFull), isTrue);
      expect(engine.isFilled(CrosswordState(puzzle: _puzzle())), isFalse);
    });
  });

  test('activating a word records its clue cell for highlighting', () {
    final next = engine.selectCell(CrosswordState(puzzle: _puzzle()), 0, 2);

    expect(next.activeClueCell, (0, 0));
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
