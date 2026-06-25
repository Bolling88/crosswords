# Perfect Clue-Cell Arrows Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Render diagonal-entry clue arrows and two-clue boxes from generated puzzles correctly — proper corner arrows for offset clues, and a divider-split box with one arrow per compartment.

**Architecture:** Extend the `ArrowShape` enum with diagonal-entry variants and generalise `ArrowShapeResolver` to detect diagonal word starts (throwing on truly malformed geometry). Order a clue cell's arrows *top-first by word-start row* at map time (in both `GeneratedPuzzleMapper` and `PuzzleResolver`) so the renderer never needs slot geometry. Replace the Material-icon arrow rendering with a scoped `CustomPainter` that draws every shape from one geometric description, and split two-clue cells into divider-separated compartments.

**Tech Stack:** Flutter 3.41.9, Dart, flutter_test. Packages: `crossword_core` (domain + resolver), `crossword_api` (generated mapper), `crossword_ui` (rendering).

## Global Constraints

- **Flutter 3.41.9.**
- **ALL widgets MUST be `StatelessWidget`** — no `StatefulWidget`, `setState`, `initState`, `dispose`, `addListener` in widgets.
- **CustomPainter exception (scoped):** the grid structure stays widget-based (Table + Stack); a `CustomPainter` is allowed **only** for drawing the arrow glyphs inside a clue cell.
- **NEVER use the null-assertion operator `!`** — capture a local and null-check it instead.
- **Always use `AppColors` constants** — `AppColors.ink` for arrow ink, `AppColors.gridLine` for the divider/border. Never hardcode colors. Use `withAlpha()` not `withOpacity()`.
- **`prefer_single_quotes`, `require_trailing_commas`, `prefer_const_constructors`, `prefer_const_declarations`, `prefer_final`.**
- Private fields/methods prefixed with `_`. English code comments.
- Run tests from each package's own directory (`packages/<pkg>`), not the repo root.

---

### Task 1: Diagonal-entry shapes in `ArrowShapeResolver`

**Files:**
- Modify: `packages/crossword_core/lib/gameplay/domain/entities/arrow_shape.dart`
- Modify: `packages/crossword_core/lib/gameplay/domain/services/arrow_shape_resolver.dart`
- Test: `packages/crossword_core/test/gameplay/domain/services/arrow_shape_resolver_test.dart`

**Interfaces:**
- Consumes: `Direction` (`{right, down}`), existing `ArrowShape` values.
- Produces: 8 new `ArrowShape` values (`diagonalSwThenRight`, `diagonalNwThenRight`, `diagonalSeThenRight`, `diagonalNeThenRight`, `diagonalSwThenDown`, `diagonalNwThenDown`, `diagonalSeThenDown`, `diagonalNeThenDown`); `ArrowShapeResolver.resolve(...)` keeps its signature `({required int clueRow, required int clueCol, required int startRow, required int startCol, required Direction base}) → ArrowShape` and now returns diagonal shapes for diagonal starts and **throws `ArgumentError`** for non-adjacent, non-diagonal geometry.

- [ ] **Step 1: Write the failing tests**

Append inside the existing `group('ArrowShapeResolver', ...)` in `packages/crossword_core/test/gameplay/domain/services/arrow_shape_resolver_test.dart`:

```dart
    // Diagonal-entry cases taken from the real 9x9 generation fixture.
    test('start diagonally SW of clue, running right → diagonalSwThenRight', () {
      expect(
        ArrowShapeResolver.resolve(
          clueRow: 0, clueCol: 7, startRow: 1, startCol: 6,
          base: Direction.right,
        ),
        ArrowShape.diagonalSwThenRight,
      );
    });

    test('start diagonally SW of clue, running down → diagonalSwThenDown', () {
      expect(
        ArrowShapeResolver.resolve(
          clueRow: 0, clueCol: 4, startRow: 1, startCol: 3,
          base: Direction.down,
        ),
        ArrowShape.diagonalSwThenDown,
      );
    });

    test('start diagonally NW of clue, running down → diagonalNwThenDown', () {
      expect(
        ArrowShapeResolver.resolve(
          clueRow: 5, clueCol: 7, startRow: 4, startCol: 6,
          base: Direction.down,
        ),
        ArrowShape.diagonalNwThenDown,
      );
    });

    test('non-adjacent, non-diagonal start throws ArgumentError', () {
      expect(
        () => ArrowShapeResolver.resolve(
          clueRow: 0, clueCol: 0, startRow: 2, startCol: 0,
          base: Direction.right,
        ),
        throwsArgumentError,
      );
    });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd packages/crossword_core && flutter test test/gameplay/domain/services/arrow_shape_resolver_test.dart`
