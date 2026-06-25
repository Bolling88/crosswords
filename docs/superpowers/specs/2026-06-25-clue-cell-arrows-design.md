# Design: Perfect clue-cell arrows (diagonal entries + split two-clue boxes)

**Date:** 2026-06-25
**Status:** Proposed — awaiting spec review
**Scope:** `crossword_core` (domain + resolver), `crossword_api` (generated mapper),
`crossword_ui` (hint cell rendering). Backend is **not** changed.

## 1. Problem

Generated puzzles (and, to a lesser degree, bundled puzzles) produce clue cells
whose arrows are not rendered correctly. Two distinct defects, both confirmed
against the real `generation_response_9x9.json` fixture:

1. **Diagonal / offset clues.** 4 of 26 slots place the clue box at a *diagonal*
   corner of the word's start cell, e.g. clue `(0,7)` → word start `(1,6)`,
   travelling right. `ArrowShapeResolver` only recognises the four *adjacent*
   start offsets (straight or perpendicular L-bend); for a diagonal start it
   silently falls through to a wrong elbow glyph. The four real cases:

   | tag | clue cell | start | travel | start rel. to clue |
   |-----|-----------|-------|--------|--------------------|
   | 1   | (0,7)     | (1,6) | right  | SW (+1,−1)         |
   | 17  | (0,4)     | (1,3) | down   | SW (+1,−1)         |
   | 21  | (5,7)     | (4,6) | down   | NW (−1,−1)         |
   | 22  | (0,8)     | (1,7) | down   | SW (+1,−1)         |

2. **Two-clue boxes.** 3 cells carry two clue tags. The renderer just `Stack`s
   the arrows by whole-cell alignment with no divider and no anti-overlap, so two
   same-side arrows compete for the same corner. The real cases:

   | clue cell | tag A (shape)            | tag B (shape)        |
   |-----------|--------------------------|----------------------|
   | (4,4)     | → straightRight          | ↓ straightDown       |
   | (5,0)     | → bentUpThenRight (st. (4,0)) | → straightRight (st. (5,1)) |
   | (5,7)     | ↓ diagonal-NW-then-down (st. (4,6)) | ↓ straightDown (st. (6,7)) |

The backend only ships a **cardinal** glyph per tag (`→ ↓ ←`); `bend_arrow` is
`null`. So the precise arrow *shape* must be derived on the client from slot
geometry. That derivation is what we are making correct.

## 2. Decisions (confirmed with product owner)

1. **Client renders the response as-is.** The generation response is
   authoritative; no backend changes. The client must correctly draw whatever
   geometry the backend emits, including diagonal entries.
2. **Diagonal-entry glyphs.** Offset clues render as a proper Swedish-korsord
   corner arrow: leave the box diagonally into the start cell, then run straight
   in the travel direction.
3. **Split two-clue boxes with a divider.** A clue cell holding two clues is
   drawn as two stacked compartments separated by a horizontal divider, one
   arrow per compartment (leaving room for per-compartment clue text later).
4. **CustomPainter for the arrow glyphs.** We make a *scoped* exception to the
   `CLAUDE.md` "widgets, not CustomPainter" rule: the grid structure stays
   widget-based (Table + Stack), but the arrow glyphs inside a clue cell are
   drawn by a small `CustomPainter` so diagonal-then-straight elbows are
   pixel-accurate instead of approximated with Material icons.

## 3. Architecture

```
crossword_core
  domain/entities/arrow_shape.dart        EXTEND enum with diagonal variants
  domain/services/arrow_shape_resolver.dart  GENERALISE: detect diagonal starts
  data/puzzle_resolver.dart               order arrows top-first (right→down already is)

crossword_api
  src/generated_puzzle_mapper.dart        order a cell's clue tags top-first by start row

crossword_ui
  .../crossword_screen/widgets/clue_arrow_painter.dart   NEW: CustomPainter
  .../crossword_screen/widgets/hint_cell_widget.dart     divider + compartments
```

`ClueArrow` (`{direction, shape, wordId}`) and `ClueCell` (`{List<ClueArrow> arrows}`)
are **unchanged** — keeping the blast radius small (`ArrowShape` is referenced in
~16 files, mostly tests). All new geometry is encoded as new `ArrowShape` enum
values that the painter switches on.

## 4. `ArrowShape` extension

Add diagonal-entry variants. Each value fully encodes *entry corner + travel
direction*, so the painter needs no extra data. Naming follows the existing
`bent<Dir>Then<Travel>` convention:

```
// existing: straightRight, straightDown,
//           bentDownThenRight, bentUpThenRight,
//           bentRightThenDown, bentLeftThenDown
// new (travel right):
diagonalSwThenRight, diagonalNwThenRight, diagonalSeThenRight, diagonalNeThenRight
// new (travel down):
diagonalSwThenDown,  diagonalNwThenDown,  diagonalSeThenDown,  diagonalNeThenDown
```

