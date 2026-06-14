# Keyboard-Aware Auto-Pan — Design

**Date:** 2026-06-14
**Status:** Approved direction (user approved Approach A)

## Context

The crossword grid is rendered inside an `InteractiveViewer(constrained: false)`
driven by a cubit-owned `TransformationController` (see
`crossword_player.dart`). When a player zooms in to read/tap a dense korsord and
the soft keyboard opens, the cell they are filling can end up hidden behind the
keyboard or scrolled out of view, with no way for the view to follow. This
milestone makes the view keep the selected cell visible.

Key facts that shape the design:

- The host `Scaffold` uses the default `resizeToAvoidBottomInset: true`, so when
  the keyboard opens the body shrinks and the `LayoutBuilder` constraints in
  `crossword_player.dart` already exclude the keyboard. **The constraints are
  the true visible viewport** — no separate keyboard-height measurement is
  needed.
- The `InteractiveViewer` child is a `SizedBox(width: maxW, height: maxH)` (the
  viewport size) with the grid centered inside it via `Align` + symmetric
  `Padding(16)`. So at identity transform the grid is centered, and a cell's
  centre in child-space is a simple function of viewport size, `cellSize`, and
  the cell's `(row, col)`.
- Project rule: no `StatefulWidget`/`setState`/`addListener` in widgets; all
  state and controllers live in the cubit. A `Ticker`-based animated pan is
  therefore awkward to host, so the pan is applied as an instant transform
  assignment (the existing `resetView()` already drives the controller this
  way).

## Goal

When the selected cell would be hidden by the keyboard or scrolled off-screen,
translate the grid just enough to bring the cell into a comfortable band, and
otherwise leave the view untouched (minimal "scroll into view", caret-style).

## Non-goals

- Animated/eased panning (instant assignment for v1; see Rationale).
- Auto-zoom or changing the user's scale (translation only).
- Changing `resizeToAvoidBottomInset` or the grid's auto-fit-at-scale-1
  behaviour.
- Horizontal-only or vertical-only restriction — both axes are handled, but no
  new gestures or controls.

## Design decisions (resolved)

- **Behaviour:** minimal scroll-into-view — move only when the selected cell is
  outside a comfortable band, and only enough to reach the band edge
  (confirmed with user).
- **Snap, not animate:** assign the transform directly. During the keyboard's
  open animation the body shrinks frame-by-frame, so the per-frame corrections
  already read as a smooth follow; a standalone eased pan would need a `Ticker`
  the no-`StatefulWidget` rule makes awkward. Flagged as possible later polish.
- **Scale preserved:** only the translation changes. At scale 1 the grid already
  auto-fits above the keyboard, and (see below) the math naturally yields "no
  move", so the feature is active precisely when the user has zoomed in.
- **All platforms:** the selection-change trigger also helps desktop arrow-key
  navigation when zoomed; harmless where there is no keyboard.

## Architecture

Three small, independently understandable units.

### 1. Pure geometry helper (new)

`packages/crossword_ui/lib/gameplay/presentation/crossword_screen/keyboard_follow.dart`

```dart
/// The transform that brings [cell] into a comfortable band of the viewport,
/// or null when the cell is already comfortably visible. Only the translation
/// is changed; the current scale is preserved. Pure — no Flutter widgets.
Matrix4? transformToRevealCell({
  required Matrix4 current,
  required Size viewport,
  required double cellSize,
  required int rows,
  required int cols,
  required (int, int) cell,
  required double margin,
});
```

Math (no rotation/skew — `InteractiveViewer` only scales + translates):

- Scale `s = current.storage[0]`; translation `tx = current.storage[12]`,
  `ty = current.storage[13]`.
- Cell centre in child-space (grid centred in the viewport-sized child; the
  2px border and symmetric padding cancel out and do not shift the centre):
  - `cx = (viewport.width  - cols * cellSize) / 2 + col * cellSize + cellSize/2`
  - `cy = (viewport.height - rows * cellSize) / 2 + row * cellSize + cellSize/2`
- Cell centre in viewport-space: `vx = s*cx + tx`, `vy = s*cy + ty`.
- Per axis, with effective margin `m = min(margin, extent/3)` and band
  `[m, extent - m]`: if the centre is below the band, the target translation
  puts it at `extent - m`; if above, at `m`; otherwise unchanged.
