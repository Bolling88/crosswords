# CrosswordEngine Extraction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract the crossword-solving algorithm out of `CrosswordCubit` into a stateless `CrosswordEngine`, leaving the Cubit as a thin view model that owns only the UI model and UI decisions.

**Architecture:** `CrosswordEngine` is a pure, Flutter-free, `const` class. Each method takes the current `CrosswordState` + an action and returns the next `CrosswordState` (logic fields only). The Cubit holds a `const CrosswordEngine()`, delegates each event to it, emits the result, and raises the soft keyboard for selection actions. Behaviour-preserving refactor — the existing `crossword_cubit_test.dart` suite is the regression guard.

**Tech Stack:** Flutter, flutter_bloc (Cubit), Equatable, Dart records/pattern-matching.

**Spec:** `docs/superpowers/specs/2026-06-11-crossword-engine-extraction-design.md`

---

## Placement note (refinement of the spec)

The spec named `gameplay/domain/services/` for the engine. Because the engine operates on `CrosswordState` (a presentation-layer class in `cubit/`), placing it in `domain/` would invert CLAUDE.md's `Cubit → Service` dependency direction. This plan instead places it at **`gameplay/presentation/crossword_screen/crossword_engine.dart`**, beside the cubit it serves, so imports flow `presentation → core` with no inversion. Responsibility is unchanged: the engine handles only crossword logic.

## File Structure

**Create:**
- `packages/crossword_ui/lib/gameplay/presentation/crossword_screen/crossword_engine.dart` — the stateless solving engine.
- `packages/crossword_ui/test/gameplay/presentation/crossword_screen/crossword_engine_test.dart` — engine unit tests.

**Modify:**
- `packages/crossword_ui/lib/gameplay/presentation/crossword_screen/cubit/crossword_cubit.dart` — slim to delegate to the engine.
- `packages/crossword_ui/lib/crossword_ui.dart` — export the engine.

**Unchanged (regression guard):**
- `packages/crossword_ui/test/gameplay/presentation/crossword_screen/cubit/crossword_cubit_test.dart` — must keep passing as-is.

---

## Task 1: Create CrosswordEngine and slim the Cubit

This is one atomic, behaviour-preserving refactor: the logic moves verbatim (every `emit(...)` becomes `return ...`, every `_raiseKeyboard()` call is dropped from the logic), and the Cubit delegates. The unchanged `crossword_cubit_test.dart` proves behaviour is preserved.

**Files:**
- Create: `packages/crossword_ui/lib/gameplay/presentation/crossword_screen/crossword_engine.dart`
- Modify: `packages/crossword_ui/lib/gameplay/presentation/crossword_screen/cubit/crossword_cubit.dart`
- Modify: `packages/crossword_ui/lib/crossword_ui.dart`

- [ ] **Step 1: Create the engine file**

Create `packages/crossword_ui/lib/gameplay/presentation/crossword_screen/crossword_engine.dart` with exactly this content:

```dart
import 'package:crossword_core/crossword_core.dart';

import 'cubit/crossword_state.dart';

/// Pure crossword-solving logic, extracted from [CrosswordCubit]. Stateless and
/// Flutter-free: every method takes the current [CrosswordState] plus an action
/// and returns the next state with the logic fields updated (selection, active
/// word, direction, inputs, and the active word's highlighted cells). It never
/// touches the keyboard, fonts, controllers, or `emit`; the Cubit owns those.
/// `font` is carried through untouched via [CrosswordState.copyWith].
class CrosswordEngine {
  const CrosswordEngine();

  /// Select the cell at [row],[col]: activate a clue's word, (re)select an
  /// answer cell, or toggle direction when re-selecting the current cell.
  CrosswordState selectCell(CrosswordState state, int row, int col) {
    final cell = state.puzzle.cells[(row, col)];
    if (cell == null) return state;

    switch (cell) {
      case BlockCell():
      case ImageCell():
        return state;
      case ClueCell():
        if (cell.arrows.isEmpty) return state;
        final word = state.puzzle.wordById(cell.arrows.first.wordId);
        if (word == null || word.cells.isEmpty) return state;
        return _activateWord(state, word, word.cells.first);
      case AnswerCell():
        if (state.selectedCell == (row, col)) {
          return _toggleDirection(state, row, col);
        }
        return _selectAnswerCell(state, row, col);
    }
  }

  /// Record [letter] at the selected cell and advance: to the next cell of the
  /// active word, back to a skipped gap, or on to the next unfinished word.
  CrosswordState inputLetter(CrosswordState state, String letter) {
    final sel = state.selectedCell;
    if (sel == null) return state;

    final newInputs = Map<(int, int), String>.from(state.userInputs)
      ..[sel] = letter;

    // Still room to advance within the active word: step to the next cell.
    final next = _step(state, sel, 1);
    if (next != null) {
      return state.copyWith(
        userInputs: newInputs,
        selectedCell: next,
        currentDirection: _axisAt(state, next),
      );
    }

    // Reached the last cell of the active word. If the word still has a gap
    // (the player skipped a cell), jump back to it; otherwise the word is done,
    // so advance to the next unfinished word. With neither, just keep the input.
    final activeWord = state.puzzle.wordById(state.activeWordId ?? '');
    if (activeWord == null) {
      return state.copyWith(userInputs: newInputs);
    }

    final gap = _firstEmptyCell(state, activeWord, newInputs);
    if (gap != null) {
      return state.copyWith(
        userInputs: newInputs,
        selectedCell: gap,
        currentDirection: _axisAt(state, gap),
      );
    }

    final nextWord = _nextUnfinishedWord(state, newInputs);
    if (nextWord == null) {
      return state.copyWith(userInputs: newInputs);
    }

    final target =
        _firstEmptyCell(state, nextWord, newInputs) ?? nextWord.cells.first;
    return _activateWord(state, nextWord, target, userInputs: newInputs);
  }

  /// Delete the selected cell's letter, or step back and delete the previous
  /// cell's letter when the selected cell is already empty.
  CrosswordState backspace(CrosswordState state) {
    final sel = state.selectedCell;
    if (sel == null) return state;

    final newInputs = Map<(int, int), String>.from(state.userInputs);
    if (newInputs.containsKey(sel)) {
      newInputs.remove(sel);
      return state.copyWith(userInputs: newInputs);
    }

    final prev = _step(state, sel, -1);
    if (prev == null) return state;
    newInputs.remove(prev);
    return state.copyWith(
      userInputs: newInputs,
      selectedCell: prev,
      currentDirection: _axisAt(state, prev),
    );
  }

  /// Move the selection one cell in the given direction (e.g. (0, 1) for the
  /// right arrow), skipping over non-answer cells until the next answer cell.
  /// The pressed axis becomes the preferred word direction at the landing cell.
  CrosswordState moveSelection(CrosswordState state, int rowDelta, int colDelta) {
    final sel = state.selectedCell;
    if (sel == null) return state;

    final axis = colDelta != 0 ? Direction.right : Direction.down;
    var (row, col) = sel;
    while (true) {
      row += rowDelta;
      col += colDelta;
      final cell = state.puzzle.cells[(row, col)];
      if (cell == null) return state; // ran off the grid; keep the selection
      if (cell is AnswerCell) {
        return _selectAnswerCell(state, row, col, axis);
      }
    }
  }

  CrosswordState _selectAnswerCell(
    CrosswordState state,
    int row,
    int col, [
    Direction? preferAxis,
  ]) {
    final axis = preferAxis ?? state.currentDirection;
    final word = state.puzzle.wordAt((row, col), axis) ??
        state.puzzle.wordAt(
          (row, col),
          axis == Direction.right ? Direction.down : Direction.right,
        );

    if (word == null) {
      return state.withLoneCell((row, col));
    }
    return _activateWord(state, word, (row, col));
  }

  CrosswordState _toggleDirection(CrosswordState state, int row, int col) {
    final other = state.currentDirection == Direction.right
        ? Direction.down
        : Direction.right;
    final word = state.puzzle.wordAt((row, col), other);
    if (word == null) return state;
    return _activateWord(state, word, (row, col));
  }

  /// Make [word] the active word and select [cell] within it, highlighting the
  /// whole word and pinning the direction to the word's local axis there. Pass
  /// [userInputs] to fold a just-typed letter into the same result.
  CrosswordState _activateWord(
    CrosswordState state,
    Word word,
    (int, int) cell, {
    Map<(int, int), String>? userInputs,
  }) {
    final index = word.cells.indexOf(cell);
    return state.copyWith(
      userInputs: userInputs,
      activeWordId: word.id,
      selectedCell: cell,
      currentDirection: word.axisAt(index < 0 ? 0 : index),
      highlightedCells: word.cells.toSet(),
    );
  }

  /// The first fillable (non-seed) cell of [word] still missing input, or null
  /// when the word is fully filled.
  (int, int)? _firstEmptyCell(
    CrosswordState state,
    Word word,
    Map<(int, int), String> inputs,
  ) {
    for (final cell in word.cells) {
      if (_isEmptyFillable(state, cell, inputs)) return cell;
    }
    return null;
  }

  /// The next word after the active one (wrapping) that still has an empty
  /// fillable cell, or null when every other word is complete.
  Word? _nextUnfinishedWord(
    CrosswordState state,
    Map<(int, int), String> inputs,
  ) {
    final words = state.puzzle.words;
    if (words.isEmpty) return null;
    final start = words.indexWhere((w) => w.id == state.activeWordId);
    for (var offset = 1; offset <= words.length; offset++) {
      final word = words[(start + offset) % words.length];
      if (_firstEmptyCell(state, word, inputs) != null) return word;
    }
    return null;
  }

  /// Whether [cell] is an answer cell the player still needs to fill. Seed cells
  /// carry a given letter, so they never count as empty.
  bool _isEmptyFillable(
    CrosswordState state,
    (int, int) cell,
    Map<(int, int), String> inputs,
  ) {
    final c = state.puzzle.cells[cell];
    return c is AnswerCell && !c.isSeed && !inputs.containsKey(cell);
  }

  /// The active word's local axis at [cell], or the current direction if the
  /// cell is not on the active word.
  Direction _axisAt(CrosswordState state, (int, int) cell) {
    final word = state.puzzle.wordById(state.activeWordId ?? '');
    if (word == null) return state.currentDirection;
    final i = word.cells.indexOf(cell);
    return i < 0 ? state.currentDirection : word.axisAt(i);
  }

  /// Step [delta] cells along the active word's ordered path from [cell],
  /// following the word through any bend; null if it would leave the word.
  (int, int)? _step(CrosswordState state, (int, int) cell, int delta) {
    final word = state.puzzle.wordById(state.activeWordId ?? '');
    if (word == null) return null;
    final i = word.cells.indexOf(cell);
    if (i < 0) return null;
    final j = i + delta;
    if (j < 0 || j >= word.cells.length) return null;
    return word.cells[j];
  }
}
```

