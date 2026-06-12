# Gameplay Feel & Completion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the crossword demo into a finishable game: solved-puzzle detection and celebration, on-demand check/reveal tools with an autocheck setting, visible active-word direction, local progress persistence, and haptic/animated feedback.

**Architecture:** All game logic stays in the pure `CrosswordEngine` (state → state). `CrosswordCubit` orchestrates persistence, haptics, the autocheck setting, and one-shot event states (`PuzzleSolved`, `PuzzleFilledButIncorrect`). Two new SharedPreferences-backed services follow the `FontService` pattern. UI gains a game menu, a celebration dialog, new cell paint states, and implicit (stateless) animations.

**Tech Stack:** Flutter workspace packages `crossword_core` (domain) and `crossword_ui` (engine/cubit/widgets), apps `apps/mobile` + `apps/web`, flutter_bloc, Equatable, shared_preferences, flutter_test.

**Spec:** `docs/superpowers/specs/2026-06-12-gameplay-feel-completion-design.md`

**Conventions that bind every task:** no `!` operator, no StatefulWidget/setState, controllers live in cubits, Swedish user-facing strings only via `Strings`, colors only via `AppColors`, trailing commas, `withAlpha` not `withOpacity`.

---

### Task 1: `CrosswordPuzzle.cluePositionOf`

**Files:**
- Modify: `packages/crossword_core/lib/gameplay/domain/entities/crossword_puzzle.dart`
- Test: `packages/crossword_core/test/gameplay/domain/entities/crossword_puzzle_test.dart`

- [x] **Step 1: Write the failing tests** — append this group inside `main()` of the existing test file:

```dart
group('cluePositionOf', () {
  const word = Word(id: 'w1', direction: Direction.right, cells: [(0, 1), (0, 2)]);
  const puzzle = CrosswordPuzzle(
    rows: 1,
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
    },
    words: [word],
    title: 't',
    languageCode: 'sv',
  );

  test('returns the clue cell whose arrow starts the word', () {
    expect(puzzle.cluePositionOf('w1'), (0, 0));
  });

  test('returns null for an unknown word id', () {
    expect(puzzle.cluePositionOf('nope'), isNull);
  });
});
```

- [x] **Step 2: Run to verify failure**

Run: `cd packages/crossword_core && flutter test test/gameplay/domain/entities/crossword_puzzle_test.dart`
Expected: FAIL — `cluePositionOf` isn't defined.

- [x] **Step 3: Implement** — add to `CrosswordPuzzle` (below `wordAt`):

```dart
  /// The grid position of the clue cell whose arrow starts the word with
  /// [wordId], or null if no clue points at it. Grids are small, so a linear
  /// scan at word-activation time is fine.
  (int, int)? cluePositionOf(String wordId) {
    for (final entry in cells.entries) {
      final cell = entry.value;
      if (cell is ClueCell && cell.arrows.any((a) => a.wordId == wordId)) {
        return entry.key;
      }
    }
    return null;
  }
```

- [x] **Step 4: Run to verify pass**

Run: `cd packages/crossword_core && flutter test`
Expected: ALL PASS.

- [x] **Step 5: Commit**

```bash
git add packages/crossword_core
git commit -m "feat(core): look up a word's clue cell via cluePositionOf"
```

---

### Task 2: `CrosswordState` — new fields, copy constructor, event states

**Files:**
- Modify: `packages/crossword_ui/lib/gameplay/presentation/crossword_screen/cubit/crossword_state.dart` (full rewrite below)
- Test (create): `packages/crossword_ui/test/gameplay/presentation/crossword_screen/cubit/crossword_state_test.dart`

- [x] **Step 1: Write the failing tests** — create the test file:

```dart
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
```

- [x] **Step 2: Run to verify failure**

Run: `cd packages/crossword_ui && flutter test test/gameplay/presentation/crossword_screen/cubit/crossword_state_test.dart`
Expected: FAIL — new members don't exist.

- [x] **Step 3: Implement** — replace `crossword_state.dart` entirely:

```dart
import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';

import 'package:crossword_core/crossword_core.dart';

import '../../../../settings/domain/entities/app_font.dart';

class CrosswordState extends Equatable {
  final CrosswordPuzzle puzzle;
  final Map<(int, int), String> userInputs;
  final (int, int)? selectedCell;

  /// Id of the word the player is currently filling. Navigation follows this
  /// word's ordered cell path, which is what lets a bent/redirected word be
  /// typed straight through its turn.
  final String? activeWordId;
  final Direction currentDirection;
  final Set<(int, int)> highlightedCells;

  /// Clue cell of the active word, highlighted so the player can see which
  /// clue (and direction) they are filling.
  final (int, int)? activeClueCell;

  /// Cells marked wrong by a check action or autocheck. Editing a cell
  /// removes its mark.
  final Set<(int, int)> incorrectCells;

  /// Cells filled via reveal. They render muted and can no longer be edited.
  final Set<(int, int)> revealedCells;

  /// True when every fillable cell holds its solution letter.
  final bool isSolved;

  /// Word that most recently verified fully correct (check, autocheck, or
  /// reveal) plus a token bumped per confirmation; together they key the
  /// one-shot confirmation flash in the grid.
  final String? confirmedWordId;
  final int confirmedWordToken;

  final AppFont font;

  const CrosswordState({
    required this.puzzle,
    this.userInputs = const <(int, int), String>{},
    this.selectedCell,
    this.activeWordId,
    this.currentDirection = Direction.right,
    this.highlightedCells = const <(int, int)>{},
    this.activeClueCell,
    this.incorrectCells = const <(int, int)>{},
    this.revealedCells = const <(int, int)>{},
    this.isSolved = false,
    this.confirmedWordId,
    this.confirmedWordToken = 0,
    this.font = AppFont.defaultFont,
  });

  CrosswordState.copy(CrosswordState state)
      : puzzle = state.puzzle,
        userInputs = state.userInputs,
        selectedCell = state.selectedCell,
        activeWordId = state.activeWordId,
        currentDirection = state.currentDirection,
        highlightedCells = state.highlightedCells,
        activeClueCell = state.activeClueCell,
        incorrectCells = state.incorrectCells,
        revealedCells = state.revealedCells,
        isSolved = state.isSolved,
        confirmedWordId = state.confirmedWordId,
        confirmedWordToken = state.confirmedWordToken,
        font = state.font;

  @override
  List<Object?> get props => [
        puzzle,
        userInputs,
        selectedCell,
        activeWordId,
        currentDirection,
        highlightedCells,
        activeClueCell,
        incorrectCells,
        revealedCells,
        isSolved,
        confirmedWordId,
        confirmedWordToken,
        font,
      ];

  CrosswordState copyWith({
    Map<(int, int), String>? userInputs,
    (int, int)? selectedCell,
    String? activeWordId,
    Direction? currentDirection,
    Set<(int, int)>? highlightedCells,
    Set<(int, int)>? incorrectCells,
    Set<(int, int)>? revealedCells,
    bool? isSolved,
    AppFont? font,
  }) {
    return CrosswordState(
      puzzle: puzzle,
      userInputs: userInputs ?? this.userInputs,
      selectedCell: selectedCell ?? this.selectedCell,
      activeWordId: activeWordId ?? this.activeWordId,
      currentDirection: currentDirection ?? this.currentDirection,
      highlightedCells: highlightedCells ?? this.highlightedCells,
      activeClueCell: activeClueCell,
      incorrectCells: incorrectCells ?? this.incorrectCells,
      revealedCells: revealedCells ?? this.revealedCells,
      isSolved: isSolved ?? this.isSolved,
      confirmedWordId: confirmedWordId,
      confirmedWordToken: confirmedWordToken,
      font: font ?? this.font,
    );
  }

  /// Activate [wordId] with its full selection context in one transition.
  /// Separate from [copyWith] because [activeClueCell] is nullable (a word
  /// may have no clue cell) and the project avoids sentinel-based copyWith.
  CrosswordState withActiveWord({
    required String wordId,
    required (int, int) selectedCell,
    required Direction direction,
    required Set<(int, int)> highlightedCells,
    required (int, int)? clueCell,
    Map<(int, int), String>? userInputs,
  }) {
    return CrosswordState(
      puzzle: puzzle,
      userInputs: userInputs ?? this.userInputs,
      selectedCell: selectedCell,
      activeWordId: wordId,
      currentDirection: direction,
      highlightedCells: highlightedCells,
      activeClueCell: clueCell,
      incorrectCells: incorrectCells,
      revealedCells: revealedCells,
      isSolved: isSolved,
      confirmedWordId: confirmedWordId,
      confirmedWordToken: confirmedWordToken,
      font: font,
    );
  }

  /// Select [cell] as a standalone cell that belongs to no word, clearing the
  /// active word (and its clue highlight) so later navigation and typing
  /// don't act on a stale word.
  CrosswordState withLoneCell((int, int) cell) {
    return CrosswordState(
      puzzle: puzzle,
      userInputs: userInputs,
      selectedCell: cell,
      activeWordId: null,
      currentDirection: currentDirection,
      highlightedCells: {cell},
      activeClueCell: null,
      incorrectCells: incorrectCells,
      revealedCells: revealedCells,
      isSolved: isSolved,
      confirmedWordId: confirmedWordId,
      confirmedWordToken: confirmedWordToken,
      font: font,
    );
  }

  /// Record that [wordId] just verified fully correct, bumping the token that
  /// keys the grid's confirmation flash.
  CrosswordState withConfirmedWord(String wordId) {
    return CrosswordState(
      puzzle: puzzle,
      userInputs: userInputs,
      selectedCell: selectedCell,
      activeWordId: activeWordId,
      currentDirection: currentDirection,
      highlightedCells: highlightedCells,
      activeClueCell: activeClueCell,
      incorrectCells: incorrectCells,
      revealedCells: revealedCells,
      isSolved: isSolved,
      confirmedWordId: wordId,
      confirmedWordToken: confirmedWordToken + 1,
      font: font,
    );
  }
}

/// One-shot event: the puzzle was just solved. Listener shows the
/// celebration dialog.
class PuzzleSolved extends CrosswordState {
  final Key key = UniqueKey();

  PuzzleSolved({required CrosswordState state}) : super.copy(state);

  @override
  List<Object?> get props => [...super.props, key];
}

/// One-shot event: the grid just became full but isn't correct. Listener
/// shows a gentle SnackBar nudge.
class PuzzleFilledButIncorrect extends CrosswordState {
  final Key key = UniqueKey();

  PuzzleFilledButIncorrect({required CrosswordState state}) : super.copy(state);

  @override
  List<Object?> get props => [...super.props, key];
}
```

