# Keyboard-Aware Auto-Pan Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep the selected crossword cell visible above the soft keyboard by translating the `InteractiveViewer` grid the minimum needed when the cell would otherwise be hidden.

**Architecture:** A pure geometry function computes the corrective transform (fully unit-testable, no widgets). The cubit feeds it the live layout via `setLayout`, calls it on every selection change through `_apply`, and re-checks after a viewport change (keyboard) via a post-frame callback. The player passes the `LayoutBuilder` metrics in with one line. Scale is preserved; only translation changes; instant assignment (no `Ticker`).

**Tech Stack:** Flutter workspace package `crossword_ui`, flutter_bloc cubit, `TransformationController`, flutter_test.

**Spec:** `docs/superpowers/specs/2026-06-14-keyboard-aware-auto-pan-design.md`

**Conventions that bind every task:** no `!` operator, no `StatefulWidget`/`setState`/`addListener` in widgets, controllers live in the cubit, trailing commas, `const` where possible.

---

### Task 1: Pure geometry helper `transformToRevealCell`

**Files:**
- Create: `packages/crossword_ui/lib/gameplay/presentation/crossword_screen/keyboard_follow.dart`
- Test (create): `packages/crossword_ui/test/gameplay/presentation/crossword_screen/keyboard_follow_test.dart`

All commands run from `packages/crossword_ui`.

- [ ] **Step 1: Write the failing tests** — create `keyboard_follow_test.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crossword_ui/gameplay/presentation/crossword_screen/keyboard_follow.dart';

void main() {
  // A 10x10 grid that exactly fills a 300x300 viewport: cellSize 30, so cell
  // (r,c) centre in child-space is (c*30+15, r*30+15).
  const viewport = Size(300, 300);
  const cellSize = 30.0;
  const rows = 10;
  const cols = 10;
  const margin = cellSize; // 30; band is [30, 270] on each axis

  Matrix4 scaled(double s, [double tx = 0, double ty = 0]) =>
      Matrix4.identity()
        ..scale(s)
        ..setTranslationRaw(tx, ty, 0);

  test('returns null at fit scale (cannot pan)', () {
    final result = transformToRevealCell(
      current: Matrix4.identity(),
      viewport: viewport,
      cellSize: cellSize,
      rows: rows,
      cols: cols,
      cell: (9, 9),
      margin: margin,
    );

    expect(result, isNull);
  });

  test('returns null when the cell is already comfortably visible', () {
    // scale 2, panned so cell (2,2) centre (75,75) maps to (100,100) — inside
    // the [30,270] band on both axes.
    final result = transformToRevealCell(
      current: scaled(2, -50, -50),
      viewport: viewport,
      cellSize: cellSize,
      rows: rows,
      cols: cols,
      cell: (2, 2),
      margin: margin,
    );

    expect(result, isNull);
  });

  test('pans up to the bottom margin when the cell is below the band', () {
    // scale 2, no pan: cell (6,*) centre y = 195 -> viewport y = 390 (> 270).
    final result = transformToRevealCell(
      current: scaled(2),
      viewport: viewport,
      cellSize: cellSize,
      rows: rows,
      cols: cols,
      cell: (6, 2),
      margin: margin,
    );

    // ty' = (extent - m) - s*cy = 270 - 390 = -120; cell lands at y = 270.
    expect(result, isNotNull);
    expect(result!.storage[13], closeTo(-120, 0.5));
    expect(2 * 195 + result.storage[13], closeTo(270, 0.5));
  });

  test('pans down to the top margin when the cell is above the band', () {
    // scale 2, panned up by 80: cell (1,3) centre y = 45 -> viewport y = 10,
    // above the band; x (centre 105 -> 210) stays inside.
    final result = transformToRevealCell(
      current: scaled(2, 0, -80),
      viewport: viewport,
      cellSize: cellSize,
      rows: rows,
      cols: cols,
      cell: (1, 3),
      margin: margin,
    );

    // ty' = m - s*cy = 30 - 90 = -60; cell lands at y = 30; x unchanged.
    expect(result, isNotNull);
    expect(result!.storage[13], closeTo(-60, 0.5));
    expect(result.storage[12], closeTo(0, 0.5));
  });

  test('pans left to the right margin when the cell is right of the band', () {
    final result = transformToRevealCell(
      current: scaled(2),
      viewport: viewport,
      cellSize: cellSize,
      rows: rows,
      cols: cols,
      cell: (2, 6),
      margin: margin,
    );

    expect(result, isNotNull);
    expect(result!.storage[12], closeTo(-120, 0.5));
  });

  test('clamps so the scaled child still covers the viewport', () {
    // scale 2, last row: pulling it to the band would expose the child's
    // bottom edge, so translation is clamped to extent*(1-scale) = -300.
    final result = transformToRevealCell(
      current: scaled(2),
      viewport: viewport,
      cellSize: cellSize,
      rows: rows,
      cols: cols,
      cell: (9, 0),
      margin: margin,
    );

    expect(result, isNotNull);
    expect(result!.storage[13], closeTo(-300, 0.5));
    // Child bottom (scale*childHeight + ty) stays at the viewport bottom.
    expect(2 * 300 + result.storage[13], closeTo(300, 0.5));
  });

  test('preserves scale and the unaffected axis', () {
    final result = transformToRevealCell(
      current: scaled(2, 0, 0),
      viewport: viewport,
      cellSize: cellSize,
      rows: rows,
      cols: cols,
      cell: (6, 2), // only y is out of band; x (centre 75 -> 150) is inside
      margin: margin,
    );

    expect(result!.storage[0], closeTo(2, 0.0001)); // scale preserved
    expect(result.storage[12], closeTo(0, 0.5)); // x translation unchanged
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/gameplay/presentation/crossword_screen/keyboard_follow_test.dart`
Expected: FAIL — `transformToRevealCell` is not defined.

