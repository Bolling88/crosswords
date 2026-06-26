import 'package:crossword_core/crossword_core.dart';
import 'package:crossword_ui/crossword_ui.dart';
import 'package:flutter_test/flutter_test.dart';

/// 2x4 grid. Across word "across" cells: (0,1),(0,2),(0,3),(1,3) — it redirects
/// down at the last cell. (1,3) is a seed. (0,0) is a clue pointing right.
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
      (1, 3): AnswerCell(value: 'D', isSeed: true),
    },
    words: [across],
    title: 't',
    languageCode: 'sv',
  );
}

/// 2x3 grid with two independent across words: w1 on row 0, w2 on row 1.
CrosswordPuzzle _twoWordPuzzle() {
  const w1 = Word(
    id: 'w1',
    direction: Direction.right,
    cells: [(0, 0), (0, 1)],
  );
  const w2 = Word(
    id: 'w2',
    direction: Direction.right,
    cells: [(1, 0), (1, 1)],
  );
  return const CrosswordPuzzle(
    rows: 2,
    cols: 2,
    cells: {
      (0, 0): AnswerCell(value: 'A'),
      (0, 1): AnswerCell(value: 'B'),
      (1, 0): AnswerCell(value: 'C'),
      (1, 1): AnswerCell(value: 'D'),
    },
    words: [w1, w2],
    title: 't',
    languageCode: 'sv',
  );
}

void main() {
  const nav = WordNavigator();
  final puzzle = _puzzle();
  final across = puzzle.words.first;

  group('step', () {
    test('advances and retreats along the word path', () {
      expect(nav.step(across, (0, 1), 1), (0, 2));
      expect(nav.step(across, (0, 2), -1), (0, 1));
    });

    test('follows the word through its bend', () {
      expect(nav.step(across, (0, 3), 1), (1, 3));
    });

    test('returns null past either end or off the word', () {
      expect(nav.step(across, (1, 3), 1), isNull);
      expect(nav.step(across, (0, 1), -1), isNull);
      expect(nav.step(across, (0, 0), 1), isNull);
    });
  });

  group('axisAt', () {
    test('reports the local axis, bending at the tail', () {
      expect(nav.axisAt(across, (0, 1), Direction.down), Direction.right);
      expect(nav.axisAt(across, (1, 3), Direction.right), Direction.down);
    });

    test('falls back when the cell is off the word or word is null', () {
      expect(nav.axisAt(across, (0, 0), Direction.down), Direction.down);
      expect(nav.axisAt(null, (0, 1), Direction.right), Direction.right);
    });
  });

  group('isEmptyFillable / firstEmptyCell', () {
    test('a non-seed cell with no input is empty fillable', () {
      expect(nav.isEmptyFillable(puzzle, (0, 1), const {}), isTrue);
    });

    test('a seed cell is never empty fillable', () {
      expect(nav.isEmptyFillable(puzzle, (1, 3), const {}), isFalse);
    });

    test('a filled cell is not empty fillable', () {
      expect(nav.isEmptyFillable(puzzle, (0, 1), const {(0, 1): 'A'}), isFalse);
    });

    test('firstEmptyCell skips filled cells and the seed', () {
      expect(
        nav.firstEmptyCell(puzzle, across, const {(0, 1): 'A'}),
        (0, 2),
      );
      // Every editable cell filled (the seed needs no input) -> null.
      expect(
        nav.firstEmptyCell(
          puzzle,
          across,
          const {(0, 1): 'A', (0, 2): 'B', (0, 3): 'C'},
        ),
        isNull,
      );
    });
  });

  group('nextUnfinishedWord', () {
    final two = _twoWordPuzzle();

    test('wraps to the next word with an empty cell', () {
      expect(nav.nextUnfinishedWord(two, 'w1', const {})?.id, 'w2');
      expect(nav.nextUnfinishedWord(two, 'w2', const {})?.id, 'w1');
    });

    test('skips a completed word', () {
      // w2 fully filled -> from w1 it wraps back to itself only if w1 has a gap.
      const inputs = {(1, 0): 'C', (1, 1): 'D'};
      expect(nav.nextUnfinishedWord(two, 'w2', inputs)?.id, 'w1');
    });

    test('returns null when every word is complete', () {
      const inputs = {(0, 0): 'A', (0, 1): 'B', (1, 0): 'C', (1, 1): 'D'};
      expect(nav.nextUnfinishedWord(two, 'w1', inputs), isNull);
    });
  });

  group('isWordCorrect', () {
    test('true only when every editable cell matches', () {
      expect(
        nav.isWordCorrect(
          puzzle,
          across,
          const {(0, 1): 'A', (0, 2): 'B', (0, 3): 'C'},
        ),
        isTrue,
      );
    });

    test('false on a wrong or missing letter', () {
      expect(
        nav.isWordCorrect(
          puzzle,
          across,
          const {(0, 1): 'X', (0, 2): 'B', (0, 3): 'C'},
        ),
        isFalse,
      );
      expect(nav.isWordCorrect(puzzle, across, const {}), isFalse);
    });
  });

  group('isLocked', () {
    test('a seed is locked', () {
      expect(nav.isLocked(puzzle, (1, 3), const {}), isTrue);
    });

    test('a revealed cell is locked', () {
      expect(nav.isLocked(puzzle, (0, 1), const {(0, 1)}), isTrue);
    });

    test('a plain editable cell is not locked', () {
      expect(nav.isLocked(puzzle, (0, 1), const {}), isFalse);
    });
  });

  group('isFilled / isSolved', () {
    test('isFilled counts any letter, right or wrong, ignoring the seed', () {
      const full = {(0, 1): 'X', (0, 2): 'B', (0, 3): 'C'};
      expect(nav.isFilled(puzzle, full), isTrue);
      expect(nav.isFilled(puzzle, const {(0, 1): 'A'}), isFalse);
    });

    test('isSolved requires every editable cell to match', () {
      const solved = {(0, 1): 'A', (0, 2): 'B', (0, 3): 'C'};
      const wrong = {(0, 1): 'X', (0, 2): 'B', (0, 3): 'C'};
      expect(nav.isSolved(puzzle, solved), isTrue);
      expect(nav.isSolved(puzzle, wrong), isFalse);
    });
  });
}