- **Clamp** each new translation so the child still covers the viewport: since
  the child extent equals the viewport extent, valid translation is
  `[extent * (1 - s), 0]`. At `s == 1` this collapses to `0`, so a fit-to-screen
  grid can't pan — the function returns `null` unless a correction to 0 is
  needed.
- Build the result by copying `current` and calling
  `setTranslationRaw(tx', ty', 0)`. Return `null` when both axes are unchanged
  within a small epsilon.

### 2. Cubit (`crossword_cubit.dart`)

- New fields: `Size? _viewportSize; double? _cellSize;` (plain fields, never
  emitted — pure view geometry).
- `void setLayout({required Size viewport, required double cellSize})`:
  stores the values; if they **changed** and a cell is selected, schedules
  `_ensureSelectedCellVisible()` via
  `WidgetsBinding.instance.addPostFrameCallback`. This catches the keyboard
  finishing its open/close animation (a layout change with no selection change).
  Post-frame is required because `setLayout` runs during `build`, and assigning
  the controller value synchronously there would trigger `InteractiveViewer`'s
  listener mid-build.
- `void _ensureSelectedCellVisible()`: if `_viewportSize`, `_cellSize`, and
  `state.selectedCell` are all present, call `transformToRevealCell(...)` with
  `margin: cellSize` and, when it returns non-null, assign it to
  `transformationController`.
- In `_apply`, after the existing emit/persist/feedback, add:
  `if (next.selectedCell != prev.selectedCell) _ensureSelectedCellVisible();`.
  This single hook covers **every** selection change — tap, arrow move,
  type-advance, reveal, clear — because they all flow through `_apply`. It runs
  in response to user events (never during build), so the synchronous transform
  assignment is safe there.

### 3. Player wiring (`crossword_player.dart`)

In the existing `LayoutBuilder`, after `cellSize` is computed, add one call:

```dart
cubit.setLayout(
  viewport: Size(constraints.maxWidth, constraints.maxHeight),
  cellSize: cellSize,
);
```

No other widget changes; no scaffold changes.

## Data flow

- **Select / move / type / reveal:** action → `_apply` emits → selection
  changed → `_ensureSelectedCellVisible()` synchronously nudges the transform if
  needed.
- **Keyboard opens/closes (or rotation):** body resizes → `LayoutBuilder`
  rebuilds → `setLayout` sees a changed viewport → post-frame
  `_ensureSelectedCellVisible()` follows the shrinking/growing viewport.

## Error handling / edge cases

- Metrics not yet known (before first layout) or no selection → ensure is a
  no-op.
- Scale 1 (fit-to-screen) → helper returns `null`; grid already fully visible.
- Cell already in band → `null`; no movement (the minimal-move requirement).
- Degenerate margins (`extent` smaller than `2*margin`) → `m` capped at
  `extent/3` so the band is always non-empty.

## Testing

- **Pure function (carries the load), `keyboard_follow_test.dart`:**
  - cell below the visible band at scale 2 → translation moves it to the bottom
    margin; scale preserved.
  - cell above the band → moves to the top margin.
  - cell already comfortably visible → returns `null`.
  - scale 1 → returns `null` (band collapses; cannot pan).
  - clamp: a correction that would expose the child's edge is limited so the
    child still covers the viewport.
  - horizontal axis behaves symmetrically to vertical.
- **Cubit (`crossword_cubit_test.dart`):**
  - `setLayout` stores metrics without emitting a new state.
  - with a zoomed-in transform set, selecting an off-screen cell moves
    `transformationController.value`; selecting an already-visible cell leaves it
    unchanged.
- **Widget (`crossword_player` test):** pump the player in a fixed box with a
  zoomed transform and a selected low cell, then rebuild with a shorter box
  (simulating the keyboard) and assert the transform translated upward. Keeps
  the post-frame/layout path honestly covered.

## Files

- Create: `.../crossword_screen/keyboard_follow.dart`
- Modify: `.../crossword_screen/cubit/crossword_cubit.dart`
- Modify: `.../crossword_screen/crossword_player.dart`
- Create: `test/.../crossword_screen/keyboard_follow_test.dart`
- Modify: `test/.../crossword_screen/cubit/crossword_cubit_test.dart`
- Modify (or add): `test/.../crossword_screen/crossword_player_*_test.dart`

`keyboard_follow.dart` is exported from `crossword_ui.dart` only if a test needs
it across the package boundary; otherwise the test imports it by path (as the
existing `hint_cell_widget` test does), keeping the public surface unchanged.