Note `copyWith` carries `activeClueCell`, `confirmedWordId`, and `confirmedWordToken` through unchanged — they are only set via the dedicated `with*` transitions.

- [x] **Step 4: Run to verify pass**

Run: `cd packages/crossword_ui && flutter test`
Expected: ALL PASS (existing engine/cubit tests still green — `_activateWord` still uses `copyWith` until Task 3).

- [x] **Step 5: Commit**

```bash
git add packages/crossword_ui
git commit -m "feat(state): correctness, reveal, solved, clue-cell and event-state support"
```

---

### Task 3: Engine — solved/filled helpers and active clue cell

**Files:**
- Modify: `packages/crossword_ui/lib/gameplay/presentation/crossword_screen/crossword_engine.dart`
- Test: `packages/crossword_ui/test/gameplay/presentation/crossword_screen/crossword_engine_test.dart`

- [x] **Step 1: Write the failing tests** — add a `_seedPuzzle` fixture next to the existing fixtures, and the new test groups inside `main()`:

```dart
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
```

```dart
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
```

- [x] **Step 2: Run to verify failure**

Run: `cd packages/crossword_ui && flutter test test/gameplay/presentation/crossword_screen/crossword_engine_test.dart`
Expected: FAIL — `computeSolved`/`isFilled` undefined, `activeClueCell` null.

- [x] **Step 3: Implement** — in `crossword_engine.dart`:

Replace `_activateWord` with:

```dart
  /// Make [word] the active word and select [cell] within it, highlighting the
  /// whole word (including its clue cell) and pinning the direction to the
  /// word's local axis there. Pass [userInputs] to fold a just-typed letter
  /// into the same result.
  CrosswordState _activateWord(
    CrosswordState state,
    Word word,
    (int, int) cell, {
    Map<(int, int), String>? userInputs,
  }) {
    final index = word.cells.indexOf(cell);
    return state.withActiveWord(
      wordId: word.id,
      selectedCell: cell,
      direction: word.axisAt(index < 0 ? 0 : index),
      highlightedCells: word.cells.toSet(),
      clueCell: state.puzzle.cluePositionOf(word.id),
      userInputs: userInputs,
    );
  }
```

Add these public/private helpers (e.g. after `moveSelection`):

```dart
  /// Whether every fillable cell has input — right or wrong.
  bool isFilled(CrosswordState state) {
    for (final entry in state.puzzle.cells.entries) {
      final cell = entry.value;
      if (cell is AnswerCell &&
          !cell.isSeed &&
          !state.userInputs.containsKey(entry.key)) {
        return false;
      }
    }
    return true;
  }

  /// Whether [inputs] solve the puzzle: every fillable cell holds its
  /// solution letter. Seeds are given-correct; separators never affect
  /// validation (per the JSON format spec).
  bool computeSolved(CrosswordState state, Map<(int, int), String> inputs) {
    for (final entry in state.puzzle.cells.entries) {
      final cell = entry.value;
      if (cell is AnswerCell && !cell.isSeed && inputs[entry.key] != cell.value) {
        return false;
      }
    }
    return true;
  }

  /// Whether [word] is fully filled with correct letters under [inputs].
  /// (A missing letter never equals the solution, so this implies filled.)
  bool _isWordCorrect(
    CrosswordState state,
    Word word,
    Map<(int, int), String> inputs,
  ) {
    for (final pos in word.cells) {
      final cell = state.puzzle.cells[pos];
      if (cell is AnswerCell && !cell.isSeed && inputs[pos] != cell.value) {
        return false;
      }
    }
    return true;
  }

  /// Whether [cell] can no longer be edited: seeds are given by the puzzle,
  /// revealed cells are given by the player asking for them.
  bool _isLocked(CrosswordState state, (int, int) cell) {
    final c = state.puzzle.cells[cell];
    return (c is AnswerCell && c.isSeed) || state.revealedCells.contains(cell);
  }
```

**Note:** add only `isFilled`, `computeSolved`, and the `_activateWord` replacement in this task. `_isWordCorrect` and `_isLocked` (listed above for reference) are added in Task 4 together with their first callers, so `flutter analyze` stays clean at this commit.

- [x] **Step 4: Run to verify pass**

Run: `cd packages/crossword_ui && flutter test && flutter analyze`
Expected: ALL PASS, no analyzer issues.

- [x] **Step 5: Commit**

```bash
git add packages/crossword_ui
git commit -m "feat(engine): solved/filled detection and active clue-cell tracking"
```

---

### Task 4: Engine — `inputLetter` with autocheck, locks, and confirmation

**Files:**
- Modify: `packages/crossword_ui/lib/gameplay/presentation/crossword_screen/crossword_engine.dart`
- Test: `packages/crossword_ui/test/gameplay/presentation/crossword_screen/crossword_engine_test.dart`

- [x] **Step 1: Write the failing tests** — add inside `main()`:

```dart
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
```

- [x] **Step 2: Run to verify failure**

Run: `cd packages/crossword_ui && flutter test test/gameplay/presentation/crossword_screen/crossword_engine_test.dart`
Expected: FAIL — `autocheck` parameter doesn't exist; solved/marks not computed.

- [x] **Step 3: Implement** — in `crossword_engine.dart`, add `_isWordCorrect` and `_isLocked` from Task 3's listing (if not already present), extract the advance logic, and replace `inputLetter`:

```dart
  /// Record [letter] at the selected cell and advance: to the next cell of the
  /// active word, back to a skipped gap, or on to the next unfinished word.
  /// Seeds and revealed cells are locked — typing on them advances without
  /// writing. With [autocheck], a wrong letter is marked immediately and a
  /// word completed correctly is confirmed (driving the grid flash).
  CrosswordState inputLetter(
    CrosswordState state,
    String letter, {
    bool autocheck = false,
  }) {
    final sel = state.selectedCell;
    if (sel == null) return state;

    var inputs = state.userInputs;
    var incorrect = state.incorrectCells;
    if (!_isLocked(state, sel)) {
      inputs = Map<(int, int), String>.from(inputs)..[sel] = letter;
      incorrect = Set<(int, int)>.from(incorrect)..remove(sel);
      final cell = state.puzzle.cells[sel];
      if (autocheck && cell is AnswerCell && cell.value != letter) {
        incorrect.add(sel);
      }
    }

    var next = _advanceAfterInput(state, sel, inputs).copyWith(
      incorrectCells: incorrect,
      isSolved: computeSolved(state, inputs),
    );

    if (autocheck) {
      final word = state.puzzle.wordById(state.activeWordId ?? '');
      if (word != null && _isWordCorrect(state, word, inputs)) {
        next = next.withConfirmedWord(word.id);
      }
    }
    return next;
  }

  /// Advance after [sel] was acted on with [inputs] now in effect: step within
  /// the active word, jump back to a skipped gap, or move on to the next
  /// unfinished word — folding [inputs] into every branch.
  CrosswordState _advanceAfterInput(
    CrosswordState state,
    (int, int) sel,
    Map<(int, int), String> inputs,
  ) {
    final next = _step(state, sel, 1);
    if (next != null) {
      return state.copyWith(
        userInputs: inputs,
        selectedCell: next,
        currentDirection: _axisAt(state, next),
      );
    }

    final activeWord = state.puzzle.wordById(state.activeWordId ?? '');
    if (activeWord == null) {
      return state.copyWith(userInputs: inputs);
    }

    final gap = _firstEmptyCell(state, activeWord, inputs);
    if (gap != null) {
      return state.copyWith(
        userInputs: inputs,
        selectedCell: gap,
        currentDirection: _axisAt(state, gap),
      );
    }

    final nextWord = _nextUnfinishedWord(state, inputs);
    if (nextWord == null) {
      return state.copyWith(userInputs: inputs);
    }

    final target =
        _firstEmptyCell(state, nextWord, inputs) ?? nextWord.cells.first;
    return _activateWord(state, nextWord, target, userInputs: inputs);
  }
```

- [x] **Step 4: Run to verify pass**

Run: `cd packages/crossword_ui && flutter test`
Expected: ALL PASS (existing inputLetter tests unchanged in behavior).

- [x] **Step 5: Commit**

```bash
git add packages/crossword_ui
git commit -m "feat(engine): autocheck, locked cells, and solved detection on input"
```

---

### Task 5: Engine — `backspace` with locks and mark-clearing

**Files:**
- Modify: `packages/crossword_ui/lib/gameplay/presentation/crossword_screen/crossword_engine.dart`
- Test: `packages/crossword_ui/test/gameplay/presentation/crossword_screen/crossword_engine_test.dart`

- [x] **Step 1: Write the failing tests** — add to the existing `backspace` group:

```dart
    test('clearing a letter also clears its incorrect mark', () {
      final state = CrosswordState(
        puzzle: _puzzle(),
        activeWordId: 'across',
        selectedCell: (0, 1),
        userInputs: const {(0, 1): 'X'},
        incorrectCells: const {(0, 1)},
      );
      final next = engine.backspace(state);

      expect(next.userInputs.containsKey((0, 1)), isFalse);
      expect(next.incorrectCells, isEmpty);
    });

    test('steps over a revealed cell without clearing it', () {
      final state = CrosswordState(
        puzzle: _puzzle(),
        activeWordId: 'across',
        selectedCell: (0, 2),
        userInputs: const {(0, 1): 'A'},
        revealedCells: const {(0, 1)},
      );
      final next = engine.backspace(state);

      expect(next.selectedCell, (0, 1));
      expect(next.userInputs[(0, 1)], 'A');
    });

    test('unsolves the puzzle when a correct letter is removed', () {
      final solved = CrosswordState(
        puzzle: _puzzle(),
        activeWordId: 'across',
        selectedCell: (1, 3),
        userInputs: const {(0, 1): 'A', (0, 2): 'B', (0, 3): 'C', (1, 3): 'D'},
        isSolved: true,
      );

      expect(engine.backspace(solved).isSolved, isFalse);
    });
```

- [x] **Step 2: Run to verify failure**

Run: `cd packages/crossword_ui && flutter test test/gameplay/presentation/crossword_screen/crossword_engine_test.dart`
Expected: FAIL on the new tests.

