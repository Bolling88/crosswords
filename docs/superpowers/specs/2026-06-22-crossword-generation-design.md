# Crossword Generation — Design

**Date:** 2026-06-22
**Status:** Approved (pending spec review)

## Goal

Let the user generate a fresh Swedish korsord from the backend
`POST https://api.ikors.se/crossword-puzzles/generate` endpoint and play it,
replacing the current behaviour where the app boots straight into a single
bundled puzzle.

## Scope & decisions

- **Entry point:** a dedicated **generate screen** that is the app's landing
  screen. The user sets options, taps Generate, sees a loader, and is navigated
  into the existing gameplay screen with the result. Back returns to the
  generate screen.
- **Exposed parameters:** grid size, max word length, and seed words. Everything
  else uses defaults.
- **`language_code`** is fixed to `"sv"` (the only language available).
- **Pictures off:** `picture_cols`/`picture_rows` sent as `0` — image clues and
  clue text are not ready yet.
- **No clue text:** the endpoint returns no clue prose today
  (`generated_clues` is null). Clue cells render arrows only, exactly as the
  current bundled puzzle does (`HintCellWidget` already handles null clue text).
- **No persistence:** generation is stateless; nothing is saved. Each Generate
  is a fresh call.
- **Bundled puzzle kept as a test view:** `loadBundledPuzzle()` stays. The
  generate screen exposes a secondary "Test puzzle" action that loads the
  bundled puzzle and navigates into gameplay through the same path. It is an
  explicit developer/test entry point, not an error fallback.

## Architecture — approach C: dedicated `crossword_api` package

```
crossword_core   domain model (CrosswordPuzzle, Cell, Word, ArrowShape) + bundled loader
      ▲              + extract shared ArrowShapeResolver (from PuzzleResolver)
      │
crossword_api    NEW package — everything for /crossword-puzzles/generate:
      │              DTOs · RemoteDataSource (http) · mapper · repository · service
      ▲
crossword_ui     depends on core + api — GenerateScreen + GeneratePuzzleCubit
      ▲
apps/mobile,     set GenerateScreen as landing; inject app-specific
apps/web         gameplayBuilder(context, puzzle)
```

- New package `packages/crossword_api/`, `resolution: workspace`, added to the
  root `pubspec.yaml` `workspace:` list. Depends on `crossword_core` and `http`
  (the repo's first network dependency).
- `crossword_ui/pubspec.yaml` gains a path dependency on `crossword_api`.
- Base URL `https://api.ikors.se` is a constructor default on the remote source
  so tests can override it.

### Shared refactor

Extract `PuzzleResolver._arrowShape` into a shared, public
`ArrowShapeResolver` in `crossword_core` so both the bundled resolver and the
new generation mapper compute clue arrows identically. The generator places
clues above/left of word starts, so it genuinely produces the same straight and
bent arrow cases (e.g. a clue at `(0,0)` for a rightward word starting at
`(1,0)` → bent down-then-right).

## `crossword_api` internals

### Request DTO — `CrosswordGenerationRequest` (`toJson`)
- User-controlled: `width`, `height`, `maxWordLen`, `seedWords`.
- Fixed/default: `languageCode: "sv"`, `pictureCols: 0`, `pictureRows: 0`,
  `maxSeconds: 30`.

### Response DTOs (`fromJson`)
`CrosswordGenerationResponse` parses only the fields the mapper needs:
`success`, `failure_reason`, `grid_cells`, `slots`, `assignments`, `seed_cells`.
`cells` (bitmask), `stats`, and clue-generation fields are ignored for now.

Nested DTOs: `GenerationGridCellDto` (`kind`, `row`, `col`, `rowspan`,
`colspan`, `letter`, `clue_tags[]`, `sep_right`, `sep_bottom`, `is_seed`),
`GenerationSlotDto` (`slot_id`, `start_row`, `start_col`, `direction`,
`length`), `GenerationAssignmentDto` (`slot_id`, `word`), `GenerationSeedCellDto`
(`row`, `col`, `letter`).

### `CrosswordGenerationRemoteDataSource`
`POST /crossword-puzzles/generate`. Throws a typed `CrosswordGenerationException`
on non-200 or `success: false` (carrying `failure_reason`).

### `GeneratedPuzzleMapper` — response → `CrosswordPuzzle`
- **Words:** one per slot. Walk `length` cells from `(start_row, start_col)` in
  `direction`; `id = slot_id.toString()`; letters from
  `assignments[slot_id].word`. Slots are straight runs.
- **Cells:** `grid_cells` → `AnswerCell` / `ClueCell` / `BlockCell`. Clue arrows
  built from `clue_tags`, computing `ArrowShape` via `ArrowShapeResolver` from
  `(clue_row, clue_col)` of the tag's slot vs the slot's `(start_row,
  start_col)`. `clueText` stays null.
- **`seedPositions`** from `seed_cells`; **`separatorEdges`** from
  `sep_right` / `sep_bottom`.
- `title` = `Strings.generatedPuzzleTitle`; `languageCode = "sv"`.

### `CrosswordGenerationRepository`
Coordinates remote source + mapper, returns `CrosswordPuzzle`.

### `PuzzleGenerationService` (domain)
Thin wrapper:
- `Future<CrosswordPuzzle> generate(GenerationParams params)`
- `Future<CrosswordPuzzle> loadTestPuzzle()` → delegates to
  `loadBundledPuzzle()`.

Registered in each app's `main.dart`, injected into the cubit (cubit talks only
to the service, per the service-layer convention).