Expected: FAIL — `diagonalSwThenRight` (etc.) undefined; the throw test fails because the current resolver falls back instead of throwing.

- [ ] **Step 3: Add the diagonal enum values**

Append to the `ArrowShape` enum in `packages/crossword_core/lib/gameplay/domain/entities/arrow_shape.dart` (before the closing `}`), keeping the trailing comma:

```dart
  /// Word starts in the diagonally below-left cell, then runs right.
  diagonalSwThenRight,

  /// Word starts in the diagonally above-left cell, then runs right.
  diagonalNwThenRight,

  /// Word starts in the diagonally below-right cell, then runs right.
  diagonalSeThenRight,

  /// Word starts in the diagonally above-right cell, then runs right.
  diagonalNeThenRight,

  /// Word starts in the diagonally below-left cell, then runs down.
  diagonalSwThenDown,

  /// Word starts in the diagonally above-left cell, then runs down.
  diagonalNwThenDown,

  /// Word starts in the diagonally below-right cell, then runs down.
  diagonalSeThenDown,

  /// Word starts in the diagonally above-right cell, then runs down.
  diagonalNeThenDown,
```

- [ ] **Step 4: Generalise the resolver**

Replace the body of `ArrowShapeResolver.resolve` in `packages/crossword_core/lib/gameplay/domain/services/arrow_shape_resolver.dart` with:

```dart
  static ArrowShape resolve({
    required int clueRow,
    required int clueCol,
    required int startRow,
    required int startCol,
    required Direction base,
  }) {
    final dr = startRow - clueRow;
    final dc = startCol - clueCol;

    // Diagonal start: the clue sits at a corner of the word's start cell.
    if (dr.abs() == 1 && dc.abs() == 1) {
      return _diagonal(dr, dc, base);
    }

    if (base == Direction.right) {
      if (dr == 0 && dc == 1) return ArrowShape.straightRight;
      if (dr == -1 && dc == 0) return ArrowShape.bentUpThenRight;
      if (dr == 1 && dc == 0) return ArrowShape.bentDownThenRight;
      throw ArgumentError(
        'Rightward word start ($dr,$dc) is not adjacent to its clue',
      );
    }
    if (dr == 1 && dc == 0) return ArrowShape.straightDown;
    if (dr == 0 && dc == -1) return ArrowShape.bentLeftThenDown;
    if (dr == 0 && dc == 1) return ArrowShape.bentRightThenDown;
    throw ArgumentError(
      'Downward word start ($dr,$dc) is not adjacent to its clue',
    );
  }

  /// Maps a diagonal start offset (start − clue) and travel direction to the
  /// matching diagonal shape. Corner names describe where the start cell sits:
  /// dr=+1 below (S), dr=-1 above (N); dc=+1 right (E), dc=-1 left (W).
  static ArrowShape _diagonal(int dr, int dc, Direction base) {
    if (base == Direction.right) {
      if (dr == 1 && dc == -1) return ArrowShape.diagonalSwThenRight;
      if (dr == -1 && dc == -1) return ArrowShape.diagonalNwThenRight;
      if (dr == 1 && dc == 1) return ArrowShape.diagonalSeThenRight;
      return ArrowShape.diagonalNeThenRight; // dr == -1 && dc == 1
    }
    if (dr == 1 && dc == -1) return ArrowShape.diagonalSwThenDown;
    if (dr == -1 && dc == -1) return ArrowShape.diagonalNwThenDown;
    if (dr == 1 && dc == 1) return ArrowShape.diagonalSeThenDown;
    return ArrowShape.diagonalNeThenDown; // dr == -1 && dc == 1
  }
```

- [ ] **Step 5: Run the full core test suite**

Run: `cd packages/crossword_core && flutter test`
Expected: PASS — the four new resolver tests pass and all existing resolver/puzzle_resolver tests still pass (the explicit adjacent cases preserve prior behavior; only impossible geometry now throws).

- [ ] **Step 6: Commit**