- [ ] **Step 3: Implement** — create `keyboard_follow.dart`:

```dart
import 'package:flutter/widgets.dart';

/// The transform that brings [cell] into a comfortable band of the [viewport],
/// or null when the cell is already comfortably visible. Only the translation
/// changes; the current scale (and any pan on the axis that is already fine)
/// is preserved.
///
/// Pure geometry. The grid is centred inside an `InteractiveViewer` child whose
/// size equals the viewport, so a cell's centre in child-space depends only on
/// the viewport size, [cellSize] and the cell's row/col (the symmetric border
/// and padding cancel out). The viewer only scales and translates — no rotation
/// — so the current matrix is read as scale `storage[0]` and translation
/// `storage[12]`/`storage[13]`.
Matrix4? transformToRevealCell({
  required Matrix4 current,
  required Size viewport,
  required double cellSize,
  required int rows,
  required int cols,
  required (int, int) cell,
  required double margin,
}) {
  final scale = current.storage[0];
  final tx = current.storage[12];
  final ty = current.storage[13];

  final (row, col) = cell;
  final cx =
      (viewport.width - cols * cellSize) / 2 + col * cellSize + cellSize / 2;
  final cy =
      (viewport.height - rows * cellSize) / 2 + row * cellSize + cellSize / 2;

  final newTx = _revealAxis(
    center: cx,
    scale: scale,
    translation: tx,
    extent: viewport.width,
    margin: margin,
  );
  final newTy = _revealAxis(
    center: cy,
    scale: scale,
    translation: ty,
    extent: viewport.height,
    margin: margin,
  );

  const epsilon = 0.5;
  if ((newTx - tx).abs() < epsilon && (newTy - ty).abs() < epsilon) return null;

  return Matrix4.copy(current)..setTranslationRaw(newTx, newTy, 0);
}

/// The translation along one axis that keeps the cell centre inside the band
/// `[m, extent - m]`, clamped so the scaled child still covers the viewport.
double _revealAxis({
  required double center,
  required double scale,
  required double translation,
  required double extent,
  required double margin,
}) {
  final m = margin < extent / 3 ? margin : extent / 3;
  final viewportPos = scale * center + translation;

  var target = translation;
  if (viewportPos < m) {
    target = m - scale * center;
  } else if (viewportPos > extent - m) {
    target = (extent - m) - scale * center;
  }

  // The child extent equals the viewport extent, so the scaled child spans
  // `scale * extent`; to keep it covering the viewport the translation must
  // stay within [extent * (1 - scale), 0].
  final min = extent * (1 - scale);
  if (target < min) target = min;
  if (target > 0) target = 0;
  return target;
}
```

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/gameplay/presentation/crossword_screen/keyboard_follow_test.dart && flutter analyze`
Expected: ALL PASS, no analyzer issues.

- [ ] **Step 5: Commit**

```bash
git add packages/crossword_ui/lib/gameplay/presentation/crossword_screen/keyboard_follow.dart packages/crossword_ui/test/gameplay/presentation/crossword_screen/keyboard_follow_test.dart
git commit -m "feat(ui): pure transformToRevealCell geometry for cell visibility"
```

---

### Task 2: Cubit wiring — `setLayout`, ensure-visible, `_apply` hook

**Files:**
- Modify: `packages/crossword_ui/lib/gameplay/presentation/crossword_screen/cubit/crossword_cubit.dart`
- Test: `packages/crossword_ui/test/gameplay/presentation/crossword_screen/cubit/crossword_cubit_test.dart`

All commands run from `packages/crossword_ui`.

- [ ] **Step 1: Write the failing tests** — append these to the existing `main()` in `crossword_cubit_test.dart` (the file already defines `buildCubit(CrosswordPuzzle)` and `_puzzle()`, a 2-row × 4-col grid whose answer cells include `(0,1)`, `(0,2)`, `(0,3)`, `(1,3)`):

```dart
  group('keyboard-aware auto-pan', () {
    // viewport 80x40 with 4 cols / 2 rows => fit cellSize 20, so the grid fills
    // the viewport and cell (r,c) centre is (c*20+10, r*20+10).
    test('setLayout stores metrics without emitting a new state', () {
      final emissions = <CrosswordState>[];
      final sub = cubit.stream.listen(emissions.add);
      addTearDown(sub.cancel);

      cubit.setLayout(viewport: const Size(80, 40), cellSize: 20);

      expect(emissions, isEmpty);
    });

    test('selecting an off-screen cell while zoomed pans it into view', () {
      cubit.setLayout(viewport: const Size(80, 40), cellSize: 20);
      cubit.transformationController.value = Matrix4.identity()..scale(2.0);

      cubit.selectCell(0, 3); // centre x = 70 -> viewport x = 140, off-screen

      // ty stays 0 (row 0 visible); tx clamps to 80*(1-2) = -80, putting the
      // cell at the right margin.
      expect(cubit.transformationController.value.storage[12], closeTo(-80, 0.5));
    });

    test('selecting a cell at fit scale does not move the view', () {
      cubit.setLayout(viewport: const Size(80, 40), cellSize: 20);

      cubit.selectCell(0, 1);

      expect(cubit.transformationController.value, Matrix4.identity());
    });

    testWidgets('the selected cell stays within the viewport across a resize',
        (tester) async {
      cubit.setLayout(viewport: const Size(80, 80), cellSize: 20);
      cubit.transformationController.value = Matrix4.identity()..scale(2.0);
      cubit.selectCell(0, 3); // revealed against the 80x80 viewport

      // Simulate the keyboard shrinking the body to half height. This is a
      // viewport change with a cell selected, so setLayout schedules a
      // post-frame visibility check; tester.pump() flushes it.
      cubit.setLayout(viewport: const Size(80, 40), cellSize: 20);
      await tester.pump();

      // Invariant: the selected cell's centre sits inside the 80x40 viewport.
      final m = cubit.transformationController.value;
      final scale = m.storage[0];
      const cx = 70.0; // (80 - 4*20)/2 + 3*20 + 10
      const cy = 10.0; // (40 - 2*20)/2 + 0*20 + 10
      expect(scale * cx + m.storage[12], inInclusiveRange(0, 80));
      expect(scale * cy + m.storage[13], inInclusiveRange(0, 40));
    });
  });
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/gameplay/presentation/crossword_screen/cubit/crossword_cubit_test.dart`
Expected: COMPILE ERROR — `setLayout` is not defined.

- [ ] **Step 3: Implement.** In `crossword_cubit.dart`:

Add the import alongside the other local imports (after `import '../crossword_engine.dart';`):

```dart
import '../keyboard_follow.dart';
```

Add these fields right after `final CrosswordEngine _engine;`:

```dart
  /// Latest grid layout from the player's LayoutBuilder, used to keep the
  /// selected cell visible. Plain fields — view geometry, never emitted.
  Size? _viewportSize;
  double? _cellSize;