## `GenerateScreen` (crossword_ui)

Standard three-widget structure (`GenerateScreen` → `GenerateScreenBuilder` →
`GenerateScreenContent`).

### `GeneratePuzzleCubit`
- Owns a `seedWords` `TextEditingController`, selected grid-size preset, selected
  max-word-length, and `isGenerating`. Disposes the controller in `close()`.
- Methods: `selectSize`, `selectMaxWordLen`, `generate()`, `openTestPuzzle()`.
- Event states (each with `final Key key = UniqueKey();`, props overridden):
  - `GenerationSucceeded` carrying the `CrosswordPuzzle`.
  - `ShowGenerationError` carrying a Swedish message.

### Controls
- Grid-size presets: 11×11 / 15×15 / 17×17 (maps to width/height).
- Max-word-length presets: 5 / 6 / 8.
- Seed-words text field (split on comma/whitespace; optional).
- Generate button — shows a spinner and is disabled while generating.
- Secondary "Test puzzle" action — loads the bundled puzzle.

### Navigation & errors
- On `GenerationSucceeded`, the builder's listener calls the injected
  `gameplayBuilder(context, puzzle)` and `Navigator.push`es it. `crossword_ui`
  stays app-agnostic; each app pushes its own `MobileCrosswordScreen` /
  `WebCrosswordScreen`.
- On `ShowGenerationError`, show a SnackBar (Swedish string); button re-enables
  for retry.

## App wiring (`apps/mobile`, `apps/web`)

- `main()` stops calling `loadBundledPuzzle()` at startup. It constructs
  `PuzzleGenerationService` (with repository/remote source/http client) and
  registers it via `RepositoryProvider`.
- `home:` becomes `AuthGate(child: GenerateScreen(gameplayBuilder: ...))`.
- Each app's `gameplayBuilder` wraps the puzzle in its existing
  `MobileCrosswordScreen` / `WebCrosswordScreen`.

## Strings

New Swedish strings in the centralized `Strings`: screen title, grid-size label,
max-word-length label, seed-words field label/hint, Generate button, generating
label, test-puzzle action, generated-puzzle title, and a generation-error
message. No hardcoded user-facing text.

## Testing

- **`GeneratedPuzzleMapper`** against the saved live sample (committed as a test
  fixture): grid dims, a known word's letters, a known straight vs bent arrow,
  seed positions.
- **`CrosswordGenerationRepository`** with a fake data source: success,
  `success: false`, and HTTP-error paths.
- **`GeneratePuzzleCubit`** with a fake service: generate → succeeded / error
  event states; `openTestPuzzle` → succeeded.
- **DTOs**: `fromJson` / `toJson` round-trip.

## Out of scope (future fixes)

- Clue text (`generated_clues`) and image clues.
- Persistence / saving puzzles (other endpoints).
- Bent/redirected generated words (current slots are straight runs).
