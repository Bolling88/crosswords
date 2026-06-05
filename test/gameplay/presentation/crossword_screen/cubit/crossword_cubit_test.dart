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