- [x] **Step 3: Implement** — replace `backspace`:

```dart
  /// Delete the selected cell's letter (and its incorrect mark), or step back
  /// and delete the previous cell's letter when the selected cell is already
  /// empty. Seeds and revealed cells are never cleared — stepping back onto
  /// one just moves the selection.
  CrosswordState backspace(CrosswordState state) {
    final sel = state.selectedCell;
    if (sel == null) return state;

    if (!_isLocked(state, sel) && state.userInputs.containsKey(sel)) {
      return _clearCell(state, sel);
    }

    final prev = _step(state, sel, -1);
    if (prev == null) return state;
    if (_isLocked(state, prev)) {
      return state.copyWith(
        selectedCell: prev,
        currentDirection: _axisAt(state, prev),
      );
    }
    return _clearCell(state, prev).copyWith(
      selectedCell: prev,
      currentDirection: _axisAt(state, prev),
    );
  }

  /// Remove [cell]'s input and incorrect mark, recomputing solved state.
  CrosswordState _clearCell(CrosswordState state, (int, int) cell) {
    final inputs = Map<(int, int), String>.from(state.userInputs)..remove(cell);
    final incorrect = Set<(int, int)>.from(state.incorrectCells)..remove(cell);
    return state.copyWith(
      userInputs: inputs,
      incorrectCells: incorrect,
      isSolved: computeSolved(state, inputs),
    );
  }
```

- [x] **Step 4: Run to verify pass**

Run: `cd packages/crossword_ui && flutter test`
Expected: ALL PASS (the existing "at the first empty cell of a word it is a no-op" test still passes: `_step` returns null there).

- [x] **Step 5: Commit**

```bash
git add packages/crossword_ui
git commit -m "feat(engine): backspace respects locked cells and clears marks"
```

---

### Task 6: Engine — `checkWord` / `checkPuzzle`

**Files:**
- Modify: `packages/crossword_ui/lib/gameplay/presentation/crossword_screen/crossword_engine.dart`
- Test: `packages/crossword_ui/test/gameplay/presentation/crossword_screen/crossword_engine_test.dart`

- [x] **Step 1: Write the failing tests:**

```dart
  group('check actions', () {
    test('checkWord marks only the active word\'s wrong letters', () {
      final state = CrosswordState(
        puzzle: _twoWordPuzzle(),
        activeWordId: 'w1',
        selectedCell: (0, 1),
        userInputs: const {(0, 1): 'X', (0, 2): 'B', (1, 1): 'X'},
        highlightedCells: const {(0, 1), (0, 2)},
      );
      final next = engine.checkWord(state);

      // (1,1) is wrong too, but belongs to w2 — untouched. Empty cells stay
      // unmarked.
      expect(next.incorrectCells, {(0, 1)});
    });

    test('checkPuzzle marks wrong letters everywhere, skipping empties', () {
      final state = CrosswordState(
        puzzle: _twoWordPuzzle(),
        userInputs: const {(0, 1): 'X', (1, 1): 'X', (1, 2): 'D'},
      );
      final next = engine.checkPuzzle(state);

      expect(next.incorrectCells, {(0, 1), (1, 1)});
    });

    test('a correct letter loses a stale mark on re-check', () {
      final state = CrosswordState(
        puzzle: _twoWordPuzzle(),
        userInputs: const {(0, 1): 'A'},
        incorrectCells: const {(0, 1)},
      );

      expect(engine.checkPuzzle(state).incorrectCells, isEmpty);
    });

    test('checkWord on a fully correct word confirms it for the flash', () {
      final state = CrosswordState(
        puzzle: _twoWordPuzzle(),
        activeWordId: 'w1',
        selectedCell: (0, 2),
        userInputs: const {(0, 1): 'A', (0, 2): 'B'},
        highlightedCells: const {(0, 1), (0, 2)},
      );
      final next = engine.checkWord(state);

      expect(next.incorrectCells, isEmpty);
      expect(next.confirmedWordId, 'w1');
      expect(next.confirmedWordToken, 1);
    });

    test('checkWord without an active word is a no-op', () {
      final state = CrosswordState(puzzle: _twoWordPuzzle());

      expect(engine.checkWord(state), state);
    });
  });
```

- [x] **Step 2: Run to verify failure**

Run: `cd packages/crossword_ui && flutter test test/gameplay/presentation/crossword_screen/crossword_engine_test.dart`
Expected: FAIL — methods undefined.

- [x] **Step 3: Implement:**

```dart
  /// Mark the active word's wrong letters. Correct and empty cells are left
  /// (or become) unmarked; a fully correct word is confirmed for the flash.
  CrosswordState checkWord(CrosswordState state) {
    final word = state.puzzle.wordById(state.activeWordId ?? '');
    if (word == null) return state;
    return _checkCells(state, word.cells);
  }

  /// Mark wrong letters across the whole grid.
  CrosswordState checkPuzzle(CrosswordState state) {
    return _checkCells(state, state.puzzle.cells.keys);
  }

  /// Re-mark [cells]: filled wrong letters join `incorrectCells`, everything
  /// else leaves it. Confirms the active word when it stands fully correct.
  CrosswordState _checkCells(CrosswordState state, Iterable<(int, int)> cells) {
    final incorrect = Set<(int, int)>.from(state.incorrectCells);
    for (final pos in cells) {
      final cell = state.puzzle.cells[pos];
      if (cell is! AnswerCell || cell.isSeed) continue;
      final input = state.userInputs[pos];
      if (input != null && input != cell.value) {
        incorrect.add(pos);
      } else {
        incorrect.remove(pos);
      }
    }

    var next = state.copyWith(incorrectCells: incorrect);
    final word = state.puzzle.wordById(state.activeWordId ?? '');
    if (word != null && _isWordCorrect(state, word, state.userInputs)) {
      next = next.withConfirmedWord(word.id);
    }
    return next;
  }
```

- [x] **Step 4: Run to verify pass**

Run: `cd packages/crossword_ui && flutter test`
Expected: ALL PASS.

- [x] **Step 5: Commit**

```bash
git add packages/crossword_ui
git commit -m "feat(engine): on-demand word and puzzle checking"
```

---

### Task 7: Engine — `revealCell` / `revealWord`

**Files:**
- Modify: `packages/crossword_ui/lib/gameplay/presentation/crossword_screen/crossword_engine.dart`
- Test: `packages/crossword_ui/test/gameplay/presentation/crossword_screen/crossword_engine_test.dart`

- [x] **Step 1: Write the failing tests:**

```dart
  group('reveal actions', () {
    test('revealCell fills the solution, locks the cell, and advances', () {
      final active = engine.selectCell(CrosswordState(puzzle: _puzzle()), 0, 0);
      final next = engine.revealCell(active);

      expect(next.userInputs[(0, 1)], 'A');
      expect(next.revealedCells, {(0, 1)});
      expect(next.selectedCell, (0, 2));
    });

    test('revealCell replaces a wrong letter and clears its mark', () {
      final state = CrosswordState(
        puzzle: _puzzle(),
        activeWordId: 'across',
        selectedCell: (0, 1),
        userInputs: const {(0, 1): 'X'},
        incorrectCells: const {(0, 1)},
        highlightedCells: const {(0, 1), (0, 2), (0, 3), (1, 3)},
      );
      final next = engine.revealCell(state);

      expect(next.userInputs[(0, 1)], 'A');
      expect(next.incorrectCells, isEmpty);
    });

    test('revealCell is a no-op on seeds and without a selection', () {
      final noSelection = CrosswordState(puzzle: _puzzle());
      expect(engine.revealCell(noSelection), noSelection);

      final onSeed = CrosswordState(
        puzzle: _seedPuzzle(),
        activeWordId: 'w',
        selectedCell: (0, 1),
        highlightedCells: const {(0, 1), (0, 2)},
      );
      expect(engine.revealCell(onSeed), onSeed);
    });

    test('revealWord fills and locks the word, confirms it, and moves on', () {
      final state = CrosswordState(
        puzzle: _twoWordPuzzle(),
        activeWordId: 'w1',
        selectedCell: (0, 1),
        highlightedCells: const {(0, 1), (0, 2)},
      );
      final next = engine.revealWord(state);

      expect(next.userInputs[(0, 1)], 'A');
      expect(next.userInputs[(0, 2)], 'B');
      expect(next.revealedCells, {(0, 1), (0, 2)});
      expect(next.confirmedWordId, 'w1');
      expect(next.activeWordId, 'w2');
      expect(next.selectedCell, (1, 1));
    });

    test('revealing the last word solves the puzzle', () {
      final active = engine.selectCell(CrosswordState(puzzle: _puzzle()), 0, 0);

      expect(engine.revealWord(active).isSolved, isTrue);
    });
  });
```

- [x] **Step 2: Run to verify failure**

Run: `cd packages/crossword_ui && flutter test test/gameplay/presentation/crossword_screen/crossword_engine_test.dart`
Expected: FAIL — methods undefined.

- [x] **Step 3: Implement:**

```dart
  /// Fill the selected cell with its solution letter and lock it, advancing
  /// as if the letter had been typed.
  CrosswordState revealCell(CrosswordState state) {
    final sel = state.selectedCell;
    if (sel == null) return state;
    final cell = state.puzzle.cells[sel];
    if (cell is! AnswerCell || _isLocked(state, sel)) return state;

    final inputs = Map<(int, int), String>.from(state.userInputs)
      ..[sel] = cell.value;
    final revealed = Set<(int, int)>.from(state.revealedCells)..add(sel);
    final incorrect = Set<(int, int)>.from(state.incorrectCells)..remove(sel);
    return _advanceAfterInput(state, sel, inputs).copyWith(
      revealedCells: revealed,
      incorrectCells: incorrect,
      isSolved: computeSolved(state, inputs),
    );
  }

  /// Fill and lock the whole active word, confirm it for the flash, and move
  /// on to the next unfinished word.
  CrosswordState revealWord(CrosswordState state) {
    final word = state.puzzle.wordById(state.activeWordId ?? '');
    if (word == null) return state;

    final inputs = Map<(int, int), String>.from(state.userInputs);
    final revealed = Set<(int, int)>.from(state.revealedCells);
    final incorrect = Set<(int, int)>.from(state.incorrectCells);
    for (final pos in word.cells) {
      final cell = state.puzzle.cells[pos];
      if (cell is! AnswerCell || cell.isSeed) continue;
      inputs[pos] = cell.value;
      revealed.add(pos);
      incorrect.remove(pos);
    }

    var next = state
        .copyWith(
          userInputs: inputs,
          revealedCells: revealed,
          incorrectCells: incorrect,
          isSolved: computeSolved(state, inputs),
        )
        .withConfirmedWord(word.id);

    final nextWord = _nextUnfinishedWord(next, inputs);
    if (nextWord == null) return next;
    final target =
        _firstEmptyCell(next, nextWord, inputs) ?? nextWord.cells.first;
    return _activateWord(next, nextWord, target);
  }
```

