# Zoomable & Pannable Crossword Grid Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users pinch-zoom (0.5x–4x) and drag-pan the crossword grid, with an app-bar button to reset to the fit-width default, while tap-to-select and keyboard typing keep working.

**Architecture:** Wrap the existing `Table`+`Stack` grid in Flutter's `InteractiveViewer` (`constrained: false`). Move the `cellSize` calculation out of `CrosswordGrid` into an outer `LayoutBuilder` in the screen so scale 1.0 fills viewport width exactly. A `TransformationController` lives in `CrosswordCubit` (per CLAUDE.md: controllers belong in the cubit, disposed in `close()`), with a `resetView()` method driven by an app-bar icon.

**Tech Stack:** Flutter, flutter_bloc (Cubit), flutter_test (plain `test()` style — no bloc_test in this repo).

---

## File Structure

- `lib/gameplay/presentation/crossword_screen/cubit/crossword_cubit.dart` — add `TransformationController transformationController`, `resetView()`, dispose in `close()`.
- `lib/gameplay/presentation/crossword_screen/widgets/crossword_grid.dart` — accept `cellSize` as a constructor param, remove internal `LayoutBuilder`.
- `lib/gameplay/presentation/crossword_screen/crossword_screen.dart` — outer `LayoutBuilder` computes base `cellSize`; wrap grid in `InteractiveViewer`; add reset icon to `AppBar.actions`.
- `lib/common/data/constants/strings.dart` — add `resetViewTooltip` string.
- `test/gameplay/presentation/crossword_screen/cubit/crossword_cubit_test.dart` — add tests for `resetView()` and controller disposal.

---

## Task 1: Add TransformationController + resetView() to the cubit

**Files:**
- Modify: `lib/gameplay/presentation/crossword_screen/cubit/crossword_cubit.dart`
- Test: `test/gameplay/presentation/crossword_screen/cubit/crossword_cubit_test.dart`

- [ ] **Step 1: Write the failing tests**

Add these two tests inside the existing top-level `main()` group block in `crossword_cubit_test.dart` (append them before the final closing `}` of `main`). They reuse the existing `_buildTestPuzzle()` helper. Note `package:flutter/widgets.dart` is needed for `Matrix4` — add the import at the top of the test file if not present:

```dart
// add to imports at top of file:
import 'package:flutter/widgets.dart';
```

```dart
  test('resetView resets the transformation to identity', () {
    final cubit = CrosswordCubit(puzzle: _buildTestPuzzle());

    // Simulate a zoomed/panned state.
    cubit.transformationController.value = Matrix4.identity()
      ..scale(2.0)
      ..translate(30.0, 40.0);
    expect(
      cubit.transformationController.value,
      isNot(equals(Matrix4.identity())),
    );

    cubit.resetView();

    expect(cubit.transformationController.value, equals(Matrix4.identity()));
    cubit.close();
  });

  test('close disposes the transformation controller without throwing', () async {
    final cubit = CrosswordCubit(puzzle: _buildTestPuzzle());
    await cubit.close();
    // Using a disposed ChangeNotifier throws; confirm it was disposed.
    expect(
      () => cubit.transformationController.addListener(() {}),
      throwsA(isA<Object>()),
    );
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/gameplay/presentation/crossword_screen/cubit/crossword_cubit_test.dart`
Expected: FAIL — `transformationController` / `resetView` are not defined on `CrosswordCubit`.

- [ ] **Step 3: Implement on the cubit**

In `crossword_cubit.dart`, the file already imports `package:flutter/widgets.dart` (which provides `TransformationController` and `Matrix4`). Add the field next to `focusNode`:

```dart
class CrosswordCubit extends Cubit<CrosswordState> {
  final FocusNode focusNode = FocusNode();
  final TransformationController transformationController =
      TransformationController();
```

Add the method (place it just above `close()`):

```dart
  /// Snap the grid back to the default fit-width, un-panned view.
  void resetView() {
    transformationController.value = Matrix4.identity();
  }
```

Update `close()` to dispose the controller:

```dart
  @override
  Future<void> close() {
    focusNode.dispose();
    transformationController.dispose();
    return super.close();
  }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/gameplay/presentation/crossword_screen/cubit/crossword_cubit_test.dart`
Expected: PASS (all tests, including the pre-existing ones).

- [ ] **Step 5: Commit**

```bash
git add lib/gameplay/presentation/crossword_screen/cubit/crossword_cubit.dart test/gameplay/presentation/crossword_screen/cubit/crossword_cubit_test.dart
git commit -m "feat: add TransformationController and resetView to CrosswordCubit"
```

---

## Task 2: Refactor CrosswordGrid to accept cellSize as a parameter

**Files:**
- Modify: `lib/gameplay/presentation/crossword_screen/widgets/crossword_grid.dart`

This removes the internal `LayoutBuilder` so the grid renders at a fixed, externally-computed `cellSize` (required for `InteractiveViewer(constrained: false)`, which gives the child unbounded width). No test here — it's a pure widget refactor verified by `flutter analyze` and Task 4's manual check.