```

Add these methods (e.g. just before `_apply`):

```dart
  /// Record the current viewport size and cell size from the player's
  /// LayoutBuilder. When the viewport changes while a cell is selected (the
  /// soft keyboard opens and the body resizes), schedule a visibility check
  /// for after this frame — assigning the transform during build would
  /// re-enter the InteractiveViewer's listener.
  void setLayout({required Size viewport, required double cellSize}) {
    final changed = _viewportSize != viewport || _cellSize != cellSize;
    _viewportSize = viewport;
    _cellSize = cellSize;
    if (changed && state.selectedCell != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _ensureSelectedCellVisible(),
      );
    }
  }

  /// Nudge the grid so the selected cell sits in a comfortable band of the
  /// visible viewport, if metrics and a selection are known. No-op otherwise.
  void _ensureSelectedCellVisible() {
    final viewport = _viewportSize;
    final cellSize = _cellSize;
    final sel = state.selectedCell;
    if (viewport == null || cellSize == null || sel == null) return;

    final next = transformToRevealCell(
      current: transformationController.value,
      viewport: viewport,
      cellSize: cellSize,
      rows: state.puzzle.rows,
      cols: state.puzzle.cols,
      cell: sel,
      margin: cellSize,
    );
    if (next != null) transformationController.value = next;
  }