- [x] **Step 4: Run to verify pass**

Run: `cd packages/crossword_ui && flutter test`
Expected: ALL PASS.

- [x] **Step 5: Commit**

```bash
git add packages/crossword_ui
git commit -m "feat(engine): reveal letter and reveal word with locking"
```

---

### Task 8: Engine — `clearWord` / `restart`

**Files:**
- Modify: `packages/crossword_ui/lib/gameplay/presentation/crossword_screen/crossword_engine.dart`
- Test: `packages/crossword_ui/test/gameplay/presentation/crossword_screen/crossword_engine_test.dart`

- [x] **Step 1: Write the failing tests:**

```dart
  group('clearWord & restart', () {
    test('clearWord clears letters and marks but keeps revealed letters', () {
      final state = CrosswordState(
        puzzle: _puzzle(),
        activeWordId: 'across',
        selectedCell: (1, 3),
        userInputs: const {(0, 1): 'A', (0, 2): 'X', (0, 3): 'C'},
        incorrectCells: const {(0, 2)},
        revealedCells: const {(0, 1)},
        highlightedCells: const {(0, 1), (0, 2), (0, 3), (1, 3)},
      );
      final next = engine.clearWord(state);

      expect(next.userInputs, {(0, 1): 'A'});
      expect(next.incorrectCells, isEmpty);
      expect(next.revealedCells, {(0, 1)});
      // Selection parks on the word's first editable gap.
      expect(next.selectedCell, (0, 2));
    });

    test('clearWord without an active word is a no-op', () {
      final state = CrosswordState(puzzle: _puzzle());

      expect(engine.clearWord(state), state);
    });

    test('restart returns a pristine state, keeping puzzle and font', () {
      final messy = CrosswordState(
        puzzle: _puzzle(),
        activeWordId: 'across',
        selectedCell: (0, 1),
        userInputs: const {(0, 1): 'A'},
        incorrectCells: const {(0, 1)},
        revealedCells: const {(0, 2)},
        isSolved: false,
        font: AppFont.values.last,
      );
      final fresh = engine.restart(messy);

      expect(fresh.userInputs, isEmpty);
      expect(fresh.incorrectCells, isEmpty);
      expect(fresh.revealedCells, isEmpty);
      expect(fresh.selectedCell, isNull);
      expect(fresh.activeWordId, isNull);
      expect(fresh.font, AppFont.values.last);
      expect(fresh.puzzle, messy.puzzle);
    });
  });
```

- [x] **Step 2: Run to verify failure**

Run: `cd packages/crossword_ui && flutter test test/gameplay/presentation/crossword_screen/crossword_engine_test.dart`
Expected: FAIL — methods undefined.

- [x] **Step 3: Implement:**

```dart
  /// Clear the active word's letters and marks, leaving seeds and revealed
  /// letters in place, and park the selection on the word's first editable
  /// gap.
  CrosswordState clearWord(CrosswordState state) {
    final word = state.puzzle.wordById(state.activeWordId ?? '');
    if (word == null) return state;

    final inputs = Map<(int, int), String>.from(state.userInputs);
    final incorrect = Set<(int, int)>.from(state.incorrectCells);
    for (final pos in word.cells) {
      if (_isLocked(state, pos)) continue;
      inputs.remove(pos);
      incorrect.remove(pos);
    }

    final next = state.copyWith(
      userInputs: inputs,
      incorrectCells: incorrect,
      isSolved: computeSolved(state, inputs),
    );
    final target = _firstEmptyCell(next, word, inputs) ?? word.cells.first;
    return _activateWord(next, word, target);
  }

  /// Wipe all inputs, marks, and selection back to a pristine puzzle. The
  /// font (a UI concern carried through engine transitions) is preserved.
  CrosswordState restart(CrosswordState state) {
    return CrosswordState(puzzle: state.puzzle, font: state.font);
  }
```

- [x] **Step 4: Run to verify pass**

Run: `cd packages/crossword_ui && flutter test`
Expected: ALL PASS.

- [x] **Step 5: Commit**

```bash
git add packages/crossword_ui
git commit -m "feat(engine): clear word and restart"
```

---

### Task 9: `ProgressService`

**Files:**
- Create: `packages/crossword_ui/lib/gameplay/domain/services/progress_service.dart`
- Modify: `packages/crossword_ui/lib/crossword_ui.dart` (add export)
- Test (create): `packages/crossword_ui/test/gameplay/domain/services/progress_service_test.dart`

- [x] **Step 1: Write the failing tests:**

```dart
import 'package:crossword_ui/crossword_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProgressService> service([Map<String, Object> stored = const {}]) async {
    SharedPreferences.setMockInitialValues(stored);
    return ProgressService(prefs: await SharedPreferences.getInstance());
  }

  test('read returns null when nothing is stored', () async {
    expect((await service()).read('t'), isNull);
  });

  test('save/read round-trips inputs and revealed cells', () async {
    final sut = await service();
    const snapshot = ProgressSnapshot(
      userInputs: {(0, 1): 'A', (2, 3): 'Ö'},
      revealedCells: {(2, 3)},
    );

    await sut.save('t', snapshot);

    expect(sut.read('t'), snapshot);
  });

  test('saving an empty snapshot removes the stored entry', () async {
    final sut = await service();
    await sut.save('t', const ProgressSnapshot(userInputs: {(0, 0): 'A'}));

    await sut.save('t', const ProgressSnapshot());

    expect(sut.read('t'), isNull);
  });

  test('clear removes the stored entry', () async {
    final sut = await service();
    await sut.save('t', const ProgressSnapshot(userInputs: {(0, 0): 'A'}));

    await sut.clear('t');

    expect(sut.read('t'), isNull);
  });

  test('corrupt stored data falls back to null', () async {
    final sut = await service({'progress_t': 'not json'});

    expect(sut.read('t'), isNull);
  });
}
```

- [x] **Step 2: Run to verify failure**

Run: `cd packages/crossword_ui && flutter test test/gameplay/domain/services/progress_service_test.dart`
Expected: FAIL — `ProgressService` doesn't exist.

- [x] **Step 3: Implement** — create `progress_service.dart`:

```dart
import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A player's saved fill state for one puzzle.
class ProgressSnapshot extends Equatable {
  final Map<(int, int), String> userInputs;
  final Set<(int, int)> revealedCells;

  const ProgressSnapshot({
    this.userInputs = const <(int, int), String>{},
    this.revealedCells = const <(int, int)>{},
  });

  bool get isEmpty => userInputs.isEmpty && revealedCells.isEmpty;

  @override
  List<Object?> get props => [userInputs, revealedCells];
}

/// Persists puzzle fill progress locally so the grid survives an app restart.
/// Keyed per puzzle; the format has no stable puzzle id yet, so callers pass
/// the title while puzzles are bundled. Only cubits should touch this service.
class ProgressService {
  static const String _prefix = 'progress_';

  final SharedPreferences _prefs;

  ProgressService({required SharedPreferences prefs}) : _prefs = prefs;

  /// The saved snapshot for [puzzleKey], or null when absent or unreadable
  /// (corrupt data falls back to a clean grid rather than crashing).
  ProgressSnapshot? read(String puzzleKey) {
    final raw = _prefs.getString('$_prefix$puzzleKey');
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final inputs = <(int, int), String>{
        for (final entry in (json['inputs'] as Map<String, dynamic>).entries)
          _parsePos(entry.key): entry.value as String,
      };
      final revealed = <(int, int)>{
        for (final pos in json['revealed'] as List<dynamic>)
          _parsePos(pos as String),
      };
      return ProgressSnapshot(userInputs: inputs, revealedCells: revealed);
    } catch (_) {
      return null;
    }
  }

  /// Persist [snapshot]. An empty snapshot removes the entry instead. A
  /// failed write is non-fatal — the in-memory state still applies.
  Future<void> save(String puzzleKey, ProgressSnapshot snapshot) async {
    if (snapshot.isEmpty) return clear(puzzleKey);
    try {
      await _prefs.setString(
        '$_prefix$puzzleKey',
        jsonEncode({
          'inputs': {
            for (final entry in snapshot.userInputs.entries)
              _keyOf(entry.key): entry.value,
          },
          'revealed': [
            for (final pos in snapshot.revealedCells) _keyOf(pos),
          ],
        }),
      );
    } catch (_) {
      // Persistence failure is non-fatal.
    }
  }

  /// Remove any saved progress for [puzzleKey].
  Future<void> clear(String puzzleKey) async {
    try {
      await _prefs.remove('$_prefix$puzzleKey');
    } catch (_) {
      // Persistence failure is non-fatal.
    }
  }

  static String _keyOf((int, int) pos) => '${pos.$1},${pos.$2}';

  static (int, int) _parsePos(String key) {
    final parts = key.split(',');
    return (int.parse(parts[0]), int.parse(parts[1]));
  }
}
```

Add to `packages/crossword_ui/lib/crossword_ui.dart` (after the font_service export):

```dart
export 'gameplay/domain/services/progress_service.dart';
```

- [x] **Step 4: Run to verify pass**

Run: `cd packages/crossword_ui && flutter test`
Expected: ALL PASS.

- [x] **Step 5: Commit**

```bash
git add packages/crossword_ui
git commit -m "feat: ProgressService persists puzzle fill state locally"
```

---

### Task 10: `GameplaySettingsService`

**Files:**
- Create: `packages/crossword_ui/lib/settings/domain/services/gameplay_settings_service.dart`
- Modify: `packages/crossword_ui/lib/crossword_ui.dart` (add export)
- Test (create): `packages/crossword_ui/test/settings/domain/services/gameplay_settings_service_test.dart`

- [x] **Step 1: Write the failing tests:**

