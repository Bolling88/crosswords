# Korsord Grid POC Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a working Swedish magazine-style crossword grid with all cell types (hint, answer, blocked, image) and interactive input to validate the Flutter widget approach.

**Architecture:** Feature-based Clean Architecture with Cubit pattern. A single `gameplay/` feature contains the data model (sealed Cell hierarchy, CrosswordPuzzle), a Cubit for selection/input state, cell widgets rendered in a Table+Stack layout, and a three-widget screen structure. Keyboard input via Focus widget's onKeyEvent.

**Tech Stack:** Flutter 3.41.9, flutter_bloc (Cubit), equatable

---

## File Structure

```
lib/
├── main.dart                                          (modify — app entry point)
└── gameplay/
    ├── data/
    │   └── entities/
    │       ├── direction.dart                          (create — Direction enum)
    │       ├── cell.dart                               (create — sealed Cell hierarchy)
    │       └── crossword_puzzle.dart                   (create — puzzle container)
    ├── data/
    │   └── sample_puzzle.dart                          (create — hardcoded 13×15 korsord)
    └── presentation/
        └── crossword_screen/
            ├── cubit/
            │   ├── crossword_cubit.dart                (create — selection, input, highlighting logic)
            │   └── crossword_state.dart                (create — Equatable state)
            ├── widgets/
            │   ├── hint_cell_widget.dart                (create — dark bg, clue text, arrow)
            │   ├── answer_cell_widget.dart              (create — letter display, selection highlight)
            │   ├── blocked_cell_widget.dart             (create — solid dark fill)
            │   └── crossword_grid.dart                  (create — Table + Stack layout with image overlay)
            └── crossword_screen.dart                    (create — 3-widget screen structure + keyboard)

test/
└── gameplay/
    └── presentation/
        └── crossword_screen/
            └── cubit/
                └── crossword_cubit_test.dart            (create — selection, input, highlight tests)
```

---

### Task 1: Project Setup

**Files:**
- Modify: `pubspec.yaml`
- Modify: `analysis_options.yaml`

- [ ] **Step 1: Add dependencies to pubspec.yaml**

Replace the dependencies and dev_dependencies sections:

```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  flutter_bloc: ^9.1.1
  equatable: ^2.0.7

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
```

- [ ] **Step 2: Update analysis_options.yaml**

Replace file contents with:

```yaml
include: package:flutter_lints/flutter.yaml

linter:
  rules:
    avoid_print: true
    prefer_single_quotes: true
    prefer_const_constructors: true
    prefer_const_declarations: true
    require_trailing_commas: true
    avoid_unnecessary_containers: true
    use_decorated_box: true
```

- [ ] **Step 3: Run flutter pub get**

Run: `flutter pub get`
Expected: dependencies resolve successfully.

- [ ] **Step 4: Commit**

```bash
git add pubspec.yaml pubspec.lock analysis_options.yaml
git commit -m "chore: add flutter_bloc and equatable dependencies, configure lints"
```

---

### Task 2: Data Model

**Files:**
- Create: `lib/gameplay/data/entities/direction.dart`
- Create: `lib/gameplay/data/entities/cell.dart`
- Create: `lib/gameplay/data/entities/crossword_puzzle.dart`

- [ ] **Step 1: Create Direction enum**

Create `lib/gameplay/data/entities/direction.dart`:

```dart
enum Direction { right, down, downRight }
```

- [ ] **Step 2: Create Cell sealed class hierarchy**

Create `lib/gameplay/data/entities/cell.dart`:

```dart
import 'direction.dart';

sealed class Cell {
  const Cell();
}

class HintCell extends Cell {
  final String clueText;
  final List<Direction> arrows;

  const HintCell({required this.clueText, required this.arrows});
}

class AnswerCell extends Cell {
  final String solution;

  const AnswerCell({required this.solution});
}

class BlockedCell extends Cell {
  const BlockedCell();
}

class ImageCell extends Cell {
  final int spanRows;
  final int spanCols;
  final bool isOrigin;

  const ImageCell({
    required this.spanRows,
    required this.spanCols,
    required this.isOrigin,
  });
}
```

- [ ] **Step 3: Create CrosswordPuzzle**

Create `lib/gameplay/data/entities/crossword_puzzle.dart`:

```dart
import 'cell.dart';

class CrosswordPuzzle {
  final int rows;
  final int cols;
  final Map<(int, int), Cell> cells;

  const CrosswordPuzzle({
    required this.rows,
    required this.cols,
    required this.cells,
  });
}
```

- [ ] **Step 4: Run analysis**

Run: `dart analyze lib/gameplay/data/entities/`
Expected: No issues found.

- [ ] **Step 5: Commit**

```bash
git add lib/gameplay/data/entities/
git commit -m "feat: add Cell sealed class hierarchy, Direction enum, and CrosswordPuzzle model"
```

---

### Task 3: Cubit State & Logic (TDD)

**Files:**
- Create: `lib/gameplay/presentation/crossword_screen/cubit/crossword_state.dart`
- Create: `lib/gameplay/presentation/crossword_screen/cubit/crossword_cubit.dart`
- Create: `test/gameplay/presentation/crossword_screen/cubit/crossword_cubit_test.dart`

- [ ] **Step 1: Create CrosswordState**

Create `lib/gameplay/presentation/crossword_screen/cubit/crossword_state.dart`:

```dart
import 'package:equatable/equatable.dart';

import '../../../../gameplay/data/entities/crossword_puzzle.dart';
import '../../../../gameplay/data/entities/direction.dart';

class CrosswordState extends Equatable {
  final CrosswordPuzzle puzzle;
  final Map<(int, int), String> userInputs;
  final (int, int)? selectedCell;
  final Direction currentDirection;
  final Set<(int, int)> highlightedCells;

  const CrosswordState({
    required this.puzzle,
    this.userInputs = const <(int, int), String>{},
    this.selectedCell,
    this.currentDirection = Direction.right,
    this.highlightedCells = const <(int, int)>{},
  });

  @override
  List<Object?> get props => [
        userInputs,
        selectedCell,
        currentDirection,
        highlightedCells,
      ];

  CrosswordState copyWith({
    Map<(int, int), String>? userInputs,
    (int, int)? selectedCell,
    Direction? currentDirection,
    Set<(int, int)>? highlightedCells,
  }) {
    return CrosswordState(
      puzzle: puzzle,
      userInputs: userInputs ?? this.userInputs,
      selectedCell: selectedCell ?? this.selectedCell,
      currentDirection: currentDirection ?? this.currentDirection,
      highlightedCells: highlightedCells ?? this.highlightedCells,
    );
  }
}
```

- [ ] **Step 2: Write failing cubit tests**

Create `test/gameplay/presentation/crossword_screen/cubit/crossword_cubit_test.dart`:

```dart
import 'package:crosswords/gameplay/data/entities/cell.dart';
import 'package:crosswords/gameplay/data/entities/crossword_puzzle.dart';
import 'package:crosswords/gameplay/data/entities/direction.dart';
import 'package:crosswords/gameplay/presentation/crossword_screen/cubit/crossword_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

CrosswordPuzzle _buildTestPuzzle() {
  // 4x4 test grid:
  // H→↓  A    A    A
  // A    H→↓  A    A
  // A    A    A    #
  // H→   A    A    A
  return CrosswordPuzzle(
    rows: 4,
    cols: 4,
    cells: {
      (0, 0): const HintCell(
        clueText: 'Test',
        arrows: [Direction.right, Direction.down],
      ),
      (0, 1): const AnswerCell(solution: 'A'),
      (0, 2): const AnswerCell(solution: 'B'),
      (0, 3): const AnswerCell(solution: 'C'),
      (1, 0): const AnswerCell(solution: 'D'),
      (1, 1): const HintCell(
        clueText: 'Test 2',
        arrows: [Direction.right, Direction.down],
      ),
      (1, 2): const AnswerCell(solution: 'E'),
      (1, 3): const AnswerCell(solution: 'F'),
      (2, 0): const AnswerCell(solution: 'G'),
      (2, 1): const AnswerCell(solution: 'H'),
      (2, 2): const AnswerCell(solution: 'I'),
      (2, 3): const BlockedCell(),
      (3, 0): const HintCell(
        clueText: 'Test 3',
        arrows: [Direction.right],
      ),
      (3, 1): const AnswerCell(solution: 'J'),
      (3, 2): const AnswerCell(solution: 'K'),
      (3, 3): const AnswerCell(solution: 'L'),
    },
  );
}

void main() {
  late CrosswordCubit cubit;

  setUp(() {
    cubit = CrosswordCubit(puzzle: _buildTestPuzzle());
  });

  tearDown(() {
    cubit.close();
  });

  test('initial state has no selection', () {
    expect(cubit.state.selectedCell, isNull);
    expect(cubit.state.highlightedCells, isEmpty);
  });

  test('selecting an answer cell highlights the horizontal word', () {
    cubit.selectCell(0, 1);

    expect(cubit.state.selectedCell, equals((0, 1)));
    expect(cubit.state.currentDirection, equals(Direction.right));
    expect(
      cubit.state.highlightedCells,
      equals({(0, 1), (0, 2), (0, 3)}),
    );
  });

  test('selecting a hint cell selects first answer cell in arrow direction', () {
    cubit.selectCell(0, 0);

    expect(cubit.state.selectedCell, equals((0, 1)));
    expect(cubit.state.currentDirection, equals(Direction.right));
  });

  test('selecting a blocked cell does nothing', () {
    cubit.selectCell(2, 3);

    expect(cubit.state.selectedCell, isNull);
  });

  test('tapping already-selected cell at crossing toggles direction', () {
    // (2,1) is at a crossing: horizontal (2,0)(2,1)(2,2) and vertical (2,1)(3,1)
    cubit.selectCell(2, 1);
    expect(cubit.state.currentDirection, equals(Direction.right));
    expect(
      cubit.state.highlightedCells,
      equals({(2, 0), (2, 1), (2, 2)}),
    );

    cubit.selectCell(2, 1);
    expect(cubit.state.currentDirection, equals(Direction.down));
    expect(
      cubit.state.highlightedCells,
      equals({(2, 1), (3, 1)}),
    );
  });

  test('typing a letter fills cell and auto-advances', () {
    cubit.selectCell(0, 1);
    cubit.onLetterInput('X');

    expect(cubit.state.userInputs[(0, 1)], equals('X'));
    expect(cubit.state.selectedCell, equals((0, 2)));
  });

  test('backspace clears current cell and moves back', () {
    cubit.selectCell(0, 1);
    cubit.onLetterInput('X');
    cubit.onLetterInput('Y');
    // Now at (0,3), inputs: (0,1)=X, (0,2)=Y

    cubit.onBackspace();
    // (0,3) was empty, so move back to (0,2) and clear it
    expect(cubit.state.selectedCell, equals((0, 2)));
    expect(cubit.state.userInputs.containsKey((0, 2)), isFalse);
  });
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `flutter test test/gameplay/presentation/crossword_screen/cubit/crossword_cubit_test.dart`
Expected: Compilation error — `CrosswordCubit` does not exist yet.

- [ ] **Step 4: Create CrosswordCubit**

Create `lib/gameplay/presentation/crossword_screen/cubit/crossword_cubit.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../gameplay/data/entities/cell.dart';
import '../../../../gameplay/data/entities/direction.dart';
import 'crossword_state.dart';

class CrosswordCubit extends Cubit<CrosswordState> {
  final FocusNode focusNode = FocusNode();

  CrosswordCubit({required CrosswordPuzzle puzzle})
      : super(CrosswordState(puzzle: puzzle));

  void selectCell(int row, int col) {
    final cell = state.puzzle.cells[(row, col)];
    if (cell == null) return;

    switch (cell) {
      case BlockedCell():
      case ImageCell():
        return;
      case HintCell():
        final dir = cell.arrows.first;
        final (nr, nc) = _advance(row, col, dir);
        if (state.puzzle.cells[(nr, nc)] is AnswerCell) {
          _selectAnswerCell(nr, nc, dir);
        }
      case AnswerCell():
        if (state.selectedCell == (row, col)) {
          _toggleDirection(row, col);
        } else {
          _selectAnswerCell(row, col, state.currentDirection);
        }
    }
  }