```bash
git add packages/crossword_core/lib/gameplay/domain/entities/arrow_shape.dart \
        packages/crossword_core/lib/gameplay/domain/services/arrow_shape_resolver.dart \
        packages/crossword_core/test/gameplay/domain/services/arrow_shape_resolver_test.dart
git commit -m "feat(core): resolve diagonal-entry clue arrow shapes"
```

---

### Task 2: Top-first arrow ordering in `GeneratedPuzzleMapper`

**Files:**
- Modify: `packages/crossword_api/lib/src/generated_puzzle_mapper.dart` (`_arrowsFor`)
- Test: `packages/crossword_api/test/generated_puzzle_mapper_test.dart`

**Interfaces:**
- Consumes: `ArrowShapeResolver.resolve` (Task 1, including diagonal shapes), `GenerationGridCellDto.clueTags`, `GenerationSlotDto.{startRow,startCol,clueRow,clueCol,direction,slotId}`.
- Produces: `ClueCell.arrows` ordered **top-first** — `arrows[0]` is the clue whose word starts at the smaller `startRow` (tie broken by smaller `startCol`).

- [ ] **Step 1: Write the failing tests**

Append inside `main()` in `packages/crossword_api/test/generated_puzzle_mapper_test.dart`:

```dart
  // Cell (5,0) carries two rightward clues: slot 6 starts at row 4 (above),
  // slot 8 starts at row 5. Top-first ordering puts slot 6 first.
  test('two-clue box (5,0) orders arrows top-first by word start', () {
    final clue = puzzle.cells[(5, 0)] as ClueCell;
    expect(clue.arrows.length, 2);
    expect(clue.arrows[0].wordId, '6');
    expect(clue.arrows[1].wordId, '8');
  });

  // Cell (5,7): slot 21 starts at row 4 (above), slot 23 at row 6.
  test('two-clue box (5,7) orders arrows top-first by word start', () {
    final clue = puzzle.cells[(5, 7)] as ClueCell;
    expect(clue.arrows.length, 2);
    expect(clue.arrows[0].wordId, '21');
    expect(clue.arrows[1].wordId, '23');
  });

  // Clue (0,7) sits diagonally NE of its word start (1,6); the word runs right.
  test('diagonal clue (0,7) resolves to diagonalSwThenRight', () {
    final clue = puzzle.cells[(0, 7)] as ClueCell;
    final arrow = clue.arrows.firstWhere((a) => a.wordId == '1');
    expect(arrow.shape, ArrowShape.diagonalSwThenRight);
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd packages/crossword_api && flutter test test/generated_puzzle_mapper_test.dart`
Expected: FAIL — ordering tests fail (current order follows tag order, not start row) and/or the diagonal test fails if Task 1 changes aren't on the path; the `(0,7)` test now expects `diagonalSwThenRight` rather than the old fallback.

- [ ] **Step 3: Sort tags top-first in `_arrowsFor`**

Replace the `_arrowsFor` method in `packages/crossword_api/lib/src/generated_puzzle_mapper.dart` with:

```dart
  /// Builds [ClueArrow]s for a clue cell, throwing on a missing slot. Arrows
  /// are ordered top-first (smaller word-start row, then col) so the renderer
  /// can split a two-clue box into top/bottom compartments without slot data.
  static List<ClueArrow> _arrowsFor(
    GenerationGridCellDto cell,
    Map<int, GenerationSlotDto> slotById,
  ) {
    final entries = <(GenerationSlotDto, ClueArrow)>[];
    for (final tag in cell.clueTags) {
      final slot = slotById[tag.id];
      if (slot == null) {
        throw CrosswordGenerationException(
          'Clue tag ${tag.id} references a missing slot',
        );
      }
      final dir = _direction(slot.direction);
      entries.add((
        slot,
        ClueArrow(
          direction: dir,
          shape: ArrowShapeResolver.resolve(
            clueRow: slot.clueRow,
            clueCol: slot.clueCol,
            startRow: slot.startRow,
            startCol: slot.startCol,
            base: dir,
          ),
          wordId: slot.slotId.toString(),
        ),
      ));
    }
    entries.sort((a, b) {
      final byRow = a.$1.startRow.compareTo(b.$1.startRow);
      return byRow != 0 ? byRow : a.$1.startCol.compareTo(b.$1.startCol);
    });
    return [for (final entry in entries) entry.$2];
  }
```

- [ ] **Step 4: Run the full api test suite**

