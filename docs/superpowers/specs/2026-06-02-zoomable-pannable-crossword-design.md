# Zoomable & Pannable Crossword Grid — Design

**Date:** 2026-06-02
**Status:** Approved (pending spec review)

## Goal

Let users zoom and pan the crossword grid so that large korsord puzzles —
which can be wider and/or taller than the screen — are navigable and
comfortable to read and play on a phone. Cell selection and keyboard typing
must keep working unchanged while zoomed or panned.

## Problem

Today `CrosswordGrid` computes `cellSize = (viewportWidth − frame) / cols`
inside its own `LayoutBuilder` and renders a `Table` + `Stack`, centred with
padding. The grid always fits the screen width exactly, so:

- Tall puzzles (more rows than fit vertically) overflow and clip.
- On large grids cells become small; there is no way to zoom in to read hint
  text/arrows or tap accurately.
- There is no panning.

## Approach

Wrap the grid in Flutter's built-in **`InteractiveViewer`** (pinch-zoom +
drag-pan). Chosen over hand-rolled gesture/matrix handling (reinvents the
wheel, fiddly tap-vs-pan arbitration) and over button-only zoom (not
pannable). `InteractiveViewer` coexists cleanly with the existing tappable
`GestureDetector` cells: taps fall through to cells, single-finger drag pans,
pinch zooms.

## Design

### Sizing model

- An **outer `LayoutBuilder`** (around the `InteractiveViewer`, in the screen
  content) reads the available viewport width and computes the base
  `cellSize = (viewportWidth − frame*2) / cols`. This is the same formula as
  today, just resolved *outside* the viewer.
- `CrosswordGrid` is refactored to **accept `cellSize` as a parameter** rather
  than computing it from its own constraints. It no longer needs its own
  `LayoutBuilder`.
- At scale `1.0` the grid fills the viewport width exactly (default view,
  predictable — matches current behavior). Tall grids that exceed viewport
  height are reachable via vertical pan.

### The viewer

```dart
InteractiveViewer(
  transformationController: cubit.transformationController,
  minScale: 0.5,
  maxScale: 4.0,
  constrained: false,        // child keeps natural size; pan in all directions
  boundaryMargin: const EdgeInsets.all(<reasonable>),
  child: CrosswordGrid(state: state, cellSize: baseCellSize),
)
```

- `constrained: false` lets the child take its natural (possibly larger than
  viewport) size, enabling panning in every direction — including vertical pan
  for tall grids at default zoom.
- Zoom range **0.5x–4x** relative to the fit-width base.

### State / architecture (CLAUDE.md compliance)

- Controllers live in the Cubit, not widgets. Add a
  **`TransformationController transformationController`** field to
  `CrosswordCubit`, disposed in `close()` alongside `focusNode`.
- Add a **`resetView()`** method to the cubit that resets the controller to
  the identity matrix (snap back to fit-width whole view):
  `transformationController.value = Matrix4.identity();`
- All widgets remain `StatelessWidget`. `InteractiveViewer` is a framework
  widget; using it inside a stateless widget is fine and does not violate the
  "our widgets must be stateless" rule.

### Reset control

- An **app-bar icon button** (e.g. `Icons.fit_screen` / `Icons.zoom_out_map`)
  added to the existing `AppBar` `actions`. Tapping it calls
  `cubit.resetView()`. Always visible, unobtrusive.
- String for tooltip/semantics goes in the centralized `Strings` file (no
  hardcoded user-facing text). Icon color uses `AppColors` foreground.

### Interaction (unchanged behavior)

- Tap a cell → selects it (existing `selectCell`), keyboard still types into
  the selected cell via the existing `Focus` + `onKeyEvent` wiring.
- Single-finger drag → pans. Pinch → zooms. Taps are not consumed by the
  viewer, so selection is unaffected.

## Files touched

- `lib/gameplay/presentation/crossword_screen/cubit/crossword_cubit.dart`
  — add `TransformationController`, `resetView()`, dispose in `close()`.
- `lib/gameplay/presentation/crossword_screen/crossword_screen.dart`
  — add outer `LayoutBuilder`, wrap grid in `InteractiveViewer`, add app-bar
  reset action.
- `lib/gameplay/presentation/crossword_screen/widgets/crossword_grid.dart`
  — accept `cellSize` param, drop internal `LayoutBuilder`.
- `lib/common/data/constants/strings.dart` — add reset-view tooltip string.

## Out of scope (YAGNI)

- **Auto-pan to keep the selected cell on-screen** during keyboard
  auto-advance. A genuine nicety when zoomed in, but the stated goal is
  overflow/panning, not auto-advance. Deferred; can be added later by having
  `onLetterInput`/selection updates drive `transformationController` to scroll
  the target cell into view.

## Testing

- Cubit test: `resetView()` sets `transformationController.value` to
  `Matrix4.identity()`.
- Cubit test: `transformationController` is disposed on `close()` (no throw /
  follows existing focusNode disposal pattern).
- Manual: pinch-zoom in/out within 0.5x–4x; pan a tall grid vertically at
  default zoom; tap-to-select + type while zoomed; app-bar reset snaps back.