```dart
import 'package:crossword_ui/crossword_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('autocheck defaults to off', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    expect(GameplaySettingsService(prefs: prefs).autocheck.value, isFalse);
  });

  test('setAutocheck updates the notifier and persists the value', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final service = GameplaySettingsService(prefs: prefs);

    await service.setAutocheck(true);

    expect(service.autocheck.value, isTrue);
    expect(prefs.getBool('autocheck_enabled'), isTrue);
  });

  test('a new service restores the stored setting (restart)', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await GameplaySettingsService(prefs: prefs).setAutocheck(true);

    expect(GameplaySettingsService(prefs: prefs).autocheck.value, isTrue);
  });
}
```

- [x] **Step 2: Run to verify failure**

Run: `cd packages/crossword_ui && flutter test test/settings/domain/services/gameplay_settings_service_test.dart`
Expected: FAIL — class doesn't exist.

- [x] **Step 3: Implement** — create `gameplay_settings_service.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds gameplay preferences as cross-feature shared state and persists them
/// locally. Only cubits should touch this service.
class GameplaySettingsService {
  static const String _autocheckKey = 'autocheck_enabled';

  final SharedPreferences _prefs;

  /// Whether wrong letters are marked the moment they are typed.
  final ValueNotifier<bool> autocheck;

  GameplaySettingsService({
    required SharedPreferences prefs,
    bool? initial,
  })  : _prefs = prefs,
        autocheck = ValueNotifier(initial ?? readStored(prefs));

  /// Reads the persisted setting, defaulting to off (unassisted solving).
  static bool readStored(SharedPreferences prefs) {
    return prefs.getBool(_autocheckKey) ?? false;
  }

  /// Sets autocheck, notifies listeners, and persists the choice. A failed
  /// write is non-fatal — the in-memory value still applies this session.
  Future<void> setAutocheck(bool enabled) async {
    autocheck.value = enabled;
    try {
      await _prefs.setBool(_autocheckKey, enabled);
    } catch (_) {
      // Persistence failure is non-fatal.
    }
  }

  void dispose() => autocheck.dispose();
}
```

Add to `crossword_ui.dart` (next to the font_service export):

```dart
export 'settings/domain/services/gameplay_settings_service.dart';
```

- [x] **Step 4: Run to verify pass**

Run: `cd packages/crossword_ui && flutter test`
Expected: ALL PASS.

- [x] **Step 5: Commit**

```bash
git add packages/crossword_ui
git commit -m "feat: GameplaySettingsService with persisted autocheck toggle"
```

---

### Task 11: Cubit orchestration + app/service wiring

This task changes the `CrosswordCubit` constructor, so it also updates every construction site (both screens, both `main.dart`s, and three test harnesses) to keep the workspace green in one commit.

**Files:**
- Modify: `packages/crossword_ui/lib/gameplay/presentation/crossword_screen/cubit/crossword_cubit.dart`
- Modify: `packages/crossword_ui/test/gameplay/presentation/crossword_screen/cubit/crossword_cubit_test.dart`
- Modify: `apps/mobile/lib/crossword/mobile_crossword_screen.dart` (BlocProvider create)
- Modify: `apps/mobile/lib/main.dart`
- Modify: `apps/web/lib/crossword/web_crossword_screen.dart` (BlocProvider create)
- Modify: `apps/web/lib/main.dart`
- Modify: `apps/mobile/test/crossword/mobile_crossword_screen_test.dart`
- Modify: `apps/web/test/web_smoke_test.dart`
- Modify (check): `packages/crossword_ui/test/gameplay/presentation/crossword_screen/mobile_input_present_test.dart` and `mobile_input_absent_test.dart` — update any `CrosswordCubit(...)` constructions the same way.

- [x] **Step 1: Write the failing cubit tests** — in `crossword_cubit_test.dart`, replace the `setUp` block and add a `_buildCubit` helper:

```dart
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
```

Replace the other inline `CrosswordCubit(puzzle: ..., fontService: fontService)` constructions in this file (`overlap`, `lone`) with `buildCubit(_overlapPuzzle())` / `buildCubit(_loneCellPuzzle())`.

Add the new test groups at the end of `main()`:

```dart
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
```

- [x] **Step 2: Run to verify failure**

Run: `cd packages/crossword_ui && flutter test test/gameplay/presentation/crossword_screen/cubit/crossword_cubit_test.dart`
Expected: COMPILE ERROR — constructor has no `settingsService`/`progressService`.

- [x] **Step 3: Implement the cubit** — replace `crossword_cubit.dart`'s imports, constructor, and action/`_apply` sections (the sentinel/IME/`isTouchPlatform`/`_raiseKeyboard`/`resetView` members stay exactly as they are):

```dart
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:crossword_core/crossword_core.dart';

import '../../../../settings/domain/services/font_service.dart';
import '../../../../settings/domain/services/gameplay_settings_service.dart';
import '../../../domain/services/progress_service.dart';
import '../crossword_engine.dart';
import 'crossword_state.dart';
```

```dart
  final FontService _fontService;
  final GameplaySettingsService _settingsService;
  final ProgressService _progressService;
  final CrosswordEngine _engine;

  CrosswordCubit({
    required CrosswordPuzzle puzzle,
    required FontService fontService,
    required GameplaySettingsService settingsService,
    required ProgressService progressService,
    CrosswordEngine engine = const CrosswordEngine(),
  })  : _fontService = fontService,
        _settingsService = settingsService,
        _progressService = progressService,
        _engine = engine,
        super(_restoredState(puzzle, fontService, progressService, engine)) {
    _fontService.selectedFont.addListener(_onFontChanged);
  }

  /// The key progress is stored under. The format has no stable puzzle id
  /// yet, so the title stands in while puzzles are bundled.
  String get _progressKey => state.puzzle.title;

  /// Initial state with any locally saved progress folded back in. A puzzle
  /// restored already-solved sets [CrosswordState.isSolved] without firing
  /// [PuzzleSolved] — events are transition-edged in [_apply].
  static CrosswordState _restoredState(
    CrosswordPuzzle puzzle,
    FontService fontService,
    ProgressService progressService,
    CrosswordEngine engine,
  ) {
    final base = CrosswordState(
      puzzle: puzzle,
      font: fontService.selectedFont.value,
    );
    final snapshot = progressService.read(puzzle.title);
    if (snapshot == null) return base;
    final restored = base.copyWith(
      userInputs: snapshot.userInputs,
      revealedCells: snapshot.revealedCells,
    );
    return restored.copyWith(
      isSolved: engine.computeSolved(restored, restored.userInputs),
    );
  }
```

Replace `onLetterInput` and add the new actions:

```dart
  void onLetterInput(String letter) => _apply(
        _engine.inputLetter(
          state,
          letter,
          autocheck: _settingsService.autocheck.value,
        ),
        raiseKeyboard: false,
        letterHaptic: true,
      );

  void checkWord() => _apply(_engine.checkWord(state), raiseKeyboard: false);

  void checkPuzzle() => _apply(_engine.checkPuzzle(state), raiseKeyboard: false);

  void revealCell() => _apply(_engine.revealCell(state), raiseKeyboard: false);

  void revealWord() => _apply(_engine.revealWord(state), raiseKeyboard: false);

  void clearWord() => _apply(_engine.clearWord(state), raiseKeyboard: false);

  void restartPuzzle() => _apply(_engine.restart(state), raiseKeyboard: false);
```

Replace `_apply` (keep its doc comment, extend it) and add the helpers:

```dart
  /// Emit [next] when it differs from the current state, and — for selection
  /// actions only — raise the soft keyboard. A no-op neither emits nor raises
  /// the keyboard. After emitting, persist changed progress and fire
  /// transition-edged feedback (haptics and one-shot event states).
  void _apply(
    CrosswordState next, {
    required bool raiseKeyboard,
    bool letterHaptic = false,
  }) {
    final prev = state;
    if (next == prev) return;
    emit(next);
    if (raiseKeyboard) _raiseKeyboard();
    _persistProgress(prev, next);
    _feedback(prev, next, letterHaptic: letterHaptic);
  }

  /// Save progress when inputs or revealed letters changed. The engine only
  /// allocates new collections when it mutates them, so identity comparison
  /// is sufficient. An empty snapshot (restart) removes the stored entry.
  void _persistProgress(CrosswordState prev, CrosswordState next) {
    if (identical(next.userInputs, prev.userInputs) &&
        identical(next.revealedCells, prev.revealedCells)) {
      return;
    }
    unawaited(_progressService.save(
      _progressKey,
      ProgressSnapshot(
        userInputs: next.userInputs,
        revealedCells: next.revealedCells,
      ),
    ));
  }

  /// Haptic and one-shot event feedback for state transitions, strongest
  /// signal first. Haptics only fire on touch platforms.
  void _feedback(
    CrosswordState prev,
    CrosswordState next, {
    required bool letterHaptic,
  }) {
    if (next.isSolved && !prev.isSolved) {
      _haptic(HapticFeedback.heavyImpact);
      emit(PuzzleSolved(state: next));
      return;
    }
    if (!next.isSolved && _engine.isFilled(next) && !_engine.isFilled(prev)) {
      _haptic(HapticFeedback.vibrate);
      emit(PuzzleFilledButIncorrect(state: next));
      return;
    }
    if (next.confirmedWordToken != prev.confirmedWordToken) {
      _haptic(HapticFeedback.mediumImpact);
      return;
    }
    if (next.incorrectCells.length > prev.incorrectCells.length) {
      _haptic(HapticFeedback.vibrate);
      return;
    }
    if (letterHaptic) _haptic(HapticFeedback.lightImpact);
  }

  void _haptic(Future<void> Function() effect) {
    if (isTouchPlatform) unawaited(effect());
  }
```

- [x] **Step 4: Wire the apps.** `apps/mobile/lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crossword_core/crossword_core.dart';
import 'package:crossword_ui/crossword_ui.dart';

import 'crossword/mobile_crossword_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final fontService = FontService(prefs: prefs);
  final settingsService = GameplaySettingsService(prefs: prefs);
  final progressService = ProgressService(prefs: prefs);
  final puzzle = await loadBundledPuzzle();
  runApp(CrosswordsApp(
    fontService: fontService,
    settingsService: settingsService,
    progressService: progressService,
    puzzle: puzzle,
  ));
}

class CrosswordsApp extends StatelessWidget {
  final FontService fontService;
  final GameplaySettingsService settingsService;
  final ProgressService progressService;
  final CrosswordPuzzle puzzle;

  const CrosswordsApp({
    required this.fontService,
    required this.settingsService,
    required this.progressService,
    required this.puzzle,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<FontService>.value(value: fontService),
        RepositoryProvider<GameplaySettingsService>.value(
          value: settingsService,
        ),
        RepositoryProvider<ProgressService>.value(value: progressService),
      ],
      child: MaterialApp(
        title: Strings.appTitle,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.brand,
            surface: AppColors.background,
          ),
          scaffoldBackgroundColor: AppColors.background,
          useMaterial3: true,
        ),
        home: MobileCrosswordScreen(puzzle: puzzle),
      ),
    );
  }
}
```