```

In `_apply`, add the visibility hook as the last statement (after the `_feedback(...)` call):

```dart
    if (next.selectedCell != prev.selectedCell) _ensureSelectedCellVisible();
```

- [ ] **Step 4: Run to verify pass**

Run: `flutter test && flutter analyze`
Expected: ALL PASS, no analyzer issues.

- [ ] **Step 5: Commit**

```bash
git add packages/crossword_ui/lib/gameplay/presentation/crossword_screen/cubit/crossword_cubit.dart packages/crossword_ui/test/gameplay/presentation/crossword_screen/cubit/crossword_cubit_test.dart
git commit -m "feat(cubit): keep the selected cell visible on selection and keyboard"
```

---

### Task 3: Player wiring — feed layout metrics to the cubit

**Files:**
- Modify: `packages/crossword_ui/lib/gameplay/presentation/crossword_screen/crossword_player.dart`

All commands run from `packages/crossword_ui`.

- [ ] **Step 1: Implement.** In `_CrosswordPlayerBody.build`, inside the `LayoutBuilder` builder, immediately after the line `final cellSize = min(cellSizeByWidth, cellSizeByHeight);`, add:

```dart
                cubit.setLayout(
                  viewport: Size(constraints.maxWidth, constraints.maxHeight),
                  cellSize: cellSize,
                );
```

(`cubit` is already in scope as `final cubit = context.read<CrosswordCubit>();` at the top of `build`. No import changes — `Size` comes from the existing `package:flutter/material.dart` import.)

- [ ] **Step 2: Run the existing player + package tests to verify no regression**

Run: `flutter test`
Expected: ALL PASS — the existing `CrosswordPlayer` render tests now exercise `setLayout` and must stay green.

- [ ] **Step 3: Analyze**

Run: `flutter analyze`
Expected: No issues found.

- [ ] **Step 4: Commit**

```bash
git add packages/crossword_ui/lib/gameplay/presentation/crossword_screen/crossword_player.dart
git commit -m "feat(ui): feed grid layout metrics to the cubit for auto-pan"
```

---

### Task 4: Full-workspace verification

All commands run from the repo root `/Users/lbofhn/AndroidStudioProjects/Crosswords`.

- [ ] **Step 1: Analyze the whole workspace**

Run: `flutter analyze`
Expected: No issues found.

- [ ] **Step 2: Run every suite**

```bash
(cd packages/crossword_core && flutter test) && \
(cd packages/crossword_ui && flutter test) && \
(cd apps/mobile && flutter test) && \
(cd apps/web && flutter test)
```
Expected: ALL PASS.

- [ ] **Step 3: Confirm nothing is left uncommitted**

Run: `git status --short`
Expected: empty.