- [ ] **Step 2: Export the engine from the barrel**

In `packages/crossword_ui/lib/crossword_ui.dart`, add the engine export. Change:

```dart
export 'gameplay/presentation/crossword_screen/crossword_player.dart';
```

to:

```dart
export 'gameplay/presentation/crossword_screen/crossword_engine.dart';
export 'gameplay/presentation/crossword_screen/crossword_player.dart';
```

- [ ] **Step 3: Replace the Cubit with the slimmed version**

Overwrite `packages/crossword_ui/lib/gameplay/presentation/crossword_screen/cubit/crossword_cubit.dart` with exactly this content. (The solving logic and its helpers are gone — they now live in `CrosswordEngine`. The Cubit keeps construction, the font listener, IME translation, controllers, keyboard, and view transform.) Note: `inputSentinel` is `'​'` (a zero-width space) — same value the old file held as a literal; tests reference the value, not the source bytes.

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:crossword_core/crossword_core.dart';

import '../../../../settings/domain/services/font_service.dart';
import '../crossword_engine.dart';
import 'crossword_state.dart';

class CrosswordCubit extends Cubit<CrosswordState> {
  /// Invisible seed character kept in [inputController] so the hidden mobile
  /// field always has content: a longer value means a letter was typed, an
  /// empty value means the user pressed backspace on the sentinel. Public only
  /// so tests can reference it.
  @visibleForTesting
  static const inputSentinel = '​'; // zero-width space

  static final _letterPattern = RegExp(r'[a-zA-ZåäöÅÄÖ]');

  final FocusNode focusNode = FocusNode();
  final TransformationController transformationController =
      TransformationController();