`apps/web/lib/main.dart` — the same change shape: add the two service fields/params to `CrosswordsWebApp`, build them in `main()`, and swap `RepositoryProvider<FontService>.value` for the same three-provider `MultiRepositoryProvider`.

Both screens' `BlocProvider` create:

```dart
      create: (context) => CrosswordCubit(
        puzzle: puzzle,
        fontService: context.read<FontService>(),
        settingsService: context.read<GameplaySettingsService>(),
        progressService: context.read<ProgressService>(),
      ),
```

Test harness updates — `apps/mobile/test/crossword/mobile_crossword_screen_test.dart`:

```dart
  late FontService fontService;
  late GameplaySettingsService settingsService;
  late ProgressService progressService;
  late CrosswordPuzzle puzzle;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    fontService = FontService(prefs: prefs);
    settingsService = GameplaySettingsService(prefs: prefs);
    progressService = ProgressService(prefs: prefs);
    puzzle = await loadBundledPuzzle();
  });

  Widget harness() => MultiRepositoryProvider(
        providers: [
          RepositoryProvider<FontService>.value(value: fontService),
          RepositoryProvider<GameplaySettingsService>.value(
            value: settingsService,
          ),
          RepositoryProvider<ProgressService>.value(value: progressService),
        ],
        child: MaterialApp(home: MobileCrosswordScreen(puzzle: puzzle)),
      );
```

`apps/web/test/web_smoke_test.dart` gets the same `MultiRepositoryProvider` wrapper. In `mobile_input_present_test.dart` / `mobile_input_absent_test.dart`, update any `CrosswordCubit(...)` constructions with the two extra services built from mock prefs (same pattern as the cubit test).

- [x] **Step 5: Run everything to verify pass**

Run: `cd packages/crossword_ui && flutter test && cd ../../apps/mobile && flutter test && cd ../web && flutter test`
Expected: ALL PASS.

- [x] **Step 6: Commit**

```bash
git add packages/crossword_ui apps/mobile apps/web
git commit -m "feat(cubit): check/reveal actions, persistence, autocheck, events, haptics"
```

---

### Task 12: Answer cell visuals — seed letters, inks, pop, pulse

**Files:**
- Modify: `packages/crossword_ui/lib/gameplay/presentation/crossword_screen/widgets/answer_cell_widget.dart` (full rewrite)
- Modify: `packages/crossword_ui/lib/gameplay/presentation/crossword_screen/widgets/crossword_grid.dart` (answer-cell wiring)
- Modify: `packages/crossword_ui/lib/common/data/constants/app_colors.dart` (add `errorInk`)
- Test (create): `packages/crossword_ui/test/gameplay/presentation/crossword_screen/widgets/crossword_grid_test.dart`

- [x] **Step 1: Write the failing tests** — create the grid test file:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crossword_core/crossword_core.dart';
import 'package:crossword_ui/crossword_ui.dart';

/// 1x3 grid: clue, a seed cell with given letter 'Å', and one normal cell
/// whose solution is 'B'.
CrosswordPuzzle _puzzle() {
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
      (0, 1): AnswerCell(value: 'Å', isSeed: true),
      (0, 2): AnswerCell(value: 'B'),
    },
    words: [w],
    seedPositions: {(0, 1)},
    title: 't',
    languageCode: 'sv',
  );
}

void main() {
  late CrosswordCubit cubit;
  late GameplaySettingsService settingsService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    settingsService = GameplaySettingsService(prefs: prefs);
    cubit = CrosswordCubit(
      puzzle: _puzzle(),
      fontService: FontService(prefs: prefs),
      settingsService: settingsService,
      progressService: ProgressService(prefs: prefs),
    );
  });

  tearDown(() => cubit.close());

  Widget harness() => MaterialApp(
        home: BlocProvider.value(
          value: cubit,
          child: Scaffold(
            body: BlocBuilder<CrosswordCubit, CrosswordState>(
              builder: (context, state) =>
                  CrosswordGrid(state: state, cellSize: 48),
            ),
          ),
        ),
      );

  Color? letterColor(WidgetTester tester, String letter) =>
      tester.widget<Text>(find.text(letter)).style?.color;

  testWidgets('seed cells render their given letter', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.text('Å'), findsOneWidget);
  });

  testWidgets('wrong letters render in error ink under autocheck',
      (tester) async {
    await settingsService.setAutocheck(true);
    cubit.selectCell(0, 2);
    cubit.onLetterInput('X');

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(letterColor(tester, 'X'), AppColors.errorInk);
  });

  testWidgets('revealed letters render in muted ink', (tester) async {
    cubit.selectCell(0, 2);
    cubit.revealCell();

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(letterColor(tester, 'B'), AppColors.inkMuted);
  });
}
```

- [x] **Step 2: Run to verify failure**

Run: `cd packages/crossword_ui && flutter test test/gameplay/presentation/crossword_screen/widgets/crossword_grid_test.dart`
Expected: FAIL — `AppColors.errorInk` undefined; seed letter not rendered.

- [x] **Step 3: Implement.** Add to `AppColors` (under "Ink"):

```dart
  /// Ink for letters marked wrong by a check — brick red, like a teacher's pen.
  static const Color errorInk = Color(0xFFB3402F);
```

Replace `answer_cell_widget.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../common/data/constants/app_colors.dart';
import '../../../../common/data/constants/app_text_styles.dart';

class AnswerCellWidget extends StatelessWidget {
  /// The letter to display: the player's input, or a seed's given letter.
  final String? letter;
  final bool isSelected;
  final bool isHighlighted;
  final bool isSeed;

  /// Marked wrong by a check action or autocheck — renders in error ink.
  final bool isIncorrect;

  /// Filled via reveal — renders in muted ink.
  final bool isRevealed;

  /// Non-null while this cell's word was just confirmed correct; a new token
  /// value replays the brief confirmation flash.
  final int? confirmPulseToken;
  final bool hasRightSeparator;
  final bool hasBottomSeparator;
  final double size;
  final VoidCallback onTap;
  final String fontFamily;

  const AnswerCellWidget({
    required this.size,
    required this.onTap,
    required this.fontFamily,
    this.letter,
    this.isSelected = false,
    this.isHighlighted = false,
    this.isSeed = false,
    this.isIncorrect = false,
    this.isRevealed = false,
    this.confirmPulseToken,
    this.hasRightSeparator = false,
    this.hasBottomSeparator = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final fillColor = isSelected
        ? AppColors.selection
        : isHighlighted
            ? AppColors.highlight
            : isSeed
                ? AppColors.seedCell
                : AppColors.paper;
    final inkColor = isIncorrect
        ? AppColors.errorInk
        : isRevealed
            ? AppColors.inkMuted
            : AppColors.ink;

    Widget cell = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: fillColor,
        border: Border(
          top: const BorderSide(color: AppColors.gridLine, width: 0.5),
          left: const BorderSide(color: AppColors.gridLine, width: 0.5),
          right: BorderSide(
            color: hasRightSeparator ? AppColors.separator : AppColors.gridLine,
            width: hasRightSeparator ? 2.0 : 0.5,
          ),
          bottom: BorderSide(
            color:
                hasBottomSeparator ? AppColors.separator : AppColors.gridLine,
            width: hasBottomSeparator ? 2.0 : 0.5,
          ),
        ),
      ),
      alignment: Alignment.center,
      // Keyed by the letter so a newly entered glyph pops in; clearing a cell
      // (letter -> null) swaps without animating.
      child: TweenAnimationBuilder<double>(
        key: ValueKey(letter ?? ''),
        tween: Tween(begin: letter == null ? 1.0 : 0.6, end: 1.0),
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutBack,
        builder: (context, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: Text(
          letter ?? '',
          style: AppTextStyles.answerLetter(size * 0.66, family: fontFamily)
              .copyWith(color: inkColor),
        ),
      ),
    );

    final token = confirmPulseToken;
    if (token != null) {
      // A new token re-keys the builder, replaying a sage wash that fades out.
      cell = TweenAnimationBuilder<double>(
        key: ValueKey('pulse-$token'),
        tween: Tween(begin: 1.0, end: 0.0),
        duration: const Duration(milliseconds: 600),
        builder: (context, strength, child) => Stack(
          fit: StackFit.passthrough,
          children: [
            if (child != null) child,
            Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(
                  color:
                      AppColors.seedCell.withAlpha((strength * 140).round()),
                ),
              ),
            ),
          ],
        ),
        child: cell,
      );
    }

    return GestureDetector(onTap: onTap, child: cell);
  }
}
```

In `crossword_grid.dart`, replace the `AnswerCell()` branch of `_buildCell` and add the pulse helper to the class:

```dart
      AnswerCell() => AnswerCellWidget(
          letter: state.userInputs[(row, col)] ??
              (cell.isSeed ? cell.value : null),
          isSelected: state.selectedCell == (row, col),
          isHighlighted: state.highlightedCells.contains((row, col)),
          isSeed: cell.isSeed,
          isIncorrect: state.incorrectCells.contains((row, col)),
          isRevealed: state.revealedCells.contains((row, col)),
          confirmPulseToken: _pulseTokenFor(row, col),
          hasRightSeparator: edges.contains(Direction.right),
          hasBottomSeparator: edges.contains(Direction.down),
          size: cellSize,
          onTap: () => cubit.selectCell(row, col),
          fontFamily: fontFamily,
        ),
```

```dart
  /// The flash token for cells of the most recently confirmed word; null for
  /// all other cells (and before any confirmation has happened).
  int? _pulseTokenFor(int row, int col) {
    if (state.confirmedWordToken == 0) return null;
    final word = state.puzzle.wordById(state.confirmedWordId ?? '');
    if (word == null || !word.cells.contains((row, col))) return null;
    return state.confirmedWordToken;
  }
