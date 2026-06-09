import 'package:crosswords/gameplay/domain/entities/cell.dart';
import 'package:crosswords/gameplay/domain/entities/clue_arrow.dart';
import 'package:crosswords/gameplay/domain/entities/arrow_shape.dart';
import 'package:crosswords/gameplay/domain/entities/crossword_puzzle.dart';
import 'package:crosswords/gameplay/domain/entities/direction.dart';
import 'package:crosswords/gameplay/domain/entities/word.dart';
import 'package:crosswords/gameplay/presentation/crossword_screen/cubit/crossword_cubit.dart';
import 'package:crosswords/settings/domain/entities/app_font.dart';
import 'package:crosswords/settings/domain/services/font_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 1x4 grid: clue at (0,0) -> across word "ABC" with a redirect that turns
/// down at (0,3). Layout:
///   C  A  B  D(redirect-down)
///               E
/// Across word "across" cells: (0,1),(0,2),(0,3),(1,3).
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

/// Grid where a redirected across word (h1) and a genuine across word (h2)
/// share cell (2,2) — h1 runs through it vertically (its bent tail), h2
/// horizontally — even though BOTH have base Direction.right.
///   Cl(h1) A  B          (h1: (0,1),(0,2) then redirects DOWN)
///          .  C  .
///       .  Cl(h2) D  E    (h2: (2,2),(2,3))
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
  TestWidgetsFlutterBinding.ensureInitialized();

  late CrosswordCubit cubit;
  late FontService fontService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    fontService = FontService(prefs: prefs);
    cubit = CrosswordCubit(puzzle: _puzzle(), fontService: fontService);
  });

  tearDown(() async {
    await cubit.close();
    fontService.dispose();
  });

  test('tapping a clue selects the first cell of its word and highlights it',
      () {
    cubit.selectCell(0, 0);
    expect(cubit.state.selectedCell, (0, 1));
    expect(cubit.state.currentDirection, Direction.right);
    expect(
      cubit.state.highlightedCells,
      {(0, 1), (0, 2), (0, 3), (1, 3)},
    );
  });

  test('letter input advances along the resolved (redirected) word path', () {
    cubit.selectCell(0, 1);
    cubit.onLetterInput('A');
    expect(cubit.state.selectedCell, (0, 2));
    cubit.onLetterInput('B');
    expect(cubit.state.selectedCell, (0, 3));
    // The word redirects downward here; next cell is (1,3), not off-grid right.
    cubit.onLetterInput('C');
    expect(cubit.state.selectedCell, (1, 3));
    expect(cubit.state.userInputs[(0, 1)], 'A');
  });

  test('backspace on an empty cell steps back and clears the previous cell', () {
    cubit.selectCell(0, 1);
    cubit.onLetterInput('A'); // writes (0,1)='A', moves to empty (0,2)
    cubit.onBackspace(); // (0,2) empty -> step back to (0,1) and clear it
    expect(cubit.state.selectedCell, (0, 1));
    expect(cubit.state.userInputs.containsKey((0, 1)), isFalse);
  });

  test('backspace on a filled cell clears it in place', () {
    cubit.selectCell(0, 1);
    cubit.onLetterInput('A'); // (0,1)='A', now at (0,2)
    cubit.onLetterInput('B'); // (0,2)='B', now at (0,3)
    cubit.selectCell(0, 2); // re-select the filled (0,2)
    cubit.onBackspace(); // (0,2) filled -> clear in place, stay
    expect(cubit.state.selectedCell, (0, 2));
    expect(cubit.state.userInputs.containsKey((0, 2)), isFalse);
    expect(cubit.state.userInputs[(0, 1)], 'A');
  });

  group('arrow-key navigation', () {
    test('moving right/left steps between adjacent answer cells', () {
      cubit.selectCell(0, 1);
      cubit.moveSelection(0, 1);
      expect(cubit.state.selectedCell, (0, 2));
      cubit.moveSelection(0, 1);
      expect(cubit.state.selectedCell, (0, 3));
      cubit.moveSelection(0, -1);
      expect(cubit.state.selectedCell, (0, 2));
    });

    test('moving right activates the across word at the new cell', () {
      cubit.selectCell(0, 1);
      cubit.moveSelection(0, 1);
      expect(cubit.state.activeWordId, 'across');
      expect(cubit.state.currentDirection, Direction.right);
    });

    test('moving off the grid keeps the current selection', () {
      cubit.selectCell(0, 3);
      cubit.moveSelection(0, 1); // (0,4) is off-grid
      expect(cubit.state.selectedCell, (0, 3));
    });

    test('moving over non-answer cells skips to the next answer cell', () {
      // (0,3) down is the redirected tail (1,3); everything else in column 3
      // above/below is answer/edge. From (0,1) moving down hits block cells.
      cubit.selectCell(0, 3);
      cubit.moveSelection(1, 0); // (1,3) is an answer cell
      expect(cubit.state.selectedCell, (1, 3));
    });

    test('moving with no selection does nothing', () {
      cubit.moveSelection(0, 1);
      expect(cubit.state.selectedCell, isNull);
    });

    test('moving down selects the vertical word through a shared cell', () {
      final overlap =
          CrosswordCubit(puzzle: _overlapPuzzle(), fontService: fontService);
      addTearDown(overlap.close);
      overlap.selectCell(0, 1); // activates h1 across, at (0,1)
      overlap.moveSelection(0, 1); // to (0,2), shared by h1's vertical run
      overlap.moveSelection(1, 0); // down -> (1,2), vertical word h1
      expect(overlap.state.selectedCell, (1, 2));
      expect(overlap.state.activeWordId, 'h1');
      expect(overlap.state.currentDirection, Direction.down);
    });
  });

  group('mobile soft-keyboard input', () {
    test('typing a letter via the hidden field fills the cell and advances', () {
      cubit.selectCell(0, 1); // active across word, selected at (0,1)
      cubit.onInputChanged('${CrosswordCubit.inputSentinel}a');
      expect(cubit.state.userInputs[(0, 1)], 'A');
      expect(cubit.state.selectedCell, (0, 2));
      // Controller is reset to the sentinel so the next keystroke is detectable.
      expect(cubit.inputController.text, CrosswordCubit.inputSentinel);
    });

    test('deleting the sentinel triggers a backspace', () {
      cubit.selectCell(0, 1);
      cubit.onInputChanged('${CrosswordCubit.inputSentinel}A'); // (0,1)=A -> (0,2)
      cubit.onInputChanged(''); // sentinel deleted on the now-empty (0,2)
      // Matches the existing backspace rule: empty cell steps back and clears.
      expect(cubit.state.selectedCell, (0, 1));
      expect(cubit.state.userInputs.containsKey((0, 1)), isFalse);
      expect(cubit.inputController.text, CrosswordCubit.inputSentinel);
    });

    test('non-letter input is ignored', () {
      cubit.selectCell(0, 1);
      cubit.onInputChanged('${CrosswordCubit.inputSentinel}5');
      expect(cubit.state.userInputs.containsKey((0, 1)), isFalse);
      expect(cubit.state.selectedCell, (0, 1));
      expect(cubit.inputController.text, CrosswordCubit.inputSentinel);
    });
  });

  test('resetView resets transformationController to identity', () {
    // Mutate to a non-identity value first to make the reset meaningful.
    cubit.transformationController.value = Matrix4.translationValues(10, 10, 0);
    cubit.resetView();
    expect(cubit.transformationController.value, Matrix4.identity());
  });

  test('font change on FontService propagates to cubit state', () async {
    expect(cubit.state.font, AppFont.defaultFont);
    await fontService.selectFont(AppFont.caveat);
    expect(cubit.state.font, AppFont.caveat);
  });

  group('overlapping same-base-direction words', () {
    late CrosswordCubit overlap;

    setUp(() {
      overlap = CrosswordCubit(puzzle: _overlapPuzzle(), fontService: fontService);
    });

    tearDown(() => overlap.close());

    test('a shared cell selects the across word, then toggles to the '
        'vertical (redirected) word', () {
      // Default direction is right -> the genuinely-across word h2.
      overlap.selectCell(2, 2);
      expect(overlap.state.activeWordId, 'h2');
      expect(overlap.state.currentDirection, Direction.right);
      expect(overlap.state.highlightedCells, {(2, 2), (2, 3)});

      // Re-tapping toggles to the word running vertically through (2,2): h1.
      overlap.selectCell(2, 2);
      expect(overlap.state.activeWordId, 'h1');
      expect(overlap.state.currentDirection, Direction.down);
      expect(overlap.state.highlightedCells, {(0, 1), (0, 2), (1, 2), (2, 2)});
    });

    test('finishing a word jumps to the next word\'s first empty cell', () {
      overlap.selectCell(0, 0); // activates h1 at (0,1)
      overlap.onLetterInput('A'); // (0,1) -> (0,2)
      overlap.onLetterInput('B'); // (0,2) -> (1,2)
      overlap.onLetterInput('C'); // (1,2) -> (2,2)
      overlap.onLetterInput('D'); // (2,2) completes h1 -> jump to h2
      // h2 is [(2,2),(2,3)]; (2,2) was just filled, so land on (2,3).
      expect(overlap.state.activeWordId, 'h2');
      expect(overlap.state.selectedCell, (2, 3));
      expect(overlap.state.currentDirection, Direction.right);
      expect(overlap.state.highlightedCells, {(2, 2), (2, 3)});
    });

    test('finishing the last cell fills a remaining gap before jumping', () {
      overlap.selectCell(0, 0); // activates h1 at (0,1)
      overlap.onLetterInput('A'); // (0,1) -> (0,2)
      overlap.moveSelection(1, 0); // skip (0,2), move down to (1,2)
      overlap.onLetterInput('C'); // (1,2) -> (2,2)
      overlap.onLetterInput('D'); // (2,2) is last cell, but (0,2) still empty
      // Stay on h1 and jump back to its gap rather than advancing words.
      expect(overlap.state.activeWordId, 'h1');
      expect(overlap.state.selectedCell, (0, 2));
    });

    test('typing follows the redirected word through its bend', () {
      overlap.selectCell(0, 0); // activates h1 at (0,1)
      expect(overlap.state.selectedCell, (0, 1));
      overlap.onLetterInput('A');
      expect(overlap.state.selectedCell, (0, 2));
      overlap.onLetterInput('B'); // bend: continues DOWN, not off-grid right
      expect(overlap.state.selectedCell, (1, 2));
      overlap.onLetterInput('C');
      expect(overlap.state.selectedCell, (2, 2));
    });
  });
}
