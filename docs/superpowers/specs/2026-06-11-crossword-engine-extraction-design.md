# Extract CrosswordEngine from CrosswordCubit

**Date:** 2026-06-11
**Status:** Approved design, pending implementation plan

## Goal

Thin `CrosswordCubit` down to a view model by extracting the crossword-solving algorithm into a stateless `CrosswordEngine` service. The Cubit keeps only the UI model and UI decisions; the service handles only crossword logic. This makes the solving logic unit-testable without a Cubit and establishes the thin-view-model pattern as the reference example.

This is a **behaviour-preserving refactor** — no gameplay behaviour changes. The existing `crossword_cubit_test.dart` suite is the safety net.

## Principle (the boundary)

- **Service = crossword logic only.** Pure rules of the puzzle: where selection goes, what is filled, which word is active, which direction.
- **View model = the UI model and every UI decision.** Constructing/emitting state, raising the soft keyboard, the font listener, controllers/focus, view transform, IME translation.

## Component 1 — `CrosswordEngine` (service)

**Location:** `packages/crossword_ui/lib/gameplay/domain/services/crossword_engine.dart` (new `gameplay/domain/services` layer in `crossword_ui`, matching the clean-architecture convention used by `FontService`).

**Shape:** stateless, Flutter-free, no fields, `const` constructor — so it needs no DI registration. Exported from the `crossword_ui` barrel.

**Public API** — each method takes the current `CrosswordState` plus an action and returns a new `CrosswordState`:

```dart
class CrosswordEngine {
  const CrosswordEngine();

  CrosswordState selectCell(CrosswordState state, int row, int col);
  CrosswordState inputLetter(CrosswordState state, String letter);
  CrosswordState backspace(CrosswordState state);
  CrosswordState moveSelection(CrosswordState state, int rowDelta, int colDelta);
}
```

These are the relocated bodies of the cubit's current `selectCell`, `onLetterInput`, `onBackspace`, and `moveSelection`, with `emit(...)` replaced by `return ...` and every `_raiseKeyboard()` call removed.

**Private helpers moved in verbatim** (now pure, operating on the passed `state` instead of `this.state`): `_activateWord` (returns state instead of emitting; no keyboard call), `_selectAnswerCell`, `_toggleDirection`, `_firstEmptyCell`, `_nextUnfinishedWord`, `_isEmptyFillable`, `_axisAt`, `_step`. The `_letterPattern` regex stays in the cubit (it is used by IME translation, see below); the engine receives already-validated single letters.

**What the engine sets:** the logic fields of `CrosswordState` — `selectedCell`, `activeWordId`, `currentDirection`, `userInputs`, and `highlightedCells` (the active word's cell set, a structural fact derived from the puzzle). It uses the existing `copyWith` / `withLoneCell` helpers, so `font` is carried through untouched. The engine never reads or writes `font` as anything but pass-through.

**What the engine never touches:** the keyboard, `FontService`, any controller/focus node, `emit`, or any Flutter UI type.

## Component 2 — `CrosswordCubit` (view model, slimmed)

The Cubit owns the UI model and is the sole emitter. It holds a `const CrosswordEngine()` (default-constructed; injectable via an optional constructor parameter `engine` for tests, defaulting to `const CrosswordEngine()` — no DI wiring needed).

**Event methods become thin adapters:**

```dart
void selectCell(int row, int col) => _applySelection(_engine.selectCell(state, row, col));
void onLetterInput(String letter) => emit(_engine.inputLetter(state, letter));
void onBackspace() => emit(_engine.backspace(state));
void moveSelection(int r, int c) => _applySelection(_engine.moveSelection(state, r, c));
```

**The keyboard rule (the one UI decision that was scattered):** selection actions raise the soft keyboard; typing/backspace do not. Centralised in one private helper:

```dart
void _applySelection(CrosswordState next) {
  emit(next);
  _raiseKeyboard();
}
```

`onLetterInput`/`onBackspace` just `emit` — they never raise the keyboard. This is behaviour-equivalent in practice: during typing the soft keyboard is already up, so the only dropped call (re-focus when input auto-advances to a new word) is unobservable. `_raiseKeyboard()` keeps its existing guard (`isTouchPlatform && keyboardFocusNode.context != null`).

**What stays in the Cubit unchanged:** `isTouchPlatform`, `_raiseKeyboard`, `resetView`, the `FontService` listener (`_onFontChanged` → `emit(state.copyWith(font: ...))`), all controllers/focus nodes, the `TransformationController`, `close()` disposal, and `onInputChanged` (IME translation). `onInputChanged` keeps the `_letterPattern` validation and now calls `onLetterInput`/`onBackspace` (which delegate to the engine) exactly as today.

**Net:** the Cubit shrinks to construction + the font listener + IME translation + four one-line event adapters + the keyboard/view plumbing. All branching solving logic leaves.

## Data Flow

```
UI event → CrosswordCubit.<action>()
            → CrosswordEngine.<action>(state, …)   // pure: returns next CrosswordState
            → emit(next)                            // cubit is sole emitter
            → _raiseKeyboard()                      // selection actions only
```

## Testing

- **New:** `packages/crossword_ui/test/gameplay/domain/services/crossword_engine_test.dart` — unit-tests the engine directly (no Cubit, no widgets), constructing `CrosswordState`/`CrosswordPuzzle` fixtures as the current cubit tests already do. Covers: clue-cell selection, answer-cell selection, same-cell direction toggle, within-word advance, skipped-gap jump-back, word-completion → next unfinished word, backspace within/across cells, arrow navigation across non-answer cells, lone-cell selection, and `highlightedCells` correctness.
- **Kept:** `crossword_cubit_test.dart` continues to pass unchanged — it now exercises the Cubit→Engine path and remains the behaviour-preservation guard. Cubit-specific coverage (keyboard raise on selection vs not on typing, font listener, IME translation, `resetView`) stays here.
- Gate: `crossword_ui` analyzes clean and all tests pass; full workspace test run stays green.

## Out of Scope

- No change to `CrosswordState`'s shape or to `SettingsCubit` (already thin).
- No move of the engine into `crossword_core` and no pure `GameState` type (explicitly declined — the engine operates on `CrosswordState`).
- No gameplay behaviour changes.

## Risks

- This is the app's most intricate and most recently churned code (bent arrows, redirected words, IME input, soft keyboard). The mitigation is strict behaviour preservation: helper bodies move verbatim, and the unchanged `crossword_cubit_test.dart` suite must stay green throughout.