```

- [x] **Step 4: Run to verify pass**

Run: `cd packages/crossword_ui && flutter test`
Expected: ALL PASS.

- [x] **Step 5: Commit**

```bash
git add packages/crossword_ui
git commit -m "feat(ui): seed letters, error/revealed inks, letter pop, confirm flash"
```

---

### Task 13: Active clue-cell highlight

**Files:**
- Modify: `packages/crossword_ui/lib/gameplay/presentation/crossword_screen/widgets/hint_cell_widget.dart`
- Modify: `packages/crossword_ui/lib/gameplay/presentation/crossword_screen/widgets/crossword_grid.dart` (`ClueCell()` branch)
- Modify: `packages/crossword_ui/lib/common/data/constants/app_colors.dart` (add `clueCellActive`)
- Test: `packages/crossword_ui/test/gameplay/presentation/crossword_screen/widgets/crossword_grid_test.dart`

- [x] **Step 1: Write the failing test** — add to the grid test file:

```dart
  testWidgets('the active word\'s clue cell is highlighted', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    BoxDecoration hintDecoration() {
      final box = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byType(HintCellWidget),
          matching: find.byType(AnimatedContainer),
        ),
      );
      return box.decoration is BoxDecoration
          ? box.decoration as BoxDecoration
          : const BoxDecoration();
    }

    expect(hintDecoration().color, AppColors.clueCell);

    cubit.selectCell(0, 2);
    await tester.pumpAndSettle();

    expect(hintDecoration().color, AppColors.clueCellActive);
  });
```

- [x] **Step 2: Run to verify failure**

Run: `cd packages/crossword_ui && flutter test test/gameplay/presentation/crossword_screen/widgets/crossword_grid_test.dart`
Expected: FAIL — `clueCellActive` undefined; widget has no active state.

- [x] **Step 3: Implement.** Add to `AppColors` (under "Interaction states"):

```dart
  /// Clue cell of the currently active word — amber-tinted to make the
  /// active direction visible.
  static const Color clueCellActive = Color(0xFFE6D9A8);
```

In `hint_cell_widget.dart`, add the field/param and swap the `Container` for an `AnimatedContainer`:

```dart
  /// Whether this clue starts the currently active word.
  final bool isActive;
```

```dart
  const HintCellWidget({
    required this.cell,
    required this.size,
    required this.onTap,
    required this.fontFamily,
    this.isActive = false,
    super.key,
  });
```

```dart
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isActive ? AppColors.clueCellActive : AppColors.clueCell,
          border: Border.all(color: AppColors.gridLine, width: 0.5),
        ),
```

In `crossword_grid.dart`, the `ClueCell()` branch becomes:

```dart
      ClueCell() => HintCellWidget(
          cell: cell,
          size: cellSize,
          onTap: () => cubit.selectCell(row, col),
          fontFamily: fontFamily,
          isActive: state.activeClueCell == (row, col),
        ),
```

- [x] **Step 4: Run to verify pass**

Run: `cd packages/crossword_ui && flutter test`
Expected: ALL PASS.

- [x] **Step 5: Commit**

```bash
git add packages/crossword_ui
git commit -m "feat(ui): highlight the active word's clue cell"
```

---

### Task 14: Game menu (check / reveal / clear / restart)

**Files:**
- Create: `packages/crossword_ui/lib/gameplay/presentation/crossword_screen/widgets/crossword_menu_button.dart`
- Modify: `packages/crossword_ui/lib/crossword_ui.dart` (add export)
- Modify: `packages/crossword_ui/lib/common/data/constants/strings.dart`
- Modify: `apps/mobile/lib/crossword/mobile_crossword_screen.dart` (app bar action)
- Modify: `apps/web/lib/crossword/web_crossword_screen.dart` (app bar action)
- Test (create): `packages/crossword_ui/test/gameplay/presentation/crossword_screen/widgets/crossword_menu_button_test.dart`

- [x] **Step 1: Write the failing tests:**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crossword_core/crossword_core.dart';
import 'package:crossword_ui/crossword_ui.dart';

CrosswordPuzzle _puzzle() {
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
      (0, 1): AnswerCell(value: 'A'),
      (0, 2): AnswerCell(value: 'B'),
    },
    words: [w],
    title: 't',
    languageCode: 'sv',
  );
}

void main() {
  late CrosswordCubit cubit;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    cubit = CrosswordCubit(
      puzzle: _puzzle(),
      fontService: FontService(prefs: prefs),
      settingsService: GameplaySettingsService(prefs: prefs),
      progressService: ProgressService(prefs: prefs),
    );
  });

  tearDown(() => cubit.close());

  Widget harness() => MaterialApp(
        home: BlocProvider.value(
          value: cubit,
          child: Scaffold(
            appBar: AppBar(actions: const [CrosswordMenuButton()]),
          ),
        ),
      );

  Future<void> openMenuAndTap(WidgetTester tester, String action) async {
    await tester.tap(find.byType(CrosswordMenuButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text(action));
    await tester.pumpAndSettle();
  }

  testWidgets('reveal letter fills the selected cell', (tester) async {
    cubit.selectCell(0, 1);
    await tester.pumpWidget(harness());

    await openMenuAndTap(tester, Strings.revealLetterAction);

    expect(cubit.state.userInputs[(0, 1)], 'A');
    expect(cubit.state.revealedCells, {(0, 1)});
  });

  testWidgets('check word marks wrong letters', (tester) async {
    cubit.selectCell(0, 1);
    cubit.onLetterInput('X');
    await tester.pumpWidget(harness());

    await openMenuAndTap(tester, Strings.checkWordAction);

    expect(cubit.state.incorrectCells, {(0, 1)});
  });

  testWidgets('restart asks for confirmation before wiping', (tester) async {
    cubit.selectCell(0, 1);
    cubit.onLetterInput('A');
    await tester.pumpWidget(harness());

    await openMenuAndTap(tester, Strings.restartAction);
    // Confirmation dialog is showing; cancel keeps the progress.
    await tester.tap(find.text(Strings.cancelAction));
    await tester.pumpAndSettle();
    expect(cubit.state.userInputs, isNotEmpty);

    await openMenuAndTap(tester, Strings.restartAction);
    expect(find.text(Strings.restartConfirmBody), findsOneWidget);
    await tester.tap(find.text(Strings.restartAction).last);
    await tester.pumpAndSettle();
    expect(cubit.state.userInputs, isEmpty);
  });
}
```

- [x] **Step 2: Run to verify failure**

Run: `cd packages/crossword_ui && flutter test test/gameplay/presentation/crossword_screen/widgets/crossword_menu_button_test.dart`
Expected: FAIL — widget and strings don't exist.

- [x] **Step 3: Implement.** Add to `Strings`:

```dart
  /// Tooltip for the in-game actions menu.
  static const String gameMenuTooltip = 'Spelmeny';

  /// Game menu actions.
  static const String checkWordAction = 'Kontrollera ord';
  static const String checkPuzzleAction = 'Kontrollera allt';
  static const String revealLetterAction = 'Visa bokstav';
  static const String revealWordAction = 'Visa ord';
  static const String clearWordAction = 'Rensa ord';
  static const String restartAction = 'Börja om';

  /// Restart confirmation dialog.
  static const String restartConfirmTitle = 'Börja om?';
  static const String restartConfirmBody =
      'All ifylld text rensas. Detta går inte att ångra.';
  static const String cancelAction = 'Avbryt';
```

Create `crossword_menu_button.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../common/data/constants/strings.dart';
import '../cubit/crossword_cubit.dart';

enum _MenuAction {
  checkWord,
  checkPuzzle,
  revealLetter,
  revealWord,
  clearWord,
  restart,
}

/// App-bar menu with the game's check/reveal/clear/restart actions. Expects a
/// [CrosswordCubit] above it in the tree.
class CrosswordMenuButton extends StatelessWidget {
  const CrosswordMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CrosswordCubit>();
    return PopupMenuButton<_MenuAction>(
      tooltip: Strings.gameMenuTooltip,
      icon: const Icon(Icons.more_vert),
      onSelected: (action) {
        switch (action) {
          case _MenuAction.checkWord:
            cubit.checkWord();
          case _MenuAction.checkPuzzle:
            cubit.checkPuzzle();
          case _MenuAction.revealLetter:
            cubit.revealCell();
          case _MenuAction.revealWord:
            cubit.revealWord();
          case _MenuAction.clearWord:
            cubit.clearWord();
          case _MenuAction.restart:
            _confirmRestart(context, cubit);
        }
      },
      itemBuilder: (context) => const <PopupMenuEntry<_MenuAction>>[
        PopupMenuItem(
          value: _MenuAction.checkWord,
          child: Text(Strings.checkWordAction),
        ),
        PopupMenuItem(
          value: _MenuAction.checkPuzzle,
          child: Text(Strings.checkPuzzleAction),
        ),
        PopupMenuDivider(),
        PopupMenuItem(
          value: _MenuAction.revealLetter,
          child: Text(Strings.revealLetterAction),
        ),
        PopupMenuItem(
          value: _MenuAction.revealWord,
          child: Text(Strings.revealWordAction),
        ),
        PopupMenuDivider(),
        PopupMenuItem(
          value: _MenuAction.clearWord,
          child: Text(Strings.clearWordAction),
        ),
        PopupMenuItem(
          value: _MenuAction.restart,
          child: Text(Strings.restartAction),
        ),
      ],
    );
  }

  /// Restart is destructive, so it confirms first. View-local dialog flow,
  /// matching how screens push routes directly from buttons.
  Future<void> _confirmRestart(
    BuildContext context,
    CrosswordCubit cubit,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(Strings.restartConfirmTitle),
        content: const Text(Strings.restartConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(Strings.cancelAction),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(Strings.restartAction),
          ),
        ],
      ),
    );
    if (confirmed == true) cubit.restartPuzzle();
  }
}
```

Add the export to `crossword_ui.dart`:

```dart
export 'gameplay/presentation/crossword_screen/widgets/crossword_menu_button.dart';
```

In both `mobile_crossword_screen.dart` and `web_crossword_screen.dart`, add as the FIRST app-bar action:

```dart
          const CrosswordMenuButton(),
```

- [x] **Step 4: Run to verify pass**

Run: `cd packages/crossword_ui && flutter test && cd ../../apps/mobile && flutter test && cd ../web && flutter test`
Expected: ALL PASS.

