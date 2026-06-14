import 'package:crossword_core/crossword_core.dart';
import 'package:crossword_ui/crossword_ui.dart';
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

/// A word plus an isolated answer cell (1,2) that belongs to no word, used to
/// exercise the lone-cell selection branch.
///   Cl(w) A  B
///    .   .  X(lone)
CrosswordPuzzle _loneCellPuzzle() {
  const w = Word(
    id: 'w',
    direction: Direction.right,
    cells: [(0, 1), (0, 2)],
  );
  return const CrosswordPuzzle(
    rows: 2,
    cols: 3,
    cells: {
      (0, 0): ClueCell(arrows: [
        ClueArrow(
          direction: Direction.right,
          shape: ArrowShape.straightRight,
          wordId: 'w',
        ),
      ]),
      (0, 1): AnswerCell(value: 'A'),
      (0, 2): AnswerCell(value: 'B'),
      (1, 0): BlockCell(),
      (1, 1): BlockCell(),
      (1, 2): AnswerCell(value: 'X'),
    },
    words: [w],
    title: 't',
    languageCode: 'sv',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CrosswordCubit cubit;
  late FontService fontService;
  late GameplaySettingsService settingsService;
  late ProgressService progressService;

  CrosswordCubit buildCubit(CrosswordPuzzle puzzle) => CrosswordCubit(
        puzzle: puzzle,
        fontService: fontService,
        settingsService: settingsService,
        progressService: progressService,
      );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    fontService = FontService(prefs: prefs);
    settingsService = GameplaySettingsService(prefs: prefs);
    progressService = ProgressService(prefs: prefs);
    cubit = buildCubit(_puzzle());
  });

  tearDown(() async {
    await cubit.close();
    fontService.dispose();
    settingsService.dispose();
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
      final overlap = buildCubit(_overlapPuzzle());
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

    test('a multi-character value enters every letter in order', () {
      cubit.selectCell(0, 1); // across word (0,1),(0,2),(0,3),(1,3)
      cubit.onInputChanged('${CrosswordCubit.inputSentinel}AB');
      expect(cubit.state.userInputs[(0, 1)], 'A');
      expect(cubit.state.userInputs[(0, 2)], 'B');
      expect(cubit.state.selectedCell, (0, 3));
    });
  });

  test('selecting an answer cell in no word clears the active word and does '
      'not teleport on the next keystroke', () {
    final lone = buildCubit(_loneCellPuzzle());
    addTearDown(lone.close);

    lone.selectCell(0, 0); // activates word w at (0,1)
    expect(lone.state.activeWordId, 'w');

    lone.selectCell(1, 2); // lone answer cell, in no word
    expect(lone.state.selectedCell, (1, 2));
    expect(lone.state.activeWordId, isNull);
    expect(lone.state.highlightedCells, {(1, 2)});

    // Typing here must NOT jump back into word w.
    lone.onLetterInput('X');
    expect(lone.state.userInputs[(1, 2)], 'X');
    expect(lone.state.selectedCell, (1, 2));
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
      overlap = buildCubit(_overlapPuzzle());
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

    test('typing after arrowing into the vertical run follows that word', () {
      overlap.selectCell(0, 1); // h1 across at (0,1)
      overlap.moveSelection(0, 1); // -> (0,2)
      overlap.moveSelection(1, 0); // down -> (1,2), now on h1's vertical run
      overlap.onLetterInput('C'); // must continue DOWN along h1
      expect(overlap.state.userInputs[(1, 2)], 'C');
      expect(overlap.state.selectedCell, (2, 2));
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

  group('persistence', () {
    test('typed letters are saved and restored by a new cubit', () async {
      cubit.selectCell(0, 1);
      cubit.onLetterInput('A');
      await Future<void>.delayed(Duration.zero); // let the async save land

      final restored = buildCubit(_puzzle());
      addTearDown(restored.close);

      expect(restored.state.userInputs[(0, 1)], 'A');
    });

    test('restartPuzzle wipes the grid and the stored progress', () async {
      cubit.selectCell(0, 1);
      cubit.onLetterInput('A');
      await Future<void>.delayed(Duration.zero);

      cubit.restartPuzzle();
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.userInputs, isEmpty);
      final restored = buildCubit(_puzzle());
      addTearDown(restored.close);
      expect(restored.state.userInputs, isEmpty);
    });
  });

  group('autocheck setting', () {
    test('wrong letters are marked while the setting is on', () async {
      await settingsService.setAutocheck(true);
      cubit.selectCell(0, 1);
      cubit.onLetterInput('X');

      expect(cubit.state.incorrectCells, {(0, 1)});
    });

    test('wrong letters enter unmarked while the setting is off', () {
      cubit.selectCell(0, 1);
      cubit.onLetterInput('X');

      expect(cubit.state.incorrectCells, isEmpty);
    });
  });

  group('one-shot events', () {
    test('solving the puzzle emits PuzzleSolved exactly once', () async {
      final events = <CrosswordState>[];
      final sub = cubit.stream.listen(events.add);
      addTearDown(sub.cancel);

      cubit.selectCell(0, 1);
      for (final letter in ['A', 'B', 'C', 'D']) {
        cubit.onLetterInput(letter);
      }
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.isSolved, isTrue);
      expect(events.whereType<PuzzleSolved>().length, 1);
    });

    test('a full but wrong grid emits PuzzleFilledButIncorrect once', () async {
      final events = <CrosswordState>[];
      final sub = cubit.stream.listen(events.add);
      addTearDown(sub.cancel);

      cubit.selectCell(0, 1);
      for (final letter in ['A', 'B', 'C', 'X']) {
        cubit.onLetterInput(letter);
      }
      await Future<void>.delayed(Duration.zero);

      expect(events.whereType<PuzzleFilledButIncorrect>().length, 1);
      expect(events.whereType<PuzzleSolved>(), isEmpty);
    });

    test('revealing the full solution solves without celebrating', () async {
      final events = <CrosswordState>[];
      final sub = cubit.stream.listen(events.add);
      addTearDown(sub.cancel);

      cubit.revealSolution();
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.isSolved, isTrue);
      expect(cubit.state.revealedCells, {(0, 1), (0, 2), (0, 3), (1, 3)});
      expect(events.whereType<PuzzleSolved>(), isEmpty);
    });
  });

  test('a revealed full solution is persisted and restored', () async {
    cubit.revealSolution();
    await Future<void>.delayed(Duration.zero);

    final restored = buildCubit(_puzzle());
    addTearDown(restored.close);

    expect(restored.state.isSolved, isTrue);
    expect(restored.state.revealedCells, {(0, 1), (0, 2), (0, 3), (1, 3)});
  });

  test('check, reveal, and clear actions work end to end', () {
    cubit.selectCell(0, 1);
    cubit.onLetterInput('X'); // wrong letter at (0,1), caret moves to (0,2)
    cubit.checkPuzzle();
    expect(cubit.state.incorrectCells, {(0, 1)});

    cubit.selectCell(0, 1);
    cubit.revealCell();
    expect(cubit.state.userInputs[(0, 1)], 'A');
    expect(cubit.state.revealedCells, {(0, 1)});
    expect(cubit.state.incorrectCells, isEmpty);

    cubit.revealWord();
    expect(cubit.state.isSolved, isTrue);

    cubit.clearWord(); // revealed letters survive a clear
    expect(cubit.state.userInputs.length, 4);
  });
}
