# Crossword JSON Format — Design

**Date:** 2026-06-04
**Status:** Approved (Approach B)

## Goal

Consume the crossword-generator JSON format and render/play it with full fidelity.
For now the JSON is a hardcoded bundled asset; a backend API comes later.

Reference sample: `assets/puzzles/generated_crossword.json` (downloaded from the
generator). Top-level shape:

```jsonc
{
  "title": "Generated crossword",
  "language_code": "sv",
  "grid": { "width": 13, "height": 15, "rows": [ [ <cell>, ... ], ... ] },
  "seed_positions": [ { "col": 3, "row": 3 }, ... ]
}
```

### Cell kinds (entries in `grid.rows[row][col]`)

- **`block`** — `{ "kind": "block" }`. Inert dark cell.
- **`answer`** — a fillable letter cell:
  ```jsonc
  {
    "kind": "answer",
    "value": "K",              // solution letter, may be Å/Ä/Ö
    "right_redirect": false,    // right-traveling word turns here
    "down_redirect": false,     // down-traveling word turns here
    "right_separator": null,    // "_" => word break inside the across phrase
    "down_separator": null      // "_" => word break inside the down phrase
  }
  ```
- **`clue`** — a hint cell defining up to two words (one across, one down):
  ```jsonc
  {
    "kind": "clue",
    "right": null,              // across clue prose (null in generator output)
    "right_clue_id": "clue-39",
    "right_word_id": "word-39",
    "right_start": { "col": 5, "row": 0 },  // first answer cell of the across word
    "down": null,               // down clue prose
    "down_clue_id": "clue-8",
    "down_word_id": "word-8",
    "down_start": { "col": 5, "row": 0 }    // first answer cell of the down word
  }
  ```
  Any of the right_* / down_* groups may be entirely null/absent (clue has only
  one direction, or — for fully null — is a passive spacer clue cell).

### Key semantics

- **Bent arrows.** A clue's `*_start` is the word's first answer cell and is **not
  necessarily adjacent** to the clue cell. The arrow glyph is derived from the
  vector (clue cell → start) plus the word's travel direction.
- **Redirect.** A word does not always run in a straight line. When a
  right-traveling word reaches an answer cell with `right_redirect: true`, the
  word **turns down** for its remaining letters; a down-traveling word at
  `down_redirect: true` **turns right**. *(Assumption — to verify against more
  generator output. Encoded in one place so it is cheap to change.)*
- **Separator.** `"_"` in `*_separator` marks an intra-answer word break (the
  answer is a multi-word phrase). Stored, rendered as a thin divider, ignored
  when checking correctness.
- **Seed positions.** The theme word the grid was generated around. Rendered
  with a subtle highlight.
- **Empty clue prose.** `right`/`down` are null in generator output. Clue cells
  render **arrows only**, no text.

## Architecture (Approach B: parse → resolve → domain)

```
JSON asset
  → Data DTOs (1:1 fromJson)          gameplay/data/entities/dto/
  → PuzzleResolver                    gameplay/data/
  → Domain CrosswordPuzzle + Words    gameplay/domain/entities/
  → Cubit / widgets (render + play)   gameplay/presentation/
```

### Data layer — DTOs (`gameplay/data/entities/dto/`)

Pure JSON mirrors with `fromJson`, no behaviour:

- `PuzzleDto` — title, languageCode, grid, seedPositions.
- `GridDto` — width, height, `List<List<GridCellDto>>`.
- `GridCellDto` (sealed) → `BlockCellDto`, `AnswerCellDto`, `ClueCellDto`.
  - `AnswerCellDto` — value, rightRedirect, downRedirect, rightSeparator, downSeparator.
  - `ClueCellDto` — for each direction: clue text, clueId, wordId, start (`PositionDto?`).
- `PositionDto` — col, row.

Dispatch on the `kind` discriminator in `GridCellDto.fromJson`.