Run: `cd packages/crossword_api && flutter test`
Expected: PASS — the three new tests pass; the existing `(0,0) → bentDownThenRight` test still passes (that start is adjacent, not diagonal).

- [ ] **Step 5: Commit**

```bash
git add packages/crossword_api/lib/src/generated_puzzle_mapper.dart \
        packages/crossword_api/test/generated_puzzle_mapper_test.dart
git commit -m "feat(api): order generated clue arrows top-first by word start"
```

---

### Task 3: Top-first arrow ordering in `PuzzleResolver`

**Files:**
- Modify: `packages/crossword_core/lib/gameplay/data/puzzle_resolver.dart` (`ClueCellDto` branch)
- Test: `packages/crossword_core/test/gameplay/data/puzzle_resolver_test.dart`

**Interfaces:**
- Consumes: `ClueCellDto.{rightWordId,rightStart,rightClueId,right,downWordId,downStart,downClueId,down}`, `ArrowShapeResolver.resolve`, `_resolveWord` (unchanged).
- Produces: `ClueCell.arrows` ordered **top-first** for bundled puzzles, same contract as Task 2.

- [ ] **Step 1: Write the failing test**

Append inside `main()` in `packages/crossword_core/test/gameplay/data/puzzle_resolver_test.dart`:

```dart
  test('two-clue cell orders arrows top-first by word start row', () {
    final dto = _puzzle([
      [
        const ClueCellDto(
          rightWordId: 'across',
          rightStart: PositionDto(col: 1, row: 0),
          downWordId: 'down',
          downStart: PositionDto(col: 0, row: 1),
        ),
        _a('A'),
      ],
      [
        _a('B'),
        _block,
      ],
    ]);

    final clue = PuzzleResolver.resolve(dto).cells[(0, 0)] as ClueCell;
    expect(clue.arrows.length, 2);
    expect(clue.arrows.first.wordId, 'across'); // start row 0 (top)
    expect(clue.arrows.last.wordId, 'down'); // start row 1 (bottom)
  });
```

- [ ] **Step 2: Run test to verify it passes-by-accident check**

Run: `cd packages/crossword_core && flutter test test/gameplay/data/puzzle_resolver_test.dart`
Expected: PASS already (current right-then-down order happens to match here). This is a guard test — proceed to make the ordering explicit so it cannot regress.

- [ ] **Step 3: Make ordering explicit in the `ClueCellDto` branch**

In `packages/crossword_core/lib/gameplay/data/puzzle_resolver.dart`, replace the entire `case ClueCellDto():` block (the one that builds `arrows` and assigns `domainCells[(r, c)] = ClueCell(arrows: arrows);`) with:

```dart
          case ClueCellDto():
            // (startRow, startCol, arrow) so we can order arrows top-first.
            final entries = <(int, int, ClueArrow)>[];

            final rightWordId = cell.rightWordId;
            final rightStart = cell.rightStart;
            if (rightWordId != null && rightStart != null) {
              words.add(_resolveWord(
                id: rightWordId,
                clueId: cell.rightClueId,
                clueText: cell.right,
                start: rightStart,
                base: Direction.right,
                answerAt: answerAt,
                separatorEdges: separatorEdges,
              ));
              entries.add((
                rightStart.row,
                rightStart.col,
                ClueArrow(
                  direction: Direction.right,
                  shape: ArrowShapeResolver.resolve(
                    clueRow: r,
                    clueCol: c,
                    startRow: rightStart.row,
                    startCol: rightStart.col,
                    base: Direction.right,
                  ),
                  wordId: rightWordId,
                ),
              ));
            }

            final downWordId = cell.downWordId;
            final downStart = cell.downStart;
            if (downWordId != null && downStart != null) {
              words.add(_resolveWord(
                id: downWordId,
                clueId: cell.downClueId,
                clueText: cell.down,
                start: downStart,
                base: Direction.down,
                answerAt: answerAt,
                separatorEdges: separatorEdges,
              ));
              entries.add((
                downStart.row,
                downStart.col,
                ClueArrow(
                  direction: Direction.down,
                  shape: ArrowShapeResolver.resolve(
                    clueRow: r,
                    clueCol: c,
                    startRow: downStart.row,
                    startCol: downStart.col,
                    base: Direction.down,
                  ),
                  wordId: downWordId,
                ),
              ));
            }

            entries.sort((a, b) {
              final byRow = a.$1.compareTo(b.$1);
              return byRow != 0 ? byRow : a.$2.compareTo(b.$2);
            });
            domainCells[(r, c)] =
                ClueCell(arrows: [for (final entry in entries) entry.$3]);
```