- [x] **Step 5: Commit**

```bash
git add packages/crossword_ui apps/mobile apps/web
git commit -m "feat(ui): game menu with check, reveal, clear, and restart"
```

---

### Task 15: Celebration dialog and filled-but-wrong nudge

**Files:**
- Modify: `packages/crossword_ui/lib/gameplay/presentation/crossword_screen/crossword_player.dart`
- Modify: `packages/crossword_ui/lib/common/data/constants/strings.dart`
- Test (create): `packages/crossword_ui/test/gameplay/presentation/crossword_screen/crossword_player_feedback_test.dart`

- [x] **Step 1: Write the failing tests:**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crossword_core/crossword_core.dart';
import 'package:crossword_ui/crossword_ui.dart';

CrosswordPuzzle _puzzle() {
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
      (0, 1): AnswerCell(value: 'A'),
      (0, 2): AnswerCell(value: 'B'),
    },
    words: [w],
    title: 't',
    languageCode: 'sv',
  );
}

void main() {
  late CrosswordCubit cubit;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    cubit = CrosswordCubit(
      puzzle: _puzzle(),
      fontService: FontService(prefs: prefs),
      settingsService: GameplaySettingsService(prefs: prefs),
      progressService: ProgressService(prefs: prefs),
    );
  });

  tearDown(() => cubit.close());

  Widget harness() => MaterialApp(
        home: BlocProvider.value(
          value: cubit,
          child: const Scaffold(body: CrosswordPlayer()),
        ),
      );

  testWidgets('solving the puzzle shows the celebration dialog',
      (tester) async {
    await tester.pumpWidget(harness());
    cubit.selectCell(0, 1);
    cubit.onLetterInput('A');
    cubit.onLetterInput('B');
    await tester.pumpAndSettle();

    expect(find.text(Strings.solvedTitle), findsOneWidget);
    expect(find.text(Strings.solvedBody), findsOneWidget);
  });

  testWidgets('a full but wrong grid shows the nudge snackbar',
      (tester) async {
    await tester.pumpWidget(harness());
    cubit.selectCell(0, 1);
    cubit.onLetterInput('A');
    cubit.onLetterInput('X');
    await tester.pump();

    expect(find.text(Strings.puzzleFilledButIncorrect), findsOneWidget);
    expect(find.text(Strings.solvedTitle), findsNothing);
  });
}
```

- [x] **Step 2: Run to verify failure**

Run: `cd packages/crossword_ui && flutter test test/gameplay/presentation/crossword_screen/crossword_player_feedback_test.dart`
Expected: FAIL — strings undefined, no listener.

- [x] **Step 3: Implement.** Add to `Strings`:

```dart
  /// Celebration dialog after solving the puzzle.
  static const String solvedTitle = 'Grattis!';
  static const String solvedBody = 'Du löste korsordet.';
  static const String closeAction = 'Stäng';

  /// SnackBar nudge when the grid is full but something is wrong.
  static const String puzzleFilledButIncorrect =
      'Korsordet är fullt – något stämmer inte än.';
```

In `crossword_player.dart`, add imports for `AppColors`/`Strings`/`AppTextStyles` constants:

```dart
import '../../../common/data/constants/app_colors.dart';
import '../../../common/data/constants/strings.dart';
```

Replace the `CrosswordPlayer.build` `BlocBuilder` with a `BlocConsumer` and add the helpers:

```dart
class CrosswordPlayer extends StatelessWidget {
  const CrosswordPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CrosswordCubit, CrosswordState>(
      listener: (context, state) {
        if (state is PuzzleSolved) {
          _showSolvedDialog(context);
        } else if (state is PuzzleFilledButIncorrect) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(Strings.puzzleFilledButIncorrect),
            ),
          );
        }
      },
      builder: (context, state) => _CrosswordPlayerBody(state: state),
    );
  }

  /// Subtle, paper-styled celebration: congratulations plus the choice to
  /// keep admiring the grid or start over.
  void _showSolvedDialog(BuildContext context) {
    final cubit = context.read<CrosswordCubit>();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.paper,
        title: const Text(Strings.solvedTitle),
        content: const Text(Strings.solvedBody),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              cubit.restartPuzzle();
            },
            child: const Text(Strings.restartAction),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(Strings.closeAction),
          ),
        ],
      ),
    );
  }
}
```

- [x] **Step 4: Run to verify pass**

Run: `cd packages/crossword_ui && flutter test`
Expected: ALL PASS.

- [x] **Step 5: Commit**

```bash
git add packages/crossword_ui
git commit -m "feat(ui): celebration dialog and filled-but-wrong nudge"
```

---

### Task 16: Autocheck switch in settings

**Files:**
- Modify: `apps/mobile/lib/settings/presentation/settings_screen/cubit/settings_state.dart`
- Modify: `apps/mobile/lib/settings/presentation/settings_screen/cubit/settings_cubit.dart`
- Modify: `apps/mobile/lib/settings/presentation/settings_screen/settings_screen.dart`
- Modify: `packages/crossword_ui/lib/common/data/constants/strings.dart`
- Modify: `apps/mobile/test/settings/presentation/settings_screen/cubit/settings_cubit_test.dart`
- Modify: `apps/mobile/test/settings/presentation/settings_screen/settings_screen_test.dart`

- [x] **Step 1: Write the failing tests.** In `settings_cubit_test.dart`, update the setup and add the toggle test:

```dart
  late FontService fontService;
  late GameplaySettingsService settingsService;
  late SettingsCubit cubit;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    fontService = FontService(prefs: prefs);
    settingsService = GameplaySettingsService(prefs: prefs);
    cubit = SettingsCubit(
      fontService: fontService,
      settingsService: settingsService,
    );
  });

  tearDown(() {
    cubit.close();
    fontService.dispose();
    settingsService.dispose();
  });
```

```dart
  test('autocheck defaults off and setAutocheck updates state and service',
      () async {
    expect(cubit.state.autocheck, isFalse);

    await cubit.setAutocheck(true);

    expect(cubit.state.autocheck, isTrue);
    expect(settingsService.autocheck.value, isTrue);
  });
```

In `settings_screen_test.dart`, replace the harness and add the switch test:

```dart
Future<Widget> _settingsUnderTest() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return MultiRepositoryProvider(
    providers: [
      RepositoryProvider<FontService>.value(value: FontService(prefs: prefs)),
      RepositoryProvider<GameplaySettingsService>.value(
        value: GameplaySettingsService(prefs: prefs),
      ),
    ],
    child: const MaterialApp(home: SettingsScreen()),
  );
}
```

```dart
  testWidgets('shows the autocheck switch', (tester) async {
    await tester.pumpWidget(await _settingsUnderTest());
    await tester.pumpAndSettle();

    expect(find.text(Strings.autocheckLabel), findsOneWidget);
    expect(find.byType(SwitchListTile), findsOneWidget);
  });
```

- [x] **Step 2: Run to verify failure**

Run: `cd apps/mobile && flutter test test/settings`
Expected: COMPILE ERROR / FAIL.

- [x] **Step 3: Implement.** Add to `Strings`:

```dart
  /// Section header for gameplay settings.
  static const String gameplaySettingLabel = 'Spel';

  /// Autocheck switch label and description.
  static const String autocheckLabel = 'Automatisk kontroll';
  static const String autocheckDescription =
      'Markera felaktiga bokstäver direkt';
```

`settings_state.dart` — add the field:

```dart
class SettingsState extends Equatable {
  final List<AppFont> fonts;
  final AppFont selectedFont;
  final bool autocheck;

  const SettingsState({
    required this.fonts,
    required this.selectedFont,
    required this.autocheck,
  });

  @override
  List<Object?> get props => [fonts, selectedFont, autocheck];

  SettingsState copyWith({
    List<AppFont>? fonts,
    AppFont? selectedFont,
    bool? autocheck,
  }) {
    return SettingsState(
      fonts: fonts ?? this.fonts,
      selectedFont: selectedFont ?? this.selectedFont,
      autocheck: autocheck ?? this.autocheck,
    );
  }
}
```

`settings_cubit.dart`:

```dart
class SettingsCubit extends Cubit<SettingsState> {
  final FontService _fontService;
  final GameplaySettingsService _settingsService;

  SettingsCubit({
    required FontService fontService,
    required GameplaySettingsService settingsService,
  })  : _fontService = fontService,
        _settingsService = settingsService,
        super(SettingsState(
          fonts: AppFont.values,
          selectedFont: fontService.selectedFont.value,
          autocheck: settingsService.autocheck.value,
        ));

  Future<void> selectFont(AppFont font) async {
    await _fontService.selectFont(font);
    emit(state.copyWith(selectedFont: font));
  }

  Future<void> setAutocheck(bool enabled) async {
    await _settingsService.setAutocheck(enabled);
    emit(state.copyWith(autocheck: enabled));
  }
}
```

`settings_screen.dart` — pass the service in the provider:

```dart
      create: (context) => SettingsCubit(
        fontService: context.read<FontService>(),
        settingsService: context.read<GameplaySettingsService>(),
      ),
```

and append the gameplay section to the `Column` children (after the font tiles):

```dart
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                child: Text(
                  Strings.gameplaySettingLabel,
                  style: AppTextStyles.clue(16),
                ),
              ),
              SwitchListTile(
                title: const Text(Strings.autocheckLabel),
                subtitle: const Text(Strings.autocheckDescription),
                value: state.autocheck,
                onChanged: cubit.setAutocheck,
              ),
```

- [x] **Step 4: Run to verify pass**

Run: `cd apps/mobile && flutter test`
Expected: ALL PASS.

- [x] **Step 5: Commit**

```bash
git add apps/mobile packages/crossword_ui
git commit -m "feat(settings): autocheck toggle"
```

---

### Task 17: Full-workspace verification

- [x] **Step 1: Analyze everything**

Run from the repo root: `flutter analyze`
Expected: No issues found.

- [x] **Step 2: Run every test suite**

```bash
(cd packages/crossword_core && flutter test) && \
(cd packages/crossword_ui && flutter test) && \
(cd apps/mobile && flutter test) && \
(cd apps/web && flutter test)
```
Expected: ALL PASS.

- [x] **Step 3: Fix anything surfaced, re-run, then commit any stragglers**

```bash
git status --short   # should show nothing uncommitted from this plan
```