  /// Controller + focus node for the hidden, mobile-only text field that summons
  /// the OS soft keyboard. Owned here per the project rule that controllers live
  /// in the Cubit. Seeded with [inputSentinel].
  final TextEditingController inputController =
      TextEditingController(text: inputSentinel);
  final FocusNode keyboardFocusNode = FocusNode();

  final FontService _fontService;
  final CrosswordEngine _engine;

  CrosswordCubit({
    required CrosswordPuzzle puzzle,
    required FontService fontService,
    CrosswordEngine engine = const CrosswordEngine(),
  })  : _fontService = fontService,
        _engine = engine,
        super(CrosswordState(
          puzzle: puzzle,
          font: fontService.selectedFont.value,
        )) {
    _fontService.selectedFont.addListener(_onFontChanged);
  }

  void _onFontChanged() {
    emit(state.copyWith(font: _fontService.selectedFont.value));
  }

  void selectCell(int row, int col) =>
      _applySelection(_engine.selectCell(state, row, col));

  void onLetterInput(String letter) => emit(_engine.inputLetter(state, letter));

  void onBackspace() => emit(_engine.backspace(state));

  void moveSelection(int rowDelta, int colDelta) =>
      _applySelection(_engine.moveSelection(state, rowDelta, colDelta));

  /// Emit [next] and raise the soft keyboard. Used only for selection actions
  /// (tapping a cell, arrow keys): the player is moving the caret, so summon the
  /// keyboard. Typing and backspace emit directly and never re-raise it — the
  /// keyboard is already up mid-entry.
  void _applySelection(CrosswordState next) {
    emit(next);
    _raiseKeyboard();
  }

  /// Translate an edit from the hidden mobile text field into letter or
  /// backspace actions. The field is seeded with [inputSentinel]; a value longer
  /// than the sentinel means characters were typed, an empty value means the
  /// sentinel itself was deleted. Every typed character is entered in order —
  /// not just the last — so a suggestion-bar word, glide-typed word, or paste
  /// is not silently truncated. The controller is then reset to the sentinel so
  /// the next keystroke is detectable.
  void onInputChanged(String value) {
    if (value.length > inputSentinel.length) {
      for (final char in value.substring(inputSentinel.length).split('')) {
        if (_letterPattern.hasMatch(char)) {
          onLetterInput(char.toUpperCase());
        }
      }
    } else if (value.isEmpty) {
      onBackspace();
    }
    inputController.value = const TextEditingValue(
      text: inputSentinel,
      selection: TextSelection.collapsed(offset: inputSentinel.length),
    );
  }

  /// True on platforms that use a soft keyboard. Reported by
  /// [defaultTargetPlatform], which on the web returns the *device's* platform —
  /// so a phone browser counts as mobile and a desktop browser does not. Never
  /// keyed off `kIsWeb` or `dart:io`'s `Platform` (the latter throws on web).
  /// Also used by the view to decide whether to build the hidden mobile field,
  /// so the gate lives in one place.
  bool get isTouchPlatform =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.android;

  /// Focus the hidden field to raise the soft keyboard, but only on touch
  /// platforms and only once the field is mounted (its node has a context). On
  /// desktop the field is never built, so the existing hardware [Focus] keeps
  /// sole ownership of input and arrow navigation.
  void _raiseKeyboard() {
    if (isTouchPlatform && keyboardFocusNode.context != null) {
      keyboardFocusNode.requestFocus();
    }
  }

  /// Snap the grid back to the default fit-width, un-panned view.
  void resetView() {
    transformationController.value = Matrix4.identity();
  }

  @override
  Future<void> close() {
    _fontService.selectedFont.removeListener(_onFontChanged);
    focusNode.dispose();
    transformationController.dispose();
    inputController.dispose();
    keyboardFocusNode.dispose();
    return super.close();
  }
}
```

- [ ] **Step 4: Run analyze and the existing cubit suite (regression guard)**

Run: `cd packages/crossword_ui && flutter analyze && flutter test test/gameplay/presentation/crossword_screen/cubit/crossword_cubit_test.dart`
Expected: analyze clean (`No issues found!`); all existing cubit tests pass unchanged. If any cubit test fails, the move was not behaviour-preserving — diff your engine method bodies against the original cubit methods (each should be identical except `emit(x)` → `return x` and the removed `_raiseKeyboard()` calls) and fix before continuing.

- [ ] **Step 5: Run the full crossword_ui suite**

Run: `cd packages/crossword_ui && flutter test`
Expected: all tests pass (the cubit, font, text-styles, app-font, and both mobile-input tests).

- [ ] **Step 6: Commit**

```bash
git add packages/crossword_ui/lib/gameplay/presentation/crossword_screen/crossword_engine.dart \
        packages/crossword_ui/lib/gameplay/presentation/crossword_screen/cubit/crossword_cubit.dart \
        packages/crossword_ui/lib/crossword_ui.dart