Note: this also removes the two `!` operators the old block used (`cell.rightStart!`, `cell.downWordId!`, …), complying with the no-`!` rule.

- [ ] **Step 4: Run the full core test suite**

Run: `cd packages/crossword_core && flutter test`
Expected: PASS — the new guard test plus all existing puzzle_resolver tests (single-arrow shapes, two-clue count, seeds, redirects) still pass.

- [ ] **Step 5: Commit**

```bash
git add packages/crossword_core/lib/gameplay/data/puzzle_resolver.dart \
        packages/crossword_core/test/gameplay/data/puzzle_resolver_test.dart
git commit -m "feat(core): order bundled clue arrows top-first by word start"
```

---

### Task 4: `ClueArrowPainter` (CustomPainter for arrow glyphs)

**Files:**
- Create: `packages/crossword_ui/lib/gameplay/presentation/crossword_screen/widgets/clue_arrow_painter.dart`
- Test: `packages/crossword_ui/test/gameplay/presentation/crossword_screen/widgets/clue_arrow_painter_test.dart`

**Interfaces:**
- Consumes: `ArrowShape` (all 14 values, from `package:crossword_core/crossword_core.dart`).
- Produces:
  - `({Offset entry, Offset travel}) clueArrowVectors(ArrowShape shape)` — entry = unit vector from clue toward the start cell; travel = cardinal unit vector the word reads (screen coords: +x right, +y down).
  - `List<Offset> clueArrowSpine(ArrowShape shape)` — arrow polyline in the unit square (0..1), tail→tip; length 2 for straight, 3 for bent/diagonal.
  - `class ClueArrowPainter extends CustomPainter` with `const ClueArrowPainter({required ArrowShape shape, required Color color})`.

- [ ] **Step 1: Write the failing tests**

Create `packages/crossword_ui/test/gameplay/presentation/crossword_screen/widgets/clue_arrow_painter_test.dart`:

```dart
import 'package:crossword_core/crossword_core.dart';
import 'package:crossword_ui/gameplay/presentation/crossword_screen/widgets/clue_arrow_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('clueArrowVectors', () {
    test('straightRight enters and reads right', () {
      final v = clueArrowVectors(ArrowShape.straightRight);
      expect(v.entry, const Offset(1, 0));
      expect(v.travel, const Offset(1, 0));
    });

    test('diagonalSwThenRight enters toward SW and reads right', () {
      final v = clueArrowVectors(ArrowShape.diagonalSwThenRight);
      expect(v.entry, const Offset(-1, 1));
      expect(v.travel, const Offset(1, 0));
    });

    test('diagonalNwThenDown enters toward NW and reads down', () {
      final v = clueArrowVectors(ArrowShape.diagonalNwThenDown);
      expect(v.entry, const Offset(-1, -1));
      expect(v.travel, const Offset(0, 1));
    });

    test('every shape reads in a cardinal direction', () {
      for (final shape in ArrowShape.values) {
        final travel = clueArrowVectors(shape).travel;
        expect(
          travel == const Offset(1, 0) || travel == const Offset(0, 1),
          isTrue,
          reason: '$shape',
        );
      }
    });
  });

  group('clueArrowSpine', () {
    test('straight has 2 points, bent/diagonal have 3', () {
      expect(clueArrowSpine(ArrowShape.straightRight).length, 2);
      expect(clueArrowSpine(ArrowShape.bentDownThenRight).length, 3);
      expect(clueArrowSpine(ArrowShape.diagonalNwThenDown).length, 3);
    });

    test('final segment runs in the travel direction (right)', () {
      final spine = clueArrowSpine(ArrowShape.diagonalSwThenRight);
      final tip = spine.last;
      final prev = spine[spine.length - 2];
      expect(tip.dx > prev.dx, isTrue);
      expect((tip.dy - prev.dy).abs() < 1e-9, isTrue);
    });

    test('all points stay within the unit square', () {
      for (final shape in ArrowShape.values) {
        for (final p in clueArrowSpine(shape)) {
          expect(p.dx, inInclusiveRange(0.0, 1.0));
          expect(p.dy, inInclusiveRange(0.0, 1.0));
        }
      }
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd packages/crossword_ui && flutter test test/gameplay/presentation/crossword_screen/widgets/clue_arrow_painter_test.dart`
Expected: FAIL — `clueArrowVectors` / `clueArrowSpine` / `ClueArrowPainter` not defined.