The corner names describe where the **start cell** sits relative to the clue
cell. The fixture exercises `diagonalSwThenRight`, `diagonalSwThenDown`, and
`diagonalNwThenDown`; the remaining five are defined for completeness so any
geometry the generator can emit has a defined glyph (no silent fallback).

## 5. `ArrowShapeResolver` generalisation

The resolver already takes `(clueRow, clueCol, startRow, startCol, base)`. Add a
diagonal branch *before* the existing fallbacks:

- Compute `dr = startRow − clueRow`, `dc = startCol − clueCol`.
- `dr == 0` (and `dc == ±1`) or `dc == 0` (and `dr == ±1`) → existing
  straight / perpendicular logic (unchanged).
- `|dr| == 1 && |dc| == 1` → diagonal: map `(sign(dr), sign(dc), base)` to the
  matching `diagonal*` value via a small table.
- Anything else (non-adjacent, non-diagonal) → throw
  `CrosswordGenerationException` (or assert in the bundled path) instead of the
  current silent wrong-glyph fallback. This surfaces malformed responses rather
  than drawing a lie.

This keeps the resolver a pure function — unit-tested in isolation.

## 6. Compartment ordering (two-clue boxes)

The widget must not have to know slot geometry. So **ordering is decided at map
time**: `ClueCell.arrows` is ordered **top-first** — `arrows[0]` is the clue
whose word starts higher (smaller `startRow`); `arrows[1]` is the lower one. Tie
(equal start row) breaks by smaller `startCol`.

- `GeneratedPuzzleMapper._arrowsFor` sorts the cell's `clueTags` by their slot's
  `startRow` (then `startCol`) before building `ClueArrow`s.
- `PuzzleResolver` already emits right-then-down order; verified this matches
  top-first for every two-clue case in the bundled puzzles (a down word's start
  is at or below a right word's start from the same clue). A guard test locks
  this in.

Verified against the fixture: the rule assigns the correct arrow to top/bottom in
all three two-clue cells (e.g. (5,7): NW-then-down → top, straightDown → bottom).

## 7. `ClueArrowPainter` (new)

A single `CustomPainter` draws one arrow from its `ArrowShape` within a given
rectangle (the whole cell for a single clue, or a compartment for a split box):

- **Straight** — a line from the entry edge across to the exit edge, arrowhead at
  the tip.
- **L-bend** — line in from one edge, right-angle turn, arrowhead at the tip.
- **Diagonal** — a short diagonal stub from the clue-cell corner into the start
  cell, then a right-angle turn into the travel direction, arrowhead at the tip.

It takes `shape`, `color` (`AppColors.ink`), and stroke width derived from cell
`size`. Because it draws from geometry, all 14 shapes share one code path keyed
by a small per-shape descriptor (entry unit-vector, travel unit-vector); there is
no per-shape branch in the paint loop. `shouldRepaint` compares `shape`, `color`,
size.

## 8. `HintCellWidget`

- **0 arrows:** unchanged (empty clue cell).
- **1 arrow:** a `CustomPaint` filling the cell, painting `arrows.first`.
- **2 arrows:** a `Column` of `[topCompartment, divider, bottomCompartment]`,
  each compartment a `CustomPaint` of its arrow within the half-height rect. The
  divider is a 0.5px `AppColors.gridLine` line (matches the existing cell
  border). Active-word highlight (`isActive`) is preserved at the cell level.

Still a `StatelessWidget`; no state, no `setState` (CLAUDE.md compliant). The
`GestureDetector` on the clue cell is retained (grid cells are the documented
exception to the InkWell rule).

## 9. Testing

- `arrow_shape_resolver_test.dart` — add the 4 diagonal fixture cases plus the
  other diagonal corners; assert the malformed (non-adjacent, non-diagonal) case
  throws.
- `generated_puzzle_mapper_test.dart` — assert two-clue cells emit arrows in
  top-first order for (4,4), (5,0), (5,7).
- `puzzle_resolver_test.dart` — guard test: bundled two-clue cells stay
  top-first.
- New `hint_cell_widget` widget test — single arrow paints once; two arrows
  produce a divider and two `CustomPaint`s; golden-free structural assertions.
- Painter geometry covered indirectly via widget test + a focused unit test on
  the per-shape descriptor table (entry/travel vectors per `ArrowShape`).

## 10. Out of scope (YAGNI)

- Per-compartment **clue text** (generator returns `null` clue prose today; the
  divider layout leaves room for it later).
- Picture clues / `ImageCell` (not produced with pictures off).
- Backend / generator changes.
- Vertical dividers or 3+ clues per box (not produced by the generator).

## 11. Risks / open questions

- **Diagonal arrow legibility at small cell sizes.** A diagonal-then-straight
  elbow in a tiny cell may be cramped; the painter's stroke width and stub
  length are tunable, and we will verify in the running app.
- **Diagonal travel ambiguity.** A diagonal entry implies the start cell but the
  travel leg (right vs down) disambiguates which word; both are encoded in the
  shape, so the painted elbow is unambiguous.
- **Five unexercised diagonal variants.** Defined but not seen in the current
  fixture; covered by resolver unit tests so they are correct if the generator
  ever emits them.