  void onLetterInput(String letter) {
    final sel = state.selectedCell;
    if (sel == null) return;

    final newInputs = Map<(int, int), String>.from(state.userInputs);
    newInputs[sel] = letter;

    final next = _findNextAnswerCell(sel.$1, sel.$2, state.currentDirection);
    final target = next ?? sel;

    emit(state.copyWith(
      userInputs: newInputs,
      selectedCell: target,
      highlightedCells: _computeWord(target.$1, target.$2, state.currentDirection),
    ));
  }

  void onBackspace() {
    final sel = state.selectedCell;
    if (sel == null) return;

    final newInputs = Map<(int, int), String>.from(state.userInputs);

    if (newInputs.containsKey(sel)) {
      newInputs.remove(sel);
      emit(state.copyWith(userInputs: newInputs));
    } else {
      final prev = _findPrevAnswerCell(sel.$1, sel.$2, state.currentDirection);
      if (prev != null) {
        newInputs.remove(prev);
        emit(state.copyWith(
          userInputs: newInputs,
          selectedCell: prev,
          highlightedCells:
              _computeWord(prev.$1, prev.$2, state.currentDirection),
        ));
      }
    }
  }

  void _selectAnswerCell(int row, int col, Direction direction) {
    var highlighted = _computeWord(row, col, direction);
    if (highlighted.length < 2) {
      final otherDir =
          direction == Direction.right ? Direction.down : Direction.right;
      final otherHighlighted = _computeWord(row, col, otherDir);
      if (otherHighlighted.length >= 2) {
        direction = otherDir;
        highlighted = otherHighlighted;
      }
    }

    emit(state.copyWith(
      selectedCell: (row, col),
      currentDirection: direction,
      highlightedCells: highlighted,
    ));
  }

  void _toggleDirection(int row, int col) {
    final otherDir = state.currentDirection == Direction.right
        ? Direction.down
        : Direction.right;
    final otherHighlighted = _computeWord(row, col, otherDir);
    if (otherHighlighted.length >= 2) {
      emit(state.copyWith(
        currentDirection: otherDir,
        highlightedCells: otherHighlighted,
      ));
    }
  }

  Set<(int, int)> _computeWord(int row, int col, Direction direction) {
    final cells = <(int, int)>{(row, col)};
    var (r, c) = (row, col);
    while (true) {
      final (nr, nc) = _advance(r, c, direction);
      if (state.puzzle.cells[(nr, nc)] is! AnswerCell) break;
      cells.add((nr, nc));
      (r, c) = (nr, nc);
    }
    (r, c) = (row, col);
    while (true) {
      final (nr, nc) = _retreat(r, c, direction);
      if (state.puzzle.cells[(nr, nc)] is! AnswerCell) break;
      cells.add((nr, nc));
      (r, c) = (nr, nc);
    }
    return cells;
  }

  (int, int) _advance(int row, int col, Direction direction) {
    return switch (direction) {
      Direction.right => (row, col + 1),
      Direction.down => (row + 1, col),
      Direction.downRight => (row + 1, col + 1),
    };
  }

  (int, int) _retreat(int row, int col, Direction direction) {
    return switch (direction) {
      Direction.right => (row, col - 1),
      Direction.down => (row - 1, col),
      Direction.downRight => (row - 1, col - 1),
    };
  }

  (int, int)? _findNextAnswerCell(int row, int col, Direction direction) {
    final (nr, nc) = _advance(row, col, direction);
    if (state.puzzle.cells[(nr, nc)] is AnswerCell) return (nr, nc);
    return null;
  }

  (int, int)? _findPrevAnswerCell(int row, int col, Direction direction) {
    final (nr, nc) = _retreat(row, col, direction);
    if (state.puzzle.cells[(nr, nc)] is AnswerCell) return (nr, nc);
    return null;
  }