- [ ] **Step 3: Implement the painter**

Create `packages/crossword_ui/lib/gameplay/presentation/crossword_screen/widgets/clue_arrow_painter.dart`:

```dart
import 'dart:math' as math;

import 'package:crossword_core/crossword_core.dart';
import 'package:flutter/material.dart';

/// Direction from the clue cell toward the word's start (entry) and the
/// direction the word then reads (travel), in screen coords (+x right, +y down).
({Offset entry, Offset travel}) clueArrowVectors(ArrowShape shape) {
  switch (shape) {
    case ArrowShape.straightRight:
      return (entry: const Offset(1, 0), travel: const Offset(1, 0));
    case ArrowShape.straightDown:
      return (entry: const Offset(0, 1), travel: const Offset(0, 1));
    case ArrowShape.bentDownThenRight:
      return (entry: const Offset(0, 1), travel: const Offset(1, 0));
    case ArrowShape.bentUpThenRight:
      return (entry: const Offset(0, -1), travel: const Offset(1, 0));
    case ArrowShape.bentRightThenDown:
      return (entry: const Offset(1, 0), travel: const Offset(0, 1));
    case ArrowShape.bentLeftThenDown:
      return (entry: const Offset(-1, 0), travel: const Offset(0, 1));
    case ArrowShape.diagonalSwThenRight:
      return (entry: const Offset(-1, 1), travel: const Offset(1, 0));
    case ArrowShape.diagonalNwThenRight:
      return (entry: const Offset(-1, -1), travel: const Offset(1, 0));
    case ArrowShape.diagonalSeThenRight:
      return (entry: const Offset(1, 1), travel: const Offset(1, 0));
    case ArrowShape.diagonalNeThenRight:
      return (entry: const Offset(1, -1), travel: const Offset(1, 0));
    case ArrowShape.diagonalSwThenDown:
      return (entry: const Offset(-1, 1), travel: const Offset(0, 1));
    case ArrowShape.diagonalNwThenDown:
      return (entry: const Offset(-1, -1), travel: const Offset(0, 1));
    case ArrowShape.diagonalSeThenDown:
      return (entry: const Offset(1, 1), travel: const Offset(0, 1));
    case ArrowShape.diagonalNeThenDown:
      return (entry: const Offset(1, -1), travel: const Offset(0, 1));
  }
}

Offset _clampUnit(Offset o) =>
    Offset(o.dx.clamp(0.08, 0.92), o.dy.clamp(0.08, 0.92));

/// Arrow spine in the unit square (0..1), ordered tail→tip. Straight arrows are
/// a 2-point line; bent and diagonal arrows add an elbow toward the start cell.
List<Offset> clueArrowSpine(ArrowShape shape) {
  final v = clueArrowVectors(shape);
  const center = Offset(0.5, 0.5);
  if (v.entry == v.travel) {
    return [
      _clampUnit(center - v.travel * 0.4),
      _clampUnit(center + v.travel * 0.4),
    ];
  }
  final elbow = _clampUnit(center + v.entry * 0.3);
  final tip = _clampUnit(elbow + v.travel * 0.45);
  return [_clampUnit(center - v.travel * 0.15), elbow, tip];
}

/// Draws a single clue arrow (line spine + filled arrowhead) filling its canvas.
/// Scoped CustomPainter exception: only the arrow glyph is painted; the grid
/// itself remains widget-based.
class ClueArrowPainter extends CustomPainter {
  final ArrowShape shape;
  final Color color;

  const ClueArrowPainter({required this.shape, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final spine = clueArrowSpine(shape)
        .map((p) => Offset(p.dx * size.width, p.dy * size.height))
        .toList();

    final stroke = Paint()
      ..color = color
      ..strokeWidth = math.max(1.0, size.shortestSide * 0.07)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path()..moveTo(spine.first.dx, spine.first.dy);
    for (final point in spine.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, stroke);

    final tip = spine.last;
    final prev = spine[spine.length - 2];
    final angle = math.atan2(tip.dy - prev.dy, tip.dx - prev.dx);
    final headLen = size.shortestSide * 0.24;
    const spread = 0.5; // radians off the shaft axis
    final left = Offset(
      tip.dx - headLen * math.cos(angle - spread),
      tip.dy - headLen * math.sin(angle - spread),
    );
    final right = Offset(
      tip.dx - headLen * math.cos(angle + spread),
      tip.dy - headLen * math.sin(angle + spread),
    );
    final head = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(
      Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(left.dx, left.dy)
        ..lineTo(right.dx, right.dy)
        ..close(),
      head,
    );
  }

  @override
  bool shouldRepaint(ClueArrowPainter oldDelegate) =>
      oldDelegate.shape != shape || oldDelegate.color != color;
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd packages/crossword_ui && flutter test test/gameplay/presentation/crossword_screen/widgets/clue_arrow_painter_test.dart`
Expected: PASS — all `clueArrowVectors` and `clueArrowSpine` tests pass.

