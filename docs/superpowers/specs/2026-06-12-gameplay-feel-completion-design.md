# Gameplay Feel & Completion — Design

**Date:** 2026-06-12
**Status:** Approved direction (user: "go with your recommendations")

## Context

The core solving loop works (selection, word-path navigation, bent words, mobile
IME input), but the game has no ending, no memory, and no feedback: nothing
detects a solved puzzle, progress dies with the app process, the active
direction is invisible, and there is zero sensory feedback. This milestone turns
the demo into a game with a beginning, middle, and end.

`AnswerCell.value` already carries the solution letter for every fillable cell,
so correctness checking is pure engine work — no format or generator changes.

## Goals

1. **Completion & correctness** — detect a solved puzzle, celebrate it, and
   offer on-demand check/reveal tools plus an optional autocheck setting.
2. **Direction / active-word visibility** — make the active word's clue cell
   visibly part of the highlight so the player always knows which word (and
   which way) they are filling.
3. **Local progress persistence** — restore the grid exactly as left, across
   app restarts.
4. **Haptics & micro-animations** — letter pop, animated highlight transitions,
   word-confirmed flash, and tactile feedback on key moments.

Also in scope (a bug this work exposes): **seed letters are never rendered** —
`CrosswordGrid` only displays `userInputs`, so a seed cell shows a sage wash but
no letter. Completion logic treats seeds as given-correct, so they must be
visible.

## Non-goals (later milestones)

Keyboard-aware auto-pan, home screen / puzzle library, image clue content, clue
prose, stats/streaks/timer, accessibility semantics, dark mode, pencil mode,
undo, backend sync.

## Design decisions (resolved)

- **Checking philosophy:** on-demand checking via a menu, with autocheck as an
  opt-in setting (default off). Korsord tradition leans toward unassisted
  solving; autocheck is there for players who want it.
- **Celebration tone:** subtle — a paper-styled dialog plus haptic, no confetti.
- **Filled-but-wrong:** when the grid becomes full but isn't correct, show a
  one-shot SnackBar nudge. Solving is auto-detected (a full, correct grid
  celebrates immediately even with checking off — the universal convention).
- **Revealed letters lock; checked-correct letters don't.** Reveal is an
  explicit "give me the answer" so those cells become given (like seeds). Cells
  that merely survive a check stay editable and unmarked.

## Architecture

All game logic stays in `CrosswordEngine` (pure, Flutter-free, state → state).
`CrosswordCubit` orchestrates: settings lookup, haptics, persistence calls, and
one-shot event states. New cross-feature state lives in services following the
`FontService` pattern (ValueNotifier + SharedPreferences, cubit-only access).

### 1. State additions (`CrosswordState`)

```dart
final Set<(int, int)> incorrectCells;  // marked wrong by check/autocheck
final Set<(int, int)> revealedCells;   // letters given via reveal; locked
final bool isSolved;                   // grid full and every letter correct
final (int, int)? activeClueCell;      // clue cell of the active word
final String? confirmedWordId;         // word that just verified correct…
final int confirmedWordToken;          // …bumped per confirm, keys the flash
```

- `copyWith` gains the non-nullable fields; `activeClueCell` and
  `confirmedWordId` get the project's no-sentinel treatment (cleared inside
  dedicated transitions, not via `copyWith(null)`).
- Add a `CrosswordState.copy(CrosswordState)` constructor so event states can
  extend the live state per the project's event-state pattern.
- `withLoneCell` clears `activeClueCell`.

**Event states** (each with `final Key key = UniqueKey()` in `props`):

- `PuzzleSolved extends CrosswordState` — emitted once on the false→true
  `isSolved` transition. Listener shows the celebration dialog.
- `PuzzleFilledButIncorrect extends CrosswordState` — emitted once when an
  input action makes the grid full but wrong (transition-edged: only when the
  previous state was not full). Listener shows a SnackBar.

### 2. Engine additions (`CrosswordEngine`)

```dart
CrosswordState inputLetter(state, letter, {bool autocheck = false});
CrosswordState checkWord(state);    // mark wrong cells of the active word
CrosswordState checkPuzzle(state);  // mark wrong cells everywhere
CrosswordState revealCell(state);   // solution into selected cell, lock, advance
CrosswordState revealWord(state);   // fill + lock active word, jump onward
CrosswordState clearWord(state);    // clear active word (skip seeds/revealed)
CrosswordState restart(state);      // fresh inputs/marks/selection
bool isFilled(state);               // every fillable cell has input
```

Shared rules:

- **Correctness:** user letter equals `AnswerCell.value` (both already
  uppercase). Seeds are given-correct; separators are ignored (per the JSON
  format spec). `isSolved` = `isFilled` && no wrong letters.
- **Editing wrong cells clears the mark:** `inputLetter`/`backspace` remove the
  edited cell from `incorrectCells`.
- **Revealed cells are immutable:** `inputLetter` on a revealed cell advances
  without writing (like a seed gap-skip); `backspace` steps over them without
  clearing. `_isEmptyFillable` already treats filled cells as done, so advance
  logic is unchanged.
- **Autocheck:** when the flag is passed, each entered letter that's wrong is
  added to `incorrectCells` immediately.
- **Word confirmation:** when an action leaves the active word fully filled and
  fully correct *and* checking was involved (autocheck input, `checkWord`,
  `checkPuzzle`, or `revealWord`), set `confirmedWordId` and bump
  `confirmedWordToken` to drive the flash. Plain unchecked typing does not
  confirm (the player asked not to be told).
- Every mutating method recomputes `isSolved`.