  @override
  Future<void> close() {
    focusNode.dispose();
    return super.close();
  }
}
```

Note: the import for `CrosswordPuzzle` comes via `crossword_state.dart` which re-exports the needed types, or add direct imports:

```dart
import '../../../../gameplay/data/entities/cell.dart';
import '../../../../gameplay/data/entities/crossword_puzzle.dart';
import '../../../../gameplay/data/entities/direction.dart';
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/gameplay/presentation/crossword_screen/cubit/crossword_cubit_test.dart`
Expected: All 7 tests pass.

- [ ] **Step 6: Commit**

```bash
git add lib/gameplay/presentation/crossword_screen/cubit/ test/
git commit -m "feat: add CrosswordCubit with selection, input, and highlighting logic"
```

---

### Task 4: Cell Widgets

**Files:**
- Create: `lib/gameplay/presentation/crossword_screen/widgets/hint_cell_widget.dart`
- Create: `lib/gameplay/presentation/crossword_screen/widgets/answer_cell_widget.dart`
- Create: `lib/gameplay/presentation/crossword_screen/widgets/blocked_cell_widget.dart`

- [ ] **Step 1: Create HintCellWidget**

Create `lib/gameplay/presentation/crossword_screen/widgets/hint_cell_widget.dart`:

```dart
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../gameplay/data/entities/cell.dart';
import '../../../../gameplay/data/entities/direction.dart';

class HintCellWidget extends StatelessWidget {
  final HintCell cell;
  final double size;
  final VoidCallback onTap;