- [ ] **Step 1: Replace the `build` method**

In `crossword_grid.dart`, add a `cellSize` field and replace the `LayoutBuilder`-based `build` with a direct build. Replace the class fields + `build` method (lines 14–47) with:

```dart
class CrosswordGrid extends StatelessWidget {
  final CrosswordState state;
  final double cellSize;

  const CrosswordGrid({
    required this.state,
    required this.cellSize,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    const frameWidth = 2.0;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.frame, width: frameWidth),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          _buildTable(context, cellSize),
          ..._buildImageOverlays(cellSize),
        ],
      ),
    );
  }
```

Leave `_buildTable`, `_buildCell`, and `_buildImageOverlays` exactly as they are — they already take `cellSize` as a parameter.

- [ ] **Step 2: Verify it analyzes cleanly**

Run: `flutter analyze lib/gameplay/presentation/crossword_screen/widgets/crossword_grid.dart`
Expected: No errors. (Callers will be fixed in Task 3 — the screen still passes the old constructor, so a full `flutter analyze` will show one error at the call site until Task 3. That is expected; do not "fix" it here.)

- [ ] **Step 3: Commit**

```bash
git add lib/gameplay/presentation/crossword_screen/widgets/crossword_grid.dart
git commit -m "refactor: make CrosswordGrid take cellSize as a parameter"
```

---

## Task 3: Add the reset-view string

**Files:**
- Modify: `lib/common/data/constants/strings.dart`

- [ ] **Step 1: Add the string**

In `strings.dart`, add inside the `Strings` class (after `imageClueLabel`):

```dart
  /// Tooltip/semantics label for the app-bar button that resets zoom & pan.
  static const String resetViewTooltip = 'Återställ vy';
```

- [ ] **Step 2: Verify it analyzes cleanly**

Run: `flutter analyze lib/common/data/constants/strings.dart`
Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/common/data/constants/strings.dart
git commit -m "feat: add resetViewTooltip string"
```

---

## Task 4: Wire InteractiveViewer + reset button into the screen

**Files:**
- Modify: `lib/gameplay/presentation/crossword_screen/crossword_screen.dart`

- [ ] **Step 1: Add the app-bar reset action**

In `crossword_screen.dart`, in `CrosswordScreenContent.build`, the `cubit` is already read via `final cubit = context.read<CrosswordCubit>();`. Add an `actions` list to the existing `AppBar` (insert after the `elevation: 0,` line):

```dart
        actions: [
          IconButton(
            icon: const Icon(Icons.fit_screen),
            tooltip: Strings.resetViewTooltip,
            onPressed: cubit.resetView,
          ),
        ],
```

- [ ] **Step 2: Replace the body's grid with a LayoutBuilder + InteractiveViewer**

Replace the `child:` of the `Padding` (currently `child: CrosswordGrid(state: state)`, around lines 72–76) so the whole `Center`/`Padding` block becomes:

```dart
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              const frameWidth = 2.0;
              const padding = 16.0;
              final viewportWidth = constraints.maxWidth - padding * 2;
              final cellSize =
                  (viewportWidth - frameWidth * 2) / state.puzzle.cols;
              return InteractiveViewer(
                transformationController: cubit.transformationController,
                minScale: 0.5,
                maxScale: 4.0,
                constrained: false,
                boundaryMargin: const EdgeInsets.all(64),
                child: Padding(
                  padding: const EdgeInsets.all(padding),
                  child: CrosswordGrid(state: state, cellSize: cellSize),
                ),
              );
            },
          ),
        ),
```

This replaces the previous `Center` + `Padding` + `CrosswordGrid`. The `Center` is dropped because `InteractiveViewer(constrained: false)` positions its child itself; the grid starts at the top-left and fills width at scale 1.0.

- [ ] **Step 3: Verify the whole project analyzes cleanly**

Run: `flutter analyze`
Expected: No errors (the Task 2 call-site error is now resolved).

- [ ] **Step 4: Run the full test suite**

Run: `flutter test`
Expected: PASS.

- [ ] **Step 5: Manual verification**

Run: `flutter run` (or hot-reload). Confirm:
- At launch the grid fills the screen width (scale 1.0), same as before.
- Pinch-zoom in/out works and is bounded between roughly half-size and 4x.
- Single-finger drag pans; a grid taller than the screen can be panned vertically.
- Tapping a cell still selects it and the keyboard types into the selected cell while zoomed/panned.
- The app-bar `fit_screen` icon snaps the view back to fit-width, un-panned.

- [ ] **Step 6: Commit**

```bash
git add lib/gameplay/presentation/crossword_screen/crossword_screen.dart
git commit -m "feat: make crossword grid zoomable and pannable with reset button"
```

---

## Notes / Out of scope

- **Auto-pan to follow the selected cell** during keyboard auto-advance is intentionally deferred (YAGNI) per the spec. If added later, drive `cubit.transformationController` from selection updates in `onLetterInput`.