### Resolver (`gameplay/data/puzzle_resolver.dart`)

Converts `PuzzleDto` → domain `CrosswordPuzzle`. Responsibilities:

1. Build the `(row, col) → Cell` grid (Block / Answer / Clue domain cells).
2. **Resolve every word.** For each clue direction that has a `*_start`:
   - Begin at `start`, travel in the base direction (across = right, down = down).
   - Append answer cells; at a `*_redirect` cell, **turn** per the redirect rule.
   - Stop at the first non-answer cell (block/clue/edge) with no active redirect.
   - Produce a `Word { id, clueId, direction, clueText?, cells: List<(int,int)>,
     separators: Set<int> }` where `separators` holds indices after which a break falls.
3. Compute each clue arrow's **shape** from (clue pos, start pos, travel dir):
   `straightRight`, `straightDown`, `bentDownThenRight`, `bentRightThenDown`.
4. Attach to each domain `ClueCell` its 0–2 `ClueArrow`s (direction + shape + wordId).

### Domain layer (`gameplay/domain/entities/`)

- `CrosswordPuzzle { int rows, cols; Map<(int,int), Cell> cells; List<Word> words;
   Set<(int,int)> seedPositions; String title; String languageCode; }`
- `Cell` (sealed) → `BlockCell`, `AnswerCell { value; bool isSeed; }`,
  `ClueCell { List<ClueArrow> arrows; }`. `ImageCell` retained for future image clues.
- `ClueArrow { Direction direction; ArrowShape shape; String wordId; }`
- `Word` (as above) — the unit gameplay navigates and highlights.
- `ArrowShape` enum; `Direction` enum reused/extended.

The existing `data/entities/{cell,crossword_puzzle,direction}.dart` are migrated
into this domain shape (they currently live under data/ but are used as domain
models). `buildSamplePuzzle()` is removed once the asset loads.

### Data source / loading

- `assets/puzzles/generated_crossword.json` — the downloaded sample, registered
  under `flutter: assets:` in `pubspec.yaml`.
- `LocalPuzzleDataSource.loadGeneratedPuzzle()` — reads via `rootBundle`,
  `jsonDecode`, `PuzzleDto.fromJson`, `PuzzleResolver.resolve` → `CrosswordPuzzle`.
  Async; returns the domain puzzle. Replaces `buildSamplePuzzle()` at the call site.

### Cubit / presentation changes

- Word highlight + letter navigation use the resolved `Word.cells` ordered path
  (look up the word(s) containing the selected cell) instead of adjacency walking.
  This is what makes bent/redirected words behave correctly.
- `selectCell` on a clue cell follows its arrow's `wordId` to that word's first cell.
- `HintCellWidget` renders `ClueArrow.shape` glyphs (incl. bent L-shapes); shows no
  text while clue prose is null.
- `AnswerCellWidget` renders the letter; draws a thin divider on separator edges;
  applies a subtle seed highlight when `isSeed`.
- Swedish åäö input is already handled and must keep working.

## Testing

Unit tests (no widget tests required by this spec):

- DTO round-trip: `PuzzleDto.fromJson` on the real asset parses without loss.
- Resolver — straight across/down word cell paths.
- Resolver — bent arrow: non-adjacent `start` yields correct first cell + arrow shape.
- Resolver — redirect: right-word turning down and down-word turning right produce
  the correct ordered path.
- Resolver — separators recorded at the right indices.
- Resolver — two-clue cell yields two words / two arrows.
- Resolver — åÄÖ values preserved.
- Cubit — highlight + next/prev navigation follow a redirected word path.

## Out of scope

- Backend API / network fetch (later).
- Clue prose authoring (generator emits null clue text).
- Image clues beyond retaining the existing `ImageCell` type.

## Open question

- **Redirect turn rule.** "Right-word bends down / down-word bends right" is an
  assumption. Confirm against additional generator output; isolated in the
  resolver so it can change in one place.
