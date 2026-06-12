import 'package:crossword_core/crossword_core.dart';
import 'package:crossword_ui/crossword_ui.dart';
import 'package:flutter_test/flutter_test.dart';

CrosswordPuzzle _puzzle() => const CrosswordPuzzle(
      rows: 1,
      cols: 2,
      cells: {
        (0, 0): AnswerCell(value: 'A'),
        (0, 1): AnswerCell(value: 'B'),
      },
      words: [],
      title: 't',
      languageCode: 'sv',
    );

void main() {
  test('withConfirmedWord records the word and bumps the token', () {
    final state = CrosswordState(puzzle: _puzzle());
    final confirmed = state.withConfirmedWord('w1');

    expect(confirmed.confirmedWordId, 'w1');
    expect(confirmed.confirmedWordToken, 1);
    expect(confirmed.withConfirmedWord('w2').confirmedWordToken, 2);
  });

  test('withActiveWord sets the full selection context', () {
    final state = CrosswordState(puzzle: _puzzle()).withActiveWord(
      wordId: 'w1',
      selectedCell: (0, 0),
      direction: Direction.right,
      highlightedCells: const {(0, 0), (0, 1)},
      clueCell: (0, 1),
    );

    expect(state.activeWordId, 'w1');
    expect(state.activeClueCell, (0, 1));
    expect(state.highlightedCells, {(0, 0), (0, 1)});
  });

  test('withLoneCell clears the active word and clue cell', () {
    final active = CrosswordState(puzzle: _puzzle()).withActiveWord(
      wordId: 'w1',
      selectedCell: (0, 0),
      direction: Direction.right,
      highlightedCells: const {(0, 0)},
      clueCell: (0, 1),
    );
    final lone = active.withLoneCell((0, 1));

    expect(lone.activeWordId, isNull);
    expect(lone.activeClueCell, isNull);
    expect(lone.highlightedCells, {(0, 1)});
  });

  test('event states copy every field from the live state', () {
    final state = CrosswordState(
      puzzle: _puzzle(),
      userInputs: const {(0, 0): 'A'},
      incorrectCells: const {(0, 1)},
      revealedCells: const {(0, 0)},
      isSolved: true,
    );
    final solved = PuzzleSolved(state: state);

    expect(solved.userInputs, state.userInputs);
    expect(solved.incorrectCells, state.incorrectCells);
    expect(solved.revealedCells, state.revealedCells);
    expect(solved.isSolved, isTrue);
  });

  test('two instances of the same event state are never equal', () {
    final state = CrosswordState(puzzle: _puzzle());

    expect(PuzzleSolved(state: state), isNot(PuzzleSolved(state: state)));
    expect(
      PuzzleFilledButIncorrect(state: state),
      isNot(PuzzleFilledButIncorrect(state: state)),
    );
  });
}