- [ ] **Step 5: Commit**

```bash
git add packages/crossword_ui/lib/gameplay/presentation/crossword_screen/widgets/clue_arrow_painter.dart \
        packages/crossword_ui/test/gameplay/presentation/crossword_screen/widgets/clue_arrow_painter_test.dart
git commit -m "feat(ui): add ClueArrowPainter for clue arrow glyphs"
```

---

### Task 5: `HintCellWidget` divider-split compartments

**Files:**
- Modify: `packages/crossword_ui/lib/gameplay/presentation/crossword_screen/widgets/hint_cell_widget.dart`
- Test: `packages/crossword_ui/test/gameplay/presentation/crossword_screen/widgets/hint_cell_widget_test.dart`

**Interfaces:**
- Consumes: `ClueCell.arrows` (ordered top-first by Tasks 2–3), `ClueArrowPainter` (Task 4), `AppColors.{ink,gridLine,clueCell,clueCellActive}`.
- Produces: a `StatelessWidget` rendering 0 arrows (empty), 1 arrow (one `CustomPaint`), or 2 arrows (a `Column` of two `CustomPaint` compartments separated by a divider).

- [ ] **Step 1: Write the failing tests**

Create `packages/crossword_ui/test/gameplay/presentation/crossword_screen/widgets/hint_cell_widget_test.dart`:

```dart
import 'package:crossword_core/crossword_core.dart';
import 'package:crossword_ui/gameplay/presentation/crossword_screen/widgets/clue_arrow_painter.dart';
import 'package:crossword_ui/gameplay/presentation/crossword_screen/widgets/hint_cell_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Finder _arrowPaints() => find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is ClueArrowPainter,
    );

Widget _host(ClueCell cell) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: HintCellWidget(
            cell: cell,
            size: 48,
            onTap: () {},
            fontFamily: 'Roboto',
          ),
        ),
      ),
    );

void main() {
  testWidgets('empty clue cell paints no arrows', (tester) async {
    await tester.pumpWidget(_host(const ClueCell()));
    expect(_arrowPaints(), findsNothing);
  });

  testWidgets('single-arrow clue cell paints one arrow, no divider column',
      (tester) async {
    await tester.pumpWidget(_host(const ClueCell(arrows: [
      ClueArrow(
        direction: Direction.right,
        shape: ArrowShape.straightRight,
        wordId: 'w1',
      ),
    ])));
    expect(_arrowPaints(), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(HintCellWidget),
        matching: find.byType(Column),
      ),
      findsNothing,
    );
  });

  testWidgets('two-clue cell splits into two compartments with a divider',
      (tester) async {
    await tester.pumpWidget(_host(const ClueCell(arrows: [
      ClueArrow(
        direction: Direction.right,
        shape: ArrowShape.straightRight,
        wordId: 'top',
      ),
      ClueArrow(
        direction: Direction.down,
        shape: ArrowShape.straightDown,
        wordId: 'bottom',
      ),
    ])));
    expect(_arrowPaints(), findsNWidgets(2));
    expect(
      find.descendant(
        of: find.byType(HintCellWidget),
        matching: find.byType(Column),
      ),
      findsOneWidget,
    );
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd packages/crossword_ui && flutter test test/gameplay/presentation/crossword_screen/widgets/hint_cell_widget_test.dart`
Expected: FAIL — the widget still renders Material-icon arrows (no `ClueArrowPainter`), so `_arrowPaints()` finds nothing.