  const HintCellWidget({
    required this.cell,
    required this.size,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Color(0xFF1A237E),
          border: Border.fromBorderSide(
            BorderSide(width: 0.5),
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.all(size * 0.08),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: Text(
                    cell.clueText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      height: 1.1,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: cell.arrows
                    .map((arrow) => _buildArrow(arrow))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArrow(Direction direction) {
    final angle = switch (direction) {
      Direction.right => 0.0,
      Direction.down => pi / 2,
      Direction.downRight => pi / 4,
    };
    return Transform.rotate(
      angle: angle,
      child: Icon(
        Icons.arrow_forward,
        color: Colors.white,
        size: size * 0.25,
      ),
    );
  }
}
```

- [ ] **Step 2: Create AnswerCellWidget**

Create `lib/gameplay/presentation/crossword_screen/widgets/answer_cell_widget.dart`:

```dart
import 'package:flutter/material.dart';

class AnswerCellWidget extends StatelessWidget {
  final String? userInput;
  final bool isSelected;
  final bool isHighlighted;
  final double size;
  final VoidCallback onTap;

  const AnswerCellWidget({
    required this.size,
    required this.onTap,
    this.userInput,
    this.isSelected = false,
    this.isHighlighted = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF42A5F5)
              : isHighlighted
                  ? const Color(0xFFBBDEFB)
                  : Colors.white,
          border: Border.all(width: 0.5),
        ),
        alignment: Alignment.center,
        child: Text(
          userInput ?? '',
          style: TextStyle(
            fontSize: size * 0.55,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : Colors.black,
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Create BlockedCellWidget**

Create `lib/gameplay/presentation/crossword_screen/widgets/blocked_cell_widget.dart`:

```dart
import 'package:flutter/material.dart';

class BlockedCellWidget extends StatelessWidget {
  final double size;

  const BlockedCellWidget({required this.size, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      color: const Color(0xFF1A237E),
    );
  }
}
```

- [ ] **Step 4: Run analysis**

Run: `dart analyze lib/gameplay/presentation/crossword_screen/widgets/`
Expected: No issues found.

- [ ] **Step 5: Commit**

```bash
git add lib/gameplay/presentation/crossword_screen/widgets/
git commit -m "feat: add HintCellWidget, AnswerCellWidget, and BlockedCellWidget"
```

---

### Task 5: Grid Widget

**Files:**
- Create: `lib/gameplay/presentation/crossword_screen/widgets/crossword_grid.dart`

- [ ] **Step 1: Create CrosswordGrid**

Create `lib/gameplay/presentation/crossword_screen/widgets/crossword_grid.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../gameplay/data/entities/cell.dart';
import '../cubit/crossword_cubit.dart';
import '../cubit/crossword_state.dart';
import 'answer_cell_widget.dart';
import 'blocked_cell_widget.dart';
import 'hint_cell_widget.dart';

class CrosswordGrid extends StatelessWidget {
  final CrosswordState state;

  const CrosswordGrid({required this.state, super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellSize = constraints.maxWidth / state.puzzle.cols;
        return Stack(
          children: [
            _buildTable(context, cellSize),
            ..._buildImageOverlays(cellSize),
          ],
        );
      },
    );
  }

  Widget _buildTable(BuildContext context, double cellSize) {
    final cubit = context.read<CrosswordCubit>();
    return Table(
      defaultColumnWidth: FixedColumnWidth(cellSize),
      defaultVerticalAlignment: TableCellVerticalAlignment.top,
      children: List.generate(state.puzzle.rows, (row) {
        return TableRow(
          children: List.generate(state.puzzle.cols, (col) {
            return SizedBox(
              height: cellSize,
              child: _buildCell(row, col, cellSize, cubit),
            );
          }),
        );
      }),
    );
  }

  Widget _buildCell(int row, int col, double cellSize, CrosswordCubit cubit) {
    final cell = state.puzzle.cells[(row, col)];
    if (cell == null) {
      return SizedBox(width: cellSize, height: cellSize);
    }

    return switch (cell) {
      HintCell() => HintCellWidget(
          cell: cell,
          size: cellSize,
          onTap: () => cubit.selectCell(row, col),
        ),
      AnswerCell() => AnswerCellWidget(
          userInput: state.userInputs[(row, col)],
          isSelected: state.selectedCell == (row, col),
          isHighlighted: state.highlightedCells.contains((row, col)),
          size: cellSize,
          onTap: () => cubit.selectCell(row, col),
        ),
      BlockedCell() => BlockedCellWidget(size: cellSize),
      ImageCell() => SizedBox(width: cellSize, height: cellSize),
    };
  }

  List<Widget> _buildImageOverlays(double cellSize) {
    final overlays = <Widget>[];
    for (final entry in state.puzzle.cells.entries) {
      final cell = entry.value;
      if (cell is ImageCell && cell.isOrigin) {
        final (row, col) = entry.key;
        overlays.add(
          Positioned(
            left: col * cellSize,
            top: row * cellSize,
            width: cell.spanCols * cellSize,
            height: cell.spanRows * cellSize,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFE8EAF6),
                border: Border.all(width: 0.5),
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.image,
                    size: cellSize * 1.2,
                    color: const Color(0xFF7986CB),
                  ),
                  Text(
                    'BILD',
                    style: TextStyle(
                      color: const Color(0xFF3F51B5),
                      fontSize: cellSize * 0.3,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }
    return overlays;
  }
}
```

- [ ] **Step 2: Run analysis**

Run: `dart analyze lib/gameplay/presentation/crossword_screen/widgets/crossword_grid.dart`
Expected: No issues found.

- [ ] **Step 3: Commit**

```bash
git add lib/gameplay/presentation/crossword_screen/widgets/crossword_grid.dart
git commit -m "feat: add CrosswordGrid with Table layout and image overlay"
```

---

### Task 6: Screen Structure, Sample Puzzle, and Wiring

**Files:**
- Create: `lib/gameplay/data/sample_puzzle.dart`
- Create: `lib/gameplay/presentation/crossword_screen/crossword_screen.dart`
- Modify: `lib/main.dart`

- [ ] **Step 1: Create sample puzzle**

Create `lib/gameplay/data/sample_puzzle.dart`:

```dart
import 'package:crosswords/gameplay/data/entities/cell.dart';
import 'package:crosswords/gameplay/data/entities/crossword_puzzle.dart';
import 'package:crosswords/gameplay/data/entities/direction.dart';

CrosswordPuzzle buildSamplePuzzle() {
  // 13×15 Swedish korsord grid layout
  // H=hint, .=answer, #=blocked, I=image origin, i=image span
  const layout = [
    'H....#H....#H', // R0
    '....#H...#H..', // R1
    '.H....#H.....', // R2
    '#...#.H...#H.', // R3
    'H......#H...#', // R4
    '..#......#...', // R5
    'H....#H....#.', // R6
    '...#.H.......', // R7
    '#.H...#..H...', // R8
    '....#......#.', // R9
    'H....#H...Iii', // R10
    '...#H.....iii', // R11
    'H.....#...iii', // R12
    '#H...#.......', // R13
    '....#H...#H..', // R14
  ];

  const clues = [
    'Husdjur',
    'Svensk stad',
    'Smak',
    'Fågel',
    'Färg',
    'Årstid',
    'Maträtt',
    'Träd',
    'Land',
    'Yrke',
    'Sport',
    'Blomma',
    'Djur',
    'Dryck',
    'Möbel',
    'Verktyg',
    'Planet',
    'Metall',
    'Tyg',
    'Ö',
    'Krydda',
    'Känsla',
    'Fisk',
  ];

  const fillLetters = 'KVISTNORDHAXFLYGMUDDERPASKEN';

  final cells = <(int, int), Cell>{};
  var clueIndex = 0;
  var letterIndex = 0;

  for (var row = 0; row < layout.length; row++) {
    for (var col = 0; col < layout[row].length; col++) {
      final ch = layout[row][col];
      switch (ch) {
        case 'H':
          final arrows = <Direction>[];
          if (col + 1 < 13 && layout[row][col + 1] == '.') {
            arrows.add(Direction.right);
          }
          if (row + 1 < 15 && layout[row + 1][col] == '.') {
            arrows.add(Direction.down);
          }
          if (arrows.isEmpty) arrows.add(Direction.right);
          cells[(row, col)] = HintCell(
            clueText: clues[clueIndex % clues.length],
            arrows: arrows,
          );
          clueIndex++;
        case '.':
          cells[(row, col)] = AnswerCell(
            solution: fillLetters[letterIndex % fillLetters.length],
          );
          letterIndex++;
        case '#':
          cells[(row, col)] = const BlockedCell();
        case 'I':
          cells[(row, col)] = const ImageCell(
            spanRows: 3,
            spanCols: 3,
            isOrigin: true,
          );
        case 'i':
          cells[(row, col)] = const ImageCell(
            spanRows: 3,
            spanCols: 3,
            isOrigin: false,
          );
      }
    }
  }

  return CrosswordPuzzle(rows: 15, cols: 13, cells: cells);
}
```

- [ ] **Step 2: Create CrosswordScreen (three-widget structure)**

Create `lib/gameplay/presentation/crossword_screen/crossword_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../gameplay/data/sample_puzzle.dart';
import 'cubit/crossword_cubit.dart';
import 'cubit/crossword_state.dart';
import 'widgets/crossword_grid.dart';

class CrosswordScreen extends StatelessWidget {
  const CrosswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => CrosswordCubit(puzzle: buildSamplePuzzle()),
      child: const CrosswordScreenBuilder(),
    );
  }
}

class CrosswordScreenBuilder extends StatelessWidget {
  const CrosswordScreenBuilder({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CrosswordCubit, CrosswordState>(
      builder: (context, state) => CrosswordScreenContent(state: state),
    );
  }
}

class CrosswordScreenContent extends StatelessWidget {
  final CrosswordState state;

  const CrosswordScreenContent({required this.state, super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CrosswordCubit>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Korsord'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      body: Focus(
        focusNode: cubit.focusNode,
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          final char = event.character;
          if (char != null &&
              char.length == 1 &&
              RegExp(r'[a-zA-ZåäöÅÄÖ]').hasMatch(char)) {
            cubit.onLetterInput(char.toUpperCase());
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.backspace) {
            cubit.onBackspace();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: CrosswordGrid(state: state),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Update main.dart**

Replace `lib/main.dart` contents:

```dart
import 'package:flutter/material.dart';

import 'gameplay/presentation/crossword_screen/crossword_screen.dart';

void main() {
  runApp(const CrosswordsApp());
}

class CrosswordsApp extends StatelessWidget {
  const CrosswordsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Korsord',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A237E)),
        useMaterial3: true,
      ),
      home: const CrosswordScreen(),
    );
  }
}
```

- [ ] **Step 4: Run flutter analyze**

Run: `flutter analyze`
Expected: No issues found.

- [ ] **Step 5: Run tests**

Run: `flutter test`
Expected: All tests pass (the default widget_test.dart will fail — delete `test/widget_test.dart` first).

- [ ] **Step 6: Run the app**

Run: `flutter run` (on a connected device or simulator)
Expected: A 13×15 crossword grid renders with dark hint cells (with clue text and arrows), white answer cells, dark blocked cells, and a 3×3 image placeholder. Tapping an answer cell highlights the word in blue. Typing on the keyboard fills letters.

- [ ] **Step 7: Commit**

```bash
git rm test/widget_test.dart
git add lib/ test/
git commit -m "feat: complete korsord grid POC with sample puzzle, screen, and keyboard input"
```