### 3. Domain addition (`CrosswordPuzzle`)

```dart
(int, int)? cluePositionOf(String wordId);
```

Scans `cells` for the `ClueCell` whose arrow carries `wordId` (grids are small;
linear scan at activation time is fine). `_activateWord` stores the result in
`activeClueCell`.

### 4. Services

**`ProgressService`** (`crossword_ui/lib/gameplay/domain/services/`):

- `ProgressSnapshot? read(String puzzleKey)` (sync — SharedPreferences reads
  are synchronous), `Future<void> save(String puzzleKey, ProgressSnapshot)`,
  `Future<void> clear(String puzzleKey)`. Failed writes are non-fatal, matching
  `FontService`.
- `ProgressSnapshot` = `userInputs` + `revealedCells`, JSON-encoded under key
  `progress_<puzzle.title>` (cells as `"row,col"` strings). The puzzle format
  has no stable id yet; title is the key until a backend supplies ids —
  acceptable while puzzles are bundled.
- Cubit restores the snapshot in its constructor (folded into the initial
  state, with `isSolved` recomputed) and fire-and-forgets a save whenever
  `userInputs` or `revealedCells` changed in `_apply`. `restart` clears it.

**`GameplaySettingsService`** (`crossword_ui/lib/settings/domain/services/`):

- `ValueNotifier<bool> autocheck` (default false), `setAutocheck(bool)`,
  persisted as `autocheck_enabled`. Mirrors `FontService` exactly.
- `CrosswordCubit` reads `autocheck.value` at input time (no listener needed —
  the setting only affects future keystrokes).
- Registered in both app `main()`s; settings screen gains a "Spel" section
  with a switch (Automatisk kontroll / "Markera felaktiga bokstäver direkt").

### 5. Cubit orchestration (`CrosswordCubit`)

- New actions delegating to the engine through `_apply`: `checkWord`,
  `checkPuzzle`, `revealCell`, `revealWord`, `clearWord`, `restartPuzzle`.
- `_apply` grows three responsibilities, all transition-edged against the
  previous state:
  1. persistence save / clear,
  2. one-shot events: emit `PuzzleSolved` or `PuzzleFilledButIncorrect`
     *after* the regular state emit,
  3. haptics (gated on `isTouchPlatform`): `HapticFeedback.lightImpact` per
     entered letter, `mediumImpact` on word confirm, `heavyImpact` on solve,
     `vibrate` when a check marks new errors.

### 6. UI

**Grid & cells:**

- `AnswerCellWidget` switches `Container` → `AnimatedContainer` (~150 ms) so
  selection/highlight changes glide instead of snap.
- Letter pop: the glyph wrapped in a `TweenAnimationBuilder<double>` keyed by
  `ValueKey(userInput)` scaling 0.6→1.0 (~120 ms, ease-out-back). Stateless.
- New paint states, in priority order: wrong letter → `AppColors.errorInk`
  (brick red `#B3402F`); revealed letter → `AppColors.inkMuted`; seed/normal →
  `AppColors.ink`. Seed cells now render `cell.value` when no user input
  exists (the display fix).
- Word-confirmed flash: cells of `confirmedWordId` carry a
  `TweenAnimationBuilder` keyed by `ValueKey(confirmedWordToken)` fading a
  sage overlay to transparent (~600 ms).
- `HintCellWidget` gains `isActive`; the active clue cell's background
  animates to a new `AppColors.clueCellActive` (amber-tinted beige `#E6D9A8`),
  making direction changes visible (the toggled word's clue lights up).

**Screen chrome (mobile + web):**

- App bar gains a `PopupMenuButton`: Kontrollera ord, Kontrollera allt, Visa
  bokstav, Visa ord, Rensa ord, Börja om. "Börja om" confirms via an
  `AlertDialog` from the view (same view-local pattern as the existing
  settings `Navigator.push`) before calling `cubit.restartPuzzle()`.
- The screen builder becomes a `BlocConsumer`; the listener handles
  `PuzzleSolved` (paper-styled dialog: "Grattis!" / "Du löste korsordet." with
  Stäng + Börja om) and `PuzzleFilledButIncorrect` (SnackBar: "Korsordet är
  fullt – något stämmer inte än.").

**Strings (all Swedish, in `Strings`):** menu labels above, dialog texts,
autocheck labels, snackbar text. **Colors (in `AppColors`):** `errorInk`,
`clueCellActive`.

## Error handling

- Persistence read failures (corrupt JSON, missing key) fall back to a clean
  state; write failures are swallowed (session keeps working), matching
  `FontService`.
- Check/reveal/clear actions with no active word or selection are no-ops via
  the existing `_apply` unchanged-state guard.

## Testing

- **Engine** (extend `crossword_engine_test.dart`): correctness math, autocheck
  marking, mark-clearing on edit, reveal locking + advance-over-revealed,
  clearWord skipping seeds/revealed, isFilled/isSolved transitions, confirmed
  word token bumps, restart.
- **Cubit** (extend `crossword_cubit_test.dart`): one-shot `PuzzleSolved` /
  `PuzzleFilledButIncorrect` edges (no refire), persistence restore at
  construction, save-on-change, clear-on-restart, autocheck flag plumbed from
  the service.
- **Services**: `ProgressService` round-trip / corrupt-data fallback;
  `GameplaySettingsService` persistence (mirror `font_service_test.dart`).
- **Domain**: `cluePositionOf` (extend `crossword_puzzle_test.dart`).
- **Widgets**: seed letter rendered; wrong/revealed ink colors; active clue
  cell highlight; menu actions dispatch to cubit.