- [ ] **Step 3: Rewrite the widget to use the painter + divider**

Replace the entire contents of `packages/crossword_ui/lib/gameplay/presentation/crossword_screen/widgets/hint_cell_widget.dart` with:

```dart
import 'package:crossword_core/crossword_core.dart';
import 'package:flutter/material.dart';

import '../../../../common/data/constants/app_colors.dart';
import 'clue_arrow_painter.dart';

class HintCellWidget extends StatelessWidget {
  final ClueCell cell;
  final double size;
  final VoidCallback onTap;
  final String fontFamily;

  /// Whether this clue starts the currently active word.
  final bool isActive;

  const HintCellWidget({
    required this.cell,
    required this.size,
    required this.onTap,
    required this.fontFamily,
    this.isActive = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isActive ? AppColors.clueCellActive : AppColors.clueCell,
          border: Border.all(color: AppColors.gridLine, width: 0.5),
        ),
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    final arrows = cell.arrows;
    if (arrows.isEmpty) {
      return const SizedBox.expand();
    }
    if (arrows.length == 1) {
      return _arrowPaint(arrows.first);
    }
    // Two clues share this box: split it into top and bottom compartments.
    // arrows are ordered top-first by the mapper/resolver.
    return Column(
      children: [
        Expanded(child: _arrowPaint(arrows[0])),
        Container(height: 0.5, color: AppColors.gridLine),
        Expanded(child: _arrowPaint(arrows[1])),
      ],
    );
  }

  Widget _arrowPaint(ClueArrow arrow) {
    return CustomPaint(
      painter: ClueArrowPainter(shape: arrow.shape, color: AppColors.ink),
      child: const SizedBox.expand(),
    );
  }
}
```

- [ ] **Step 4: Run the full ui test suite**

Run: `cd packages/crossword_ui && flutter test`
Expected: PASS — the three new widget tests pass and existing crossword_grid / engine / cubit tests still pass (the widget keeps its public constructor and `ClueCell` rendering contract).

- [ ] **Step 5: Commit**

```bash
git add packages/crossword_ui/lib/gameplay/presentation/crossword_screen/widgets/hint_cell_widget.dart \
        packages/crossword_ui/test/gameplay/presentation/crossword_screen/widgets/hint_cell_widget_test.dart
git commit -m "feat(ui): split two-clue hint cells and paint arrows via ClueArrowPainter"
```

---

### Task 6: Full-suite analyze + verification

**Files:** none (verification only).

- [ ] **Step 1: Analyze all touched packages**

Run: `cd packages/crossword_core && flutter analyze && cd ../crossword_api && flutter analyze && cd ../crossword_ui && flutter analyze`
Expected: No issues (no new lints — trailing commas, single quotes, const, no `!`).

- [ ] **Step 2: Run every package's tests**

Run: `cd packages/crossword_core && flutter test && cd ../crossword_api && flutter test && cd ../crossword_ui && flutter test`
Expected: All PASS.

- [ ] **Step 3: Visual check in the running app (manual)**

Launch the app to the generate screen, generate/load the test puzzle, and confirm: diagonal-entry clues show a corner arrow pointing into the start cell then along the word; two-clue boxes show a horizontal divider with one arrow per half and no overlap. Tune `ClueArrowPainter` stroke width / `0.3`/`0.45` spine factors and `headLen` if cramped at small cell sizes (see spec §11). Re-run Task 4/5 tests after any tuning.

- [ ] **Step 4: Commit any tuning**

```bash
git add packages/crossword_ui/lib/gameplay/presentation/crossword_screen/widgets/clue_arrow_painter.dart
git commit -m "polish(ui): tune clue arrow geometry for small cells"
```

(Skip this commit if no tuning was needed.)

---

## Notes for the implementer

- The real generation fixture lives at `packages/crossword_api/test/fixtures/generation_response_9x9.json`. Its multi-clue cells are `(4,4)`, `(5,0)`, `(5,7)`; its diagonal clues are slots 1, 17, 21, 22.
- `ArrowShape` is exported from `package:crossword_core/crossword_core.dart`; do not import the entity file directly.
- Grid cells are the documented exception to the "InkWell not GestureDetector" rule — keep the `GestureDetector` in `HintCellWidget`.
- Out of scope: per-compartment clue text (prose is null today), picture clues, backend changes, 3+ clues per box.