git commit -m "refactor: extract CrosswordEngine from CrosswordCubit"
```

---

## Task 2: Unit-test CrosswordEngine in isolation

The engine is now testable without a Cubit or widgets. Add focused unit tests constructing `CrosswordState`/`CrosswordPuzzle` fixtures directly.

**Files:**
- Create: `packages/crossword_ui/test/gameplay/presentation/crossword_screen/crossword_engine_test.dart`

- [ ] **Step 1: Write the engine tests**

Create `packages/crossword_ui/test/gameplay/presentation/crossword_screen/crossword_engine_test.dart` with exactly this content:

```dart
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
```

- [ ] **Step 2: Run the engine tests**

Run: `cd packages/crossword_ui && flutter test test/gameplay/presentation/crossword_screen/crossword_engine_test.dart`
Expected: all tests pass. If `inputLetter`'s gap/next-word assertions fail, re-check the engine's `_firstEmptyCell`/`_nextUnfinishedWord` against the originals; if `moveSelection`/`selectCell` fail, re-check `wordAt`/`axisAt` usage.

- [ ] **Step 3: Run analyze and the full suite**

Run: `cd packages/crossword_ui && flutter analyze && flutter test`
Expected: analyze clean; every test passes (engine + cubit + others).

- [ ] **Step 4: Commit**

```bash
git add packages/crossword_ui/test/gameplay/presentation/crossword_screen/crossword_engine_test.dart
git commit -m "test: unit-test CrosswordEngine in isolation"
```

---

## Self-Review

**Spec coverage:**
- Stateless, Flutter-free, `const` `CrosswordEngine` with `selectCell`/`inputLetter`/`backspace`/`moveSelection` → Task 1 Step 1. ✓
- All private helpers moved in, `_activateWord` returns instead of emitting, no `_raiseKeyboard` in engine → Task 1 Step 1. ✓
- Engine sets logic fields incl. `highlightedCells`; carries `font` through via `copyWith` → Task 1 Step 1. ✓
- Engine exported from barrel → Task 1 Step 2. ✓
- Cubit slimmed: sole emitter, four one-line adapters, `_applySelection` keyboard rule (selection actions raise; typing/backspace don't), keeps font listener / IME / controllers / `resetView` / `isTouchPlatform` / `_raiseKeyboard` → Task 1 Step 3. ✓
- `_letterPattern` stays in the Cubit for IME translation → Task 1 Step 3. ✓
- Engine injectable via `engine = const CrosswordEngine()` default; no DI wiring → Task 1 Step 3. ✓
- New engine unit tests; existing `crossword_cubit_test.dart` kept as guard → Task 2 + Task 1 Step 4. ✓
- Behaviour preservation gated by the unchanged cubit suite → Task 1 Step 4. ✓
- Placement deviation (presentation, not domain/services) documented with rationale → Placement note. ✓

**Placeholder scan:** None — full engine, full cubit, full test file, exact commands.

**Type consistency:** Method names `selectCell`/`inputLetter`/`backspace`/`moveSelection` are used identically in the engine (Task 1 Step 1), the cubit delegations (Task 1 Step 3), and the tests (Task 2). `CrosswordState` fields referenced (`puzzle`, `selectedCell`, `activeWordId`, `currentDirection`, `userInputs`, `highlightedCells`) and helpers (`copyWith`, `withLoneCell`) match the existing `crossword_state.dart`. `CrosswordEngine` constructor is `const` and used as `const CrosswordEngine()` everywhere. Cubit constructor signature adds `CrosswordEngine engine = const CrosswordEngine()`, leaving existing `CrosswordCubit(puzzle:, fontService:)` call sites (cubit tests, both apps' screens) valid.
