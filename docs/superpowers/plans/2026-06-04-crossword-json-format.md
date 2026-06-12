# Crossword JSON Format Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Consume the crossword-generator JSON (bundled as a hardcoded asset) and render/play it with full fidelity — bent arrows, two-clue cells, redirected word paths, separators, seed highlighting, and åäö.

**Architecture:** Three layers (Approach B). Data DTOs deserialize the JSON 1:1. A `PuzzleResolver` converts DTOs into a domain `CrosswordPuzzle` and, crucially, resolves every `word_id` into an explicit ordered list of cell positions (following `start` + `redirect` turns). The cubit and widgets consume the domain model; word highlight/navigation walk the resolved `Word.cells` path instead of scanning adjacent cells.

**Tech Stack:** Flutter 3.41.9, flutter_bloc (Cubit), Equatable, `dart:convert`, `flutter/services.dart` `rootBundle`.

**Spec:** `docs/superpowers/specs/2026-06-04-crossword-json-format-design.md`

---

## File Structure

**Create:**
- `assets/puzzles/generated_crossword.json` — the downloaded generator output.
- `lib/gameplay/data/entities/dto/position_dto.dart` — `{col,row}` DTO.
- `lib/gameplay/data/entities/dto/grid_cell_dto.dart` — sealed DTO: block/answer/clue.
- `lib/gameplay/data/entities/dto/grid_dto.dart` — width/height/rows DTO.
- `lib/gameplay/data/entities/dto/puzzle_dto.dart` — top-level DTO.
- `lib/gameplay/data/puzzle_resolver.dart` — DTO → domain + word resolution.
- `lib/gameplay/data/local_puzzle_data_source.dart` — loads asset → domain puzzle.
- `lib/gameplay/domain/entities/arrow_shape.dart` — arrow glyph enum.
- `lib/gameplay/domain/entities/clue_arrow.dart` — direction + shape + wordId.
- `lib/gameplay/domain/entities/word.dart` — resolved word.
- `test/gameplay/data/entities/dto/puzzle_dto_test.dart`
- `test/gameplay/data/puzzle_resolver_test.dart`
- `test/gameplay/data/local_puzzle_data_source_test.dart`

**Modify (migrate the existing data-layer entities into the domain layer):**
- `lib/gameplay/domain/entities/direction.dart` — NEW location; `enum Direction { right, down }`.
- `lib/gameplay/domain/entities/cell.dart` — NEW location; `ClueCell`/`AnswerCell`/`BlockCell`/`ImageCell`.
- `lib/gameplay/domain/entities/crossword_puzzle.dart` — NEW location; adds `words`, `seedPositions`, `separatorEdges`, `title`, `languageCode`, lookups.
- `lib/gameplay/presentation/crossword_screen/cubit/crossword_cubit.dart` — word-path navigation.
- `lib/gameplay/presentation/crossword_screen/cubit/crossword_state.dart` — import path only.
- `lib/gameplay/presentation/crossword_screen/widgets/crossword_grid.dart` — new cell types.
- `lib/gameplay/presentation/crossword_screen/widgets/hint_cell_widget.dart` — arrow shapes.
- `lib/gameplay/presentation/crossword_screen/widgets/answer_cell_widget.dart` — separators + seed.
- `lib/gameplay/presentation/crossword_screen/crossword_screen.dart` — receive loaded puzzle.
- `lib/main.dart` — load puzzle before `runApp`, pass down.
- `lib/common/data/constants/app_colors.dart` — add `seedCell`, `separator`.
- `pubspec.yaml` — register the asset.
- `test/gameplay/presentation/crossword_screen/cubit/crossword_cubit_test.dart` — new model.

**Delete (after migration):**
- `lib/gameplay/data/entities/cell.dart`
- `lib/gameplay/data/entities/crossword_puzzle.dart`
- `lib/gameplay/data/entities/direction.dart`
- `lib/gameplay/data/sample_puzzle.dart`

---

## Task 1: Bundle the JSON asset

**Files:**
- Create: `assets/puzzles/generated_crossword.json`
- Modify: `pubspec.yaml:57-66` (the `flutter:` section)

- [ ] **Step 1: Download the asset**

Run:
```bash
mkdir -p assets/puzzles
curl -fsSL https://pastebin.com/raw/6sG2n7vi -o assets/puzzles/generated_crossword.json
```

- [ ] **Step 2: Verify it is valid JSON with the expected shape**

Run:
```bash
python3 -c "import json; d=json.load(open('assets/puzzles/generated_crossword.json')); print(d['grid']['width'], d['grid']['height'], d['title'], len(d['seed_positions']))"
```
Expected: `13 15 Generated crossword 14`

- [ ] **Step 3: Register the asset in pubspec.yaml**

In `pubspec.yaml`, inside the `flutter:` section, immediately after the `uses-material-design: true` line, add (the `assets:` key is indented two spaces under `flutter:`):

```yaml
  assets:
    - assets/puzzles/generated_crossword.json
```

- [ ] **Step 4: Verify pubspec parses**

Run: `flutter pub get`
Expected: completes with no error (`Got dependencies!`).

- [ ] **Step 5: Commit**

```bash
git add assets/puzzles/generated_crossword.json pubspec.yaml
git commit -m "feat: bundle generated crossword JSON as an asset"
```

---

## Task 2: Domain entities

Pure data classes. No tests of their own beyond the lookup test in Step 7 — they are exercised heavily by the resolver and cubit tests.

**Files:**
- Create: `lib/gameplay/domain/entities/direction.dart`
- Create: `lib/gameplay/domain/entities/arrow_shape.dart`
- Create: `lib/gameplay/domain/entities/clue_arrow.dart`
- Create: `lib/gameplay/domain/entities/cell.dart`
- Create: `lib/gameplay/domain/entities/word.dart`
- Create: `lib/gameplay/domain/entities/crossword_puzzle.dart`
- Test: `test/gameplay/domain/entities/crossword_puzzle_test.dart`

- [ ] **Step 1: Create `direction.dart`**

```dart
/// The two base travel directions a word can run before any redirect.
enum Direction { right, down }
```

- [ ] **Step 2: Create `arrow_shape.dart`**

```dart
/// Visual glyph for a clue's arrow, derived from where the word starts
/// relative to the clue cell and which way the word travels.
enum ArrowShape {
  /// Word starts in the cell to the right and runs right.
  straightRight,

  /// Word starts in the cell below and runs down.
  straightDown,

  /// Word starts in the cell below, then runs right (L-shaped, down→right).
  bentDownThenRight,

  /// Word starts in the cell to the right, then runs down (L-shaped, right→down).
  bentRightThenDown,
}
```

- [ ] **Step 3: Create `clue_arrow.dart`**

```dart
import 'package:equatable/equatable.dart';

import 'arrow_shape.dart';
import 'direction.dart';

/// One arrow drawn in a clue cell, pointing at the word it introduces.
class ClueArrow extends Equatable {
  final Direction direction;
  final ArrowShape shape;
  final String wordId;

  const ClueArrow({
    required this.direction,
    required this.shape,
    required this.wordId,
  });

  @override
  List<Object?> get props => [direction, shape, wordId];
}
```

- [ ] **Step 4: Create `cell.dart`**

```dart
import 'clue_arrow.dart';

sealed class Cell {
  const Cell();
}

/// A hint cell carrying 0–2 arrows (one across, one down).
class ClueCell extends Cell {
  final List<ClueArrow> arrows;

  const ClueCell({this.arrows = const []});
}

/// A fillable letter cell.
class AnswerCell extends Cell {
  final String value;
  final bool isSeed;

  const AnswerCell({required this.value, this.isSeed = false});
}

/// An inert dark cell.
class BlockCell extends Cell {
  const BlockCell();
}

/// Retained for future image clues; not produced by the current generator.
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

- [ ] **Step 5: Create `word.dart`**

```dart
import 'package:equatable/equatable.dart';

import 'direction.dart';

/// A resolved word: the ordered grid positions a player fills, following the
/// clue's start position and any mid-word redirect turns.
class Word extends Equatable {
  final String id;
  final String? clueId;
  final String? clueText;
  final Direction direction;

  /// Ordered cell positions `(row, col)` from first letter to last.
  final List<(int, int)> cells;

  /// Indices into [cells] after which an intra-answer word break falls.
  final Set<int> separators;

  const Word({
    required this.id,
    required this.direction,
    required this.cells,
    this.clueId,
    this.clueText,
    this.separators = const {},
  });

  @override
  List<Object?> get props => [id, clueId, clueText, direction, cells, separators];
}
```

- [ ] **Step 6: Create `crossword_puzzle.dart`**

```dart
import 'cell.dart';
import 'direction.dart';
import 'word.dart';

class CrosswordPuzzle {
  final int rows;
  final int cols;
  final Map<(int, int), Cell> cells;
  final List<Word> words;
  final Set<(int, int)> seedPositions;

  /// Which cell edges carry an intra-answer break: a [Direction.right] entry
  /// means a divider on that cell's right edge; [Direction.down] its bottom.
  final Map<(int, int), Set<Direction>> separatorEdges;

  final String title;
  final String languageCode;

  const CrosswordPuzzle({
    required this.rows,
    required this.cols,
    required this.cells,
    required this.words,
    required this.title,
    required this.languageCode,
    this.seedPositions = const {},
    this.separatorEdges = const {},
  });

  /// The word with [id], or null if none.
  Word? wordById(String id) {
    for (final w in words) {
      if (w.id == id) return w;
    }
    return null;
  }

  /// The word running [direction] that contains [cell], or null.
  Word? wordAt((int, int) cell, Direction direction) {
    for (final w in words) {
      if (w.direction == direction && w.cells.contains(cell)) return w;
    }
    return null;
  }
}
```

- [ ] **Step 7: Write the lookup test**

`test/gameplay/domain/entities/crossword_puzzle_test.dart`:

```dart
import 'package:crosswords/gameplay/domain/entities/cell.dart';
import 'package:crosswords/gameplay/domain/entities/crossword_puzzle.dart';
import 'package:crosswords/gameplay/domain/entities/direction.dart';
import 'package:crosswords/gameplay/domain/entities/word.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const across = Word(
    id: 'word-1',
    direction: Direction.right,
    cells: [(0, 1), (0, 2)],
  );
  const down = Word(
    id: 'word-2',
    direction: Direction.down,
    cells: [(0, 1), (1, 1)],
  );
  const puzzle = CrosswordPuzzle(
    rows: 2,
    cols: 3,
    cells: {},
    words: [across, down],
    title: 't',
    languageCode: 'sv',
  );

  test('wordById finds by id', () {
    expect(puzzle.wordById('word-2'), down);
    expect(puzzle.wordById('nope'), isNull);
  });

  test('wordAt matches direction and membership', () {
    expect(puzzle.wordAt((0, 1), Direction.right), across);
    expect(puzzle.wordAt((0, 1), Direction.down), down);
    expect(puzzle.wordAt((1, 1), Direction.right), isNull);
  });
}
```

- [ ] **Step 8: Run the test**

Run: `flutter test test/gameplay/domain/entities/crossword_puzzle_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 9: Commit**

```bash
git add lib/gameplay/domain/entities test/gameplay/domain/entities/crossword_puzzle_test.dart
git commit -m "feat: add domain entities for resolved crossword model"
```

---

## Task 3: JSON DTOs

**Files:**
- Create: `lib/gameplay/data/entities/dto/position_dto.dart`
- Create: `lib/gameplay/data/entities/dto/grid_cell_dto.dart`
- Create: `lib/gameplay/data/entities/dto/grid_dto.dart`
- Create: `lib/gameplay/data/entities/dto/puzzle_dto.dart`
- Test: `test/gameplay/data/entities/dto/puzzle_dto_test.dart`

- [ ] **Step 1: Write the failing round-trip test**

`test/gameplay/data/entities/dto/puzzle_dto_test.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:crosswords/gameplay/data/entities/dto/grid_cell_dto.dart';
import 'package:crosswords/gameplay/data/entities/dto/puzzle_dto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses the bundled generator JSON', () {
    final raw = File('assets/puzzles/generated_crossword.json').readAsStringSync();
    final dto = PuzzleDto.fromJson(jsonDecode(raw) as Map<String, dynamic>);

    expect(dto.title, 'Generated crossword');
    expect(dto.languageCode, 'sv');
    expect(dto.grid.width, 13);
    expect(dto.grid.height, 15);
    expect(dto.grid.rows.length, 15);
    expect(dto.grid.rows.every((r) => r.length == 13), isTrue);
    expect(dto.seedPositions.length, 14);

    // First cell is a clue that points right with a non-adjacent start.
    final first = dto.grid.rows[0][0] as ClueCellDto;
    expect(first.rightWordId, 'word-12');
    expect(first.rightStart?.row, 1);
    expect(first.rightStart?.col, 0);

    // A redirected answer cell exists (row 2, col 12 -> "K", right_redirect).
    final redirected = dto.grid.rows[2][12] as AnswerCellDto;
    expect(redirected.value, 'K');
    expect(redirected.rightRedirect, isTrue);

    // A separator cell exists (row 13, col 1 -> "I", right_separator "_").
    final separated = dto.grid.rows[13][1] as AnswerCellDto;
    expect(separated.rightSeparator, '_');
  });
}
```

- [ ] **Step 2: Run it to confirm it fails**

Run: `flutter test test/gameplay/data/entities/dto/puzzle_dto_test.dart`
Expected: FAIL — `Target of URI doesn't exist` for the DTO imports.

- [ ] **Step 3: Create `position_dto.dart`**

```dart
class PositionDto {
  final int col;
  final int row;

  const PositionDto({required this.col, required this.row});

  factory PositionDto.fromJson(Map<String, dynamic> json) => PositionDto(
        col: json['col'] as int,
        row: json['row'] as int,
      );
}
```

- [ ] **Step 4: Create `grid_cell_dto.dart`**

```dart
import 'position_dto.dart';

sealed class GridCellDto {
  const GridCellDto();

  factory GridCellDto.fromJson(Map<String, dynamic> json) {
    switch (json['kind'] as String) {
      case 'block':
        return const BlockCellDto();
      case 'answer':
        return AnswerCellDto.fromJson(json);
      case 'clue':
        return ClueCellDto.fromJson(json);
      default:
        throw FormatException('Unknown cell kind: ${json['kind']}');
    }
  }
}

class BlockCellDto extends GridCellDto {
  const BlockCellDto();
}

class AnswerCellDto extends GridCellDto {
  final String value;
  final bool rightRedirect;
  final bool downRedirect;
  final String? rightSeparator;
  final String? downSeparator;

  const AnswerCellDto({
    required this.value,
    this.rightRedirect = false,
    this.downRedirect = false,
    this.rightSeparator,
    this.downSeparator,
  });

  factory AnswerCellDto.fromJson(Map<String, dynamic> json) => AnswerCellDto(
        value: json['value'] as String,
        rightRedirect: json['right_redirect'] as bool? ?? false,
        downRedirect: json['down_redirect'] as bool? ?? false,
        rightSeparator: json['right_separator'] as String?,
        downSeparator: json['down_separator'] as String?,
      );
}

class ClueCellDto extends GridCellDto {
  final String? right;
  final String? rightClueId;
  final String? rightWordId;
  final PositionDto? rightStart;
  final String? down;
  final String? downClueId;
  final String? downWordId;
  final PositionDto? downStart;

  const ClueCellDto({
    this.right,
    this.rightClueId,
    this.rightWordId,
    this.rightStart,
    this.down,
    this.downClueId,
    this.downWordId,
    this.downStart,
  });

  factory ClueCellDto.fromJson(Map<String, dynamic> json) {
    PositionDto? pos(String key) {
      final value = json[key];
      return value == null
          ? null
          : PositionDto.fromJson(value as Map<String, dynamic>);
    }

    return ClueCellDto(
      right: json['right'] as String?,
      rightClueId: json['right_clue_id'] as String?,
      rightWordId: json['right_word_id'] as String?,
      rightStart: pos('right_start'),
      down: json['down'] as String?,
      downClueId: json['down_clue_id'] as String?,
      downWordId: json['down_word_id'] as String?,
      downStart: pos('down_start'),
    );
  }
}
```

- [ ] **Step 5: Create `grid_dto.dart`**

```dart
import 'grid_cell_dto.dart';

class GridDto {
  final int width;
  final int height;
  final List<List<GridCellDto>> rows;

  const GridDto({
    required this.width,
    required this.height,
    required this.rows,
  });

  factory GridDto.fromJson(Map<String, dynamic> json) => GridDto(
        width: json['width'] as int,
        height: json['height'] as int,
        rows: (json['rows'] as List)
            .map((row) => (row as List)
                .map((cell) =>
                    GridCellDto.fromJson(cell as Map<String, dynamic>))
                .toList())
            .toList(),
      );
}
```

- [ ] **Step 6: Create `puzzle_dto.dart`**

```dart
import 'grid_dto.dart';
import 'position_dto.dart';

class PuzzleDto {
  final String title;
  final String languageCode;
  final GridDto grid;
  final List<PositionDto> seedPositions;

  const PuzzleDto({
    required this.title,
    required this.languageCode,
    required this.grid,
    required this.seedPositions,
  });

  factory PuzzleDto.fromJson(Map<String, dynamic> json) => PuzzleDto(
        title: json['title'] as String,
        languageCode: json['language_code'] as String,
        grid: GridDto.fromJson(json['grid'] as Map<String, dynamic>),
        seedPositions: (json['seed_positions'] as List)
            .map((p) => PositionDto.fromJson(p as Map<String, dynamic>))
            .toList(),
      );
}
```

- [ ] **Step 7: Run the test to confirm it passes**

Run: `flutter test test/gameplay/data/entities/dto/puzzle_dto_test.dart`
Expected: PASS (1 test).

- [ ] **Step 8: Commit**

```bash
git add lib/gameplay/data/entities/dto test/gameplay/data/entities/dto
git commit -m "feat: add DTOs that deserialize the crossword JSON"
```

---

## Task 4: Puzzle resolver

This is the heart of the feature. Build words from `start` + `redirect`, compute arrow shapes, mark seeds, record separator edges.

**Files:**
- Create: `lib/gameplay/data/puzzle_resolver.dart`
- Test: `test/gameplay/data/puzzle_resolver_test.dart`

- [ ] **Step 1: Write the failing tests**

`test/gameplay/data/puzzle_resolver_test.dart`:

```dart
import 'package:crosswords/gameplay/data/entities/dto/grid_cell_dto.dart';
import 'package:crosswords/gameplay/data/entities/dto/grid_dto.dart';
import 'package:crosswords/gameplay/data/entities/dto/position_dto.dart';
import 'package:crosswords/gameplay/data/entities/dto/puzzle_dto.dart';
import 'package:crosswords/gameplay/data/puzzle_resolver.dart';
import 'package:crosswords/gameplay/domain/entities/arrow_shape.dart';
import 'package:crosswords/gameplay/domain/entities/cell.dart';
import 'package:crosswords/gameplay/domain/entities/direction.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a PuzzleDto from a compact grid spec for focused tests.
PuzzleDto _puzzle(List<List<GridCellDto>> rows, {List<PositionDto> seeds = const []}) {
  return PuzzleDto(
    title: 't',
    languageCode: 'sv',
    grid: GridDto(width: rows.first.length, height: rows.length, rows: rows),
    seedPositions: seeds,
  );
}

const _block = BlockCellDto();
AnswerCellDto _a(
  String v, {
  bool rightRedirect = false,
  bool downRedirect = false,
  String? rightSeparator,
}) =>
    AnswerCellDto(
      value: v,
      rightRedirect: rightRedirect,
      downRedirect: downRedirect,
      rightSeparator: rightSeparator,
    );

void main() {
  test('resolves a straight across word', () {
    final dto = _puzzle([
      [
        ClueCellDto(rightWordId: 'w1', rightClueId: 'c1', rightStart: const PositionDto(col: 1, row: 0)),
        _a('C'),
        _a('A'),
        _a('T'),
      ],
    ]);

    final puzzle = PuzzleResolver.resolve(dto);
    final word = puzzle.wordById('w1');

    expect(word, isNotNull);
    expect(word!.direction, Direction.right);
    expect(word.cells, [(0, 1), (0, 2), (0, 3)]);
  });

  test('clue arrow shape is straightRight when start is adjacent right', () {
    final dto = _puzzle([
      [
        ClueCellDto(rightWordId: 'w1', rightStart: const PositionDto(col: 1, row: 0)),
        _a('A'),
        _a('B'),
      ],
    ]);

    final clue = PuzzleResolver.resolve(dto).cells[(0, 0)] as ClueCell;
    expect(clue.arrows.single.shape, ArrowShape.straightRight);
  });

  test('bent arrow: across word whose start is below the clue', () {
    // Clue at (0,0). Across word starts at (1,0) and runs right.
    final dto = _puzzle([
      [
        ClueCellDto(rightWordId: 'w1', rightStart: const PositionDto(col: 0, row: 1)),
        _block,
        _block,
      ],
      [
        _a('A'),
        _a('B'),
        _a('C'),
      ],
    ]);

    final puzzle = PuzzleResolver.resolve(dto);
    final clue = puzzle.cells[(0, 0)] as ClueCell;
    expect(clue.arrows.single.shape, ArrowShape.bentDownThenRight);
    expect(puzzle.wordById('w1')!.cells, [(1, 0), (1, 1), (1, 2)]);
  });

  test('redirect: across word turns down at a right_redirect cell', () {
    // A B(redirect) then down to C, D.
    final dto = _puzzle([
      [
        ClueCellDto(rightWordId: 'w1', rightStart: const PositionDto(col: 1, row: 0)),
        _a('A'),
        _a('B', rightRedirect: true),
      ],
      [
        _block,
        _block,
        _a('C'),
      ],
      [
        _block,
        _block,
        _a('D'),
      ],
    ]);

    final word = PuzzleResolver.resolve(dto).wordById('w1');
    expect(word!.cells, [(0, 1), (0, 2), (1, 2), (2, 2)]);
  });

  test('records separator index and a right separator edge', () {
    final dto = _puzzle([
      [
        ClueCellDto(rightWordId: 'w1', rightStart: const PositionDto(col: 1, row: 0)),
        _a('A', rightSeparator: '_'),
        _a('B'),
      ],
    ]);

    final puzzle = PuzzleResolver.resolve(dto);
    expect(puzzle.wordById('w1')!.separators, {0});
    expect(puzzle.separatorEdges[(0, 1)], contains(Direction.right));
  });

  test('two-clue cell yields an across and a down word with two arrows', () {
    final dto = _puzzle([
      [
        ClueCellDto(
          rightWordId: 'across',
          rightStart: const PositionDto(col: 1, row: 0),
          downWordId: 'down',
          downStart: const PositionDto(col: 0, row: 1),
        ),
        _a('A'),
      ],
      [
        _a('B'),
        _block,
      ],
    ]);

    final puzzle = PuzzleResolver.resolve(dto);
    final clue = puzzle.cells[(0, 0)] as ClueCell;
    expect(clue.arrows.length, 2);
    expect(puzzle.wordById('across')!.direction, Direction.right);
    expect(puzzle.wordById('down')!.direction, Direction.down);
  });

  test('marks seed answer cells and preserves åäö values', () {
    final dto = _puzzle([
      [
        ClueCellDto(rightWordId: 'w1', rightStart: const PositionDto(col: 1, row: 0)),
        _a('Å'),
        _a('Ä'),
      ],
    ], seeds: const [PositionDto(col: 1, row: 0)]);

    final puzzle = PuzzleResolver.resolve(dto);
    final seedCell = puzzle.cells[(0, 1)] as AnswerCell;
    final plainCell = puzzle.cells[(0, 2)] as AnswerCell;
    expect(seedCell.value, 'Å');
    expect(seedCell.isSeed, isTrue);
    expect(plainCell.isSeed, isFalse);
  });
}
```

- [ ] **Step 2: Run to confirm it fails**

Run: `flutter test test/gameplay/data/puzzle_resolver_test.dart`
Expected: FAIL — `puzzle_resolver.dart` does not exist.

- [ ] **Step 3: Implement the resolver**

`lib/gameplay/data/puzzle_resolver.dart`:

```dart
import '../domain/entities/arrow_shape.dart';
import '../domain/entities/cell.dart';
import '../domain/entities/clue_arrow.dart';
import '../domain/entities/crossword_puzzle.dart';
import '../domain/entities/direction.dart';
import '../domain/entities/word.dart';
import 'entities/dto/grid_cell_dto.dart';
import 'entities/dto/position_dto.dart';
import 'entities/dto/puzzle_dto.dart';

/// Converts a parsed [PuzzleDto] into a playable domain [CrosswordPuzzle],
/// resolving each word's ordered cell path from its start position and any
/// mid-word redirect turns.
class PuzzleResolver {
  const PuzzleResolver._();

  static CrosswordPuzzle resolve(PuzzleDto dto) {
    final grid = dto.grid;
    final rows = grid.height;
    final cols = grid.width;

    AnswerCellDto? answerAt(int r, int c) {
      if (r < 0 || r >= rows || c < 0 || c >= cols) return null;
      final cell = grid.rows[r][c];
      return cell is AnswerCellDto ? cell : null;
    }

    final seeds = dto.seedPositions.map((p) => (p.row, p.col)).toSet();
    final domainCells = <(int, int), Cell>{};
    final words = <Word>[];
    final separatorEdges = <(int, int), Set<Direction>>{};

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final cell = grid.rows[r][c];
        switch (cell) {
          case BlockCellDto():
            domainCells[(r, c)] = const BlockCell();
          case AnswerCellDto():
            domainCells[(r, c)] =
                AnswerCell(value: cell.value, isSeed: seeds.contains((r, c)));
          case ClueCellDto():
            final arrows = <ClueArrow>[];

            if (cell.rightWordId != null && cell.rightStart != null) {
              words.add(_resolveWord(
                id: cell.rightWordId!,
                clueId: cell.rightClueId,
                clueText: cell.right,
                start: cell.rightStart!,
                base: Direction.right,
                answerAt: answerAt,
                separatorEdges: separatorEdges,
              ));
              arrows.add(ClueArrow(
                direction: Direction.right,
                shape: _arrowShape(r, c, cell.rightStart!, Direction.right),
                wordId: cell.rightWordId!,
              ));
            }

            if (cell.downWordId != null && cell.downStart != null) {
              words.add(_resolveWord(
                id: cell.downWordId!,
                clueId: cell.downClueId,
                clueText: cell.down,
                start: cell.downStart!,
                base: Direction.down,
                answerAt: answerAt,
                separatorEdges: separatorEdges,
              ));
              arrows.add(ClueArrow(
                direction: Direction.down,
                shape: _arrowShape(r, c, cell.downStart!, Direction.down),
                wordId: cell.downWordId!,
              ));
            }

            domainCells[(r, c)] = ClueCell(arrows: arrows);
        }
      }
    }

    return CrosswordPuzzle(
      rows: rows,
      cols: cols,
      cells: domainCells,
      words: words,
      seedPositions: seeds,
      separatorEdges: separatorEdges,
      title: dto.title,
      languageCode: dto.languageCode,
    );
  }

  /// Walks from [start] in [base] direction, appending answer cells and
  /// turning right→down / down→right at any cell flagged redirect for the
  /// current travel direction, until the next cell is not an answer.
  static Word _resolveWord({
    required String id,
    required String? clueId,
    required String? clueText,
    required PositionDto start,
    required Direction base,
    required AnswerCellDto? Function(int, int) answerAt,
    required Map<(int, int), Set<Direction>> separatorEdges,
  }) {
    final cells = <(int, int)>[];
    final separators = <int>{};
    var r = start.row;
    var c = start.col;
    var dir = base;

    while (true) {
      final cell = answerAt(r, c);
      if (cell == null) break;
      cells.add((r, c));
      final index = cells.length - 1;

      final separator =
          dir == Direction.right ? cell.rightSeparator : cell.downSeparator;
      if (separator != null) {
        separators.add(index);
        separatorEdges.putIfAbsent((r, c), () => <Direction>{}).add(dir);
      }

      final redirect =
          dir == Direction.right ? cell.rightRedirect : cell.downRedirect;
      if (redirect) {
        dir = dir == Direction.right ? Direction.down : Direction.right;
      }

      final (nr, nc) =
          dir == Direction.right ? (r, c + 1) : (r + 1, c);
      if (answerAt(nr, nc) == null) break;
      r = nr;
      c = nc;
    }

    return Word(
      id: id,
      clueId: clueId,
      clueText: clueText,
      direction: base,
      cells: cells,
      separators: separators,
    );
  }

  /// Picks the arrow glyph from where the word starts relative to the clue.
  static ArrowShape _arrowShape(
    int clueRow,
    int clueCol,
    PositionDto start,
    Direction base,
  ) {
    final startsRight = start.row == clueRow && start.col == clueCol + 1;
    if (base == Direction.right) {
      return startsRight
          ? ArrowShape.straightRight
          : ArrowShape.bentDownThenRight;
    }
    final startsBelow = start.col == clueCol && start.row == clueRow + 1;
    return startsBelow ? ArrowShape.straightDown : ArrowShape.bentRightThenDown;
  }
}
```

- [ ] **Step 4: Run the tests to confirm they pass**

Run: `flutter test test/gameplay/data/puzzle_resolver_test.dart`
Expected: PASS (8 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/gameplay/data/puzzle_resolver.dart test/gameplay/data/puzzle_resolver_test.dart
git commit -m "feat: resolve crossword DTOs into playable words with bent/redirect paths"
```

---

## Task 5: Local puzzle data source

**Files:**
- Create: `lib/gameplay/data/local_puzzle_data_source.dart`
- Test: `test/gameplay/data/local_puzzle_data_source_test.dart`

- [ ] **Step 1: Write the failing test**

`test/gameplay/data/local_puzzle_data_source_test.dart`:

```dart
import 'package:crosswords/gameplay/data/local_puzzle_data_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads the bundled puzzle from assets into the domain model', () async {
    final puzzle = await const LocalPuzzleDataSource().loadGeneratedPuzzle();

    expect(puzzle.rows, 15);
    expect(puzzle.cols, 13);
    expect(puzzle.title, 'Generated crossword');
    expect(puzzle.words, isNotEmpty);
    expect(puzzle.seedPositions, isNotEmpty);
  });
}
```

- [ ] **Step 2: Run to confirm it fails**

Run: `flutter test test/gameplay/data/local_puzzle_data_source_test.dart`
Expected: FAIL — `local_puzzle_data_source.dart` does not exist.

- [ ] **Step 3: Implement the data source**

`lib/gameplay/data/local_puzzle_data_source.dart`:

```dart
import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../domain/entities/crossword_puzzle.dart';
import 'entities/dto/puzzle_dto.dart';
import 'puzzle_resolver.dart';

/// Loads the bundled, hardcoded crossword from assets. A backend-backed
/// source can replace this later behind the same return type.
class LocalPuzzleDataSource {
  static const String _assetPath = 'assets/puzzles/generated_crossword.json';

  final AssetBundle _bundle;

  const LocalPuzzleDataSource({AssetBundle? bundle})
      : _bundle = bundle ?? rootBundle;

  Future<CrosswordPuzzle> loadGeneratedPuzzle() async {
    final raw = await _bundle.loadString(_assetPath);
    final dto = PuzzleDto.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    return PuzzleResolver.resolve(dto);
  }
}
```

Note: `const LocalPuzzleDataSource()` resolves `_bundle` to `rootBundle` at construction; `rootBundle` is a top-level getter, so the default cannot be `const` — change the test to `LocalPuzzleDataSource()` (no `const`) and drop `const` from the constructor if the analyzer flags it. Keep the constructor non-const:

```dart
  LocalPuzzleDataSource({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;
```

And in the test use `LocalPuzzleDataSource()` without `const`.

- [ ] **Step 4: Run the test to confirm it passes**

Run: `flutter test test/gameplay/data/local_puzzle_data_source_test.dart`
Expected: PASS (1 test). If asset loading fails in the test binding, confirm Task 1 Step 3 registered the asset and `flutter pub get` was run.

- [ ] **Step 5: Commit**

```bash
git add lib/gameplay/data/local_puzzle_data_source.dart test/gameplay/data/local_puzzle_data_source_test.dart
git commit -m "feat: load the bundled puzzle asset into the domain model"
```

---

## Task 6: Rewrite the cubit for word-path navigation

The cubit no longer scans adjacent cells; it looks up the resolved `Word` and walks its ordered `cells`.

**Files:**
- Modify: `lib/gameplay/presentation/crossword_screen/cubit/crossword_state.dart` (import path)
- Modify: `lib/gameplay/presentation/crossword_screen/cubit/crossword_cubit.dart` (rewrite)
- Test: `test/gameplay/presentation/crossword_screen/cubit/crossword_cubit_test.dart` (rewrite)

- [ ] **Step 1: Update the state import**

In `crossword_state.dart`, replace the two data-entity imports:

```dart
import '../../../../gameplay/data/entities/crossword_puzzle.dart';
import '../../../../gameplay/data/entities/direction.dart';
```

with:

```dart
import '../../../../gameplay/domain/entities/crossword_puzzle.dart';
import '../../../../gameplay/domain/entities/direction.dart';
```

(The rest of `crossword_state.dart` is unchanged.)

- [ ] **Step 2: Rewrite the cubit test**

Replace the entire contents of `test/gameplay/presentation/crossword_screen/cubit/crossword_cubit_test.dart`:

```dart
import 'package:crosswords/gameplay/domain/entities/cell.dart';
import 'package:crosswords/gameplay/domain/entities/clue_arrow.dart';
import 'package:crosswords/gameplay/domain/entities/arrow_shape.dart';
import 'package:crosswords/gameplay/domain/entities/crossword_puzzle.dart';
import 'package:crosswords/gameplay/domain/entities/direction.dart';
import 'package:crosswords/gameplay/domain/entities/word.dart';
import 'package:crosswords/gameplay/presentation/crossword_screen/cubit/crossword_cubit.dart';
import 'package:crosswords/settings/domain/services/font_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 1x4 grid: clue at (0,0) -> across word "ABC" with a redirect that turns
/// down at (0,3). Layout:
///   C  A  B  D(redirect-down)
///               E
/// Across word "across" cells: (0,1),(0,2),(0,3),(1,3).
CrosswordPuzzle _puzzle() {
  const across = Word(
    id: 'across',
    direction: Direction.right,
    cells: [(0, 1), (0, 2), (0, 3), (1, 3)],
  );
  return const CrosswordPuzzle(
    rows: 2,
    cols: 4,
    cells: {
      (0, 0): ClueCell(arrows: [
        ClueArrow(
          direction: Direction.right,
          shape: ArrowShape.straightRight,
          wordId: 'across',
        ),
      ]),
      (0, 1): AnswerCell(value: 'A'),
      (0, 2): AnswerCell(value: 'B'),
      (0, 3): AnswerCell(value: 'C'),
      (1, 0): BlockCell(),
      (1, 1): BlockCell(),
      (1, 2): BlockCell(),
      (1, 3): AnswerCell(value: 'D'),
    },
    words: [across],
    title: 't',
    languageCode: 'sv',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CrosswordCubit cubit;
  late FontService fontService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    fontService = FontService(prefs: prefs);
    cubit = CrosswordCubit(puzzle: _puzzle(), fontService: fontService);
  });

  tearDown(() => cubit.close());

  test('tapping a clue selects the first cell of its word and highlights it',
      () {
    cubit.selectCell(0, 0);
    expect(cubit.state.selectedCell, (0, 1));
    expect(cubit.state.currentDirection, Direction.right);
    expect(
      cubit.state.highlightedCells,
      {(0, 1), (0, 2), (0, 3), (1, 3)},
    );
  });

  test('letter input advances along the resolved (redirected) word path', () {
    cubit.selectCell(0, 1);
    cubit.onLetterInput('A');
    expect(cubit.state.selectedCell, (0, 2));
    cubit.onLetterInput('B');
    expect(cubit.state.selectedCell, (0, 3));
    // The word redirects downward here; next cell is (1,3), not off-grid right.
    cubit.onLetterInput('C');
    expect(cubit.state.selectedCell, (1, 3));
    expect(cubit.state.userInputs[(0, 1)], 'A');
  });

  test('backspace on an empty cell steps back and clears the previous cell', () {
    cubit.selectCell(0, 1);
    cubit.onLetterInput('A'); // writes (0,1)='A', moves to empty (0,2)
    cubit.onBackspace(); // (0,2) empty -> step back to (0,1) and clear it
    expect(cubit.state.selectedCell, (0, 1));
    expect(cubit.state.userInputs.containsKey((0, 1)), isFalse);
  });

  test('backspace on a filled cell clears it in place', () {
    cubit.selectCell(0, 1);
    cubit.onLetterInput('A'); // (0,1)='A', now at (0,2)
    cubit.onLetterInput('B'); // (0,2)='B', now at (0,3)
    cubit.selectCell(0, 2); // re-select the filled (0,2)
    cubit.onBackspace(); // (0,2) filled -> clear in place, stay
    expect(cubit.state.selectedCell, (0, 2));
    expect(cubit.state.userInputs.containsKey((0, 2)), isFalse);
    expect(cubit.state.userInputs[(0, 1)], 'A');
  });
}
```

- [ ] **Step 3: Run to confirm it fails**

Run: `flutter test test/gameplay/presentation/crossword_screen/cubit/crossword_cubit_test.dart`
Expected: FAIL — old cubit references `HintCell`/`AnswerCell.solution`/data-entity imports.

- [ ] **Step 4: Rewrite the cubit**

Replace the entire contents of `crossword_cubit.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../gameplay/domain/entities/cell.dart';
import '../../../../gameplay/domain/entities/crossword_puzzle.dart';
import '../../../../gameplay/domain/entities/direction.dart';
import '../../../../gameplay/domain/entities/word.dart';
import '../../../../settings/domain/services/font_service.dart';
import 'crossword_state.dart';

class CrosswordCubit extends Cubit<CrosswordState> {
  final FocusNode focusNode = FocusNode();
  final TransformationController transformationController =
      TransformationController();
  final FontService _fontService;

  CrosswordCubit({
    required CrosswordPuzzle puzzle,
    required FontService fontService,
  })  : _fontService = fontService,
        super(CrosswordState(
          puzzle: puzzle,
          font: fontService.selectedFont.value,
        )) {
    _fontService.selectedFont.addListener(_onFontChanged);
  }

  void _onFontChanged() {
    emit(state.copyWith(font: _fontService.selectedFont.value));
  }

  void selectCell(int row, int col) {
    final cell = state.puzzle.cells[(row, col)];
    if (cell == null) return;

    switch (cell) {
      case BlockCell():
      case ImageCell():
        return;
      case ClueCell():
        if (cell.arrows.isEmpty) return;
        final word = state.puzzle.wordById(cell.arrows.first.wordId);
        if (word == null || word.cells.isEmpty) return;
        emit(state.copyWith(
          selectedCell: word.cells.first,
          currentDirection: word.direction,
          highlightedCells: word.cells.toSet(),
        ));
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

    final newInputs = Map<(int, int), String>.from(state.userInputs)
      ..[sel] = letter;
    final next = _nextCell(sel, state.currentDirection) ?? sel;

    emit(state.copyWith(userInputs: newInputs, selectedCell: next));
  }

  void onBackspace() {
    final sel = state.selectedCell;
    if (sel == null) return;

    final newInputs = Map<(int, int), String>.from(state.userInputs);
    if (newInputs.containsKey(sel)) {
      newInputs.remove(sel);
      emit(state.copyWith(userInputs: newInputs));
    } else {
      final prev = _prevCell(sel, state.currentDirection);
      if (prev != null) {
        newInputs.remove(prev);
        emit(state.copyWith(userInputs: newInputs, selectedCell: prev));
      }
    }
  }

  void _selectAnswerCell(int row, int col, Direction direction) {
    final word = state.puzzle.wordAt((row, col), direction) ??
        state.puzzle.wordAt(
          (row, col),
          direction == Direction.right ? Direction.down : Direction.right,
        );

    if (word == null) {
      emit(state.copyWith(
        selectedCell: (row, col),
        highlightedCells: {(row, col)},
      ));
      return;
    }

    emit(state.copyWith(
      selectedCell: (row, col),
      currentDirection: word.direction,
      highlightedCells: word.cells.toSet(),
    ));
  }

  void _toggleDirection(int row, int col) {
    final other = state.currentDirection == Direction.right
        ? Direction.down
        : Direction.right;
    final word = state.puzzle.wordAt((row, col), other);
    if (word != null) {
      emit(state.copyWith(
        currentDirection: other,
        highlightedCells: word.cells.toSet(),
      ));
    }
  }

  (int, int)? _nextCell((int, int) cell, Direction direction) {
    final word = state.puzzle.wordAt(cell, direction);
    if (word == null) return null;
    final i = word.cells.indexOf(cell);
    if (i < 0 || i + 1 >= word.cells.length) return null;
    return word.cells[i + 1];
  }

  (int, int)? _prevCell((int, int) cell, Direction direction) {
    final word = state.puzzle.wordAt(cell, direction);
    if (word == null) return null;
    final i = word.cells.indexOf(cell);
    if (i <= 0) return null;
    return word.cells[i - 1];
  }

  /// Snap the grid back to the default fit-width, un-panned view.
  void resetView() {
    transformationController.value = Matrix4.identity();
  }

  @override
  Future<void> close() {
    _fontService.selectedFont.removeListener(_onFontChanged);
    focusNode.dispose();
    transformationController.dispose();
    return super.close();
  }
}
```

- [ ] **Step 5: Run the cubit test to confirm it passes**

Run: `flutter test test/gameplay/presentation/crossword_screen/cubit/crossword_cubit_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/gameplay/presentation/crossword_screen/cubit test/gameplay/presentation/crossword_screen/cubit/crossword_cubit_test.dart
git commit -m "feat: navigate words via resolved cell paths in CrosswordCubit"
```

---

## Task 7: Update the widgets

**Files:**
- Modify: `lib/common/data/constants/app_colors.dart` (add colors)
- Modify: `lib/gameplay/presentation/crossword_screen/widgets/hint_cell_widget.dart`
- Modify: `lib/gameplay/presentation/crossword_screen/widgets/answer_cell_widget.dart`
- Modify: `lib/gameplay/presentation/crossword_screen/widgets/crossword_grid.dart`

There are no widget unit tests in this task; correctness is verified by `flutter analyze` plus the manual run in Task 8.

- [ ] **Step 1: Add colors**

In `app_colors.dart`, before the closing `}` of the `// App chrome` section, add:

```dart
  // Theme / structure marks
  /// Seed (theme word) answer cell — subtle pale sage wash.
  static const Color seedCell = Color(0xFFE3EAD2);

  /// Divider drawn on a cell edge where a multi-word answer breaks.
  static const Color separator = Color(0xFF3A352C);
```

- [ ] **Step 2: Rewrite `hint_cell_widget.dart` to draw arrow shapes**

Replace the entire file:

```dart
import 'package:flutter/material.dart';

import '../../../../common/data/constants/app_colors.dart';
import '../../../../gameplay/domain/entities/arrow_shape.dart';
import '../../../../gameplay/domain/entities/cell.dart';

class HintCellWidget extends StatelessWidget {
  final ClueCell cell;
  final double size;
  final VoidCallback onTap;
  final String fontFamily;

  const HintCellWidget({
    required this.cell,
    required this.size,
    required this.onTap,
    required this.fontFamily,
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
          color: AppColors.clueCell,
          border: Border.all(color: AppColors.gridLine, width: 0.5),
        ),
        child: Stack(
          children: [
            // Clue prose is null in generator output, so clue cells render
            // arrows only. Texts can be layered here once authored.
            for (final arrow in cell.arrows) _buildArrow(arrow.shape),
          ],
        ),
      ),
    );
  }

  Widget _buildArrow(ArrowShape shape) {
    return switch (shape) {
      ArrowShape.straightRight => Align(
          alignment: Alignment.centerRight,
          child: Icon(Icons.play_arrow,
              color: AppColors.ink, size: size * 0.3),
        ),
      ArrowShape.straightDown => Align(
          alignment: Alignment.bottomCenter,
          child: Transform.rotate(
            angle: 1.5707963267948966, // pi/2
            child: Icon(Icons.play_arrow,
                color: AppColors.ink, size: size * 0.3),
          ),
        ),
      // Bent arrows: an elbow glyph hugging the corner the word turns through.
      ArrowShape.bentDownThenRight => Align(
          alignment: Alignment.bottomRight,
          child: Icon(Icons.subdirectory_arrow_right,
              color: AppColors.ink, size: size * 0.34),
        ),
      ArrowShape.bentRightThenDown => Align(
          alignment: Alignment.bottomRight,
          child: Transform.rotate(
            angle: 1.5707963267948966, // pi/2: turns the elbow to right→down
            child: Icon(Icons.subdirectory_arrow_right,
                color: AppColors.ink, size: size * 0.34),
          ),
        ),
    };
  }
}
```

- [ ] **Step 3: Rewrite `answer_cell_widget.dart` for seed + separators**

Replace the entire file:

```dart
import 'package:flutter/material.dart';

import '../../../../common/data/constants/app_colors.dart';
import '../../../../common/data/constants/app_text_styles.dart';

class AnswerCellWidget extends StatelessWidget {
  final String? userInput;
  final bool isSelected;
  final bool isHighlighted;
  final bool isSeed;
  final bool hasRightSeparator;
  final bool hasBottomSeparator;
  final double size;
  final VoidCallback onTap;
  final String fontFamily;

  const AnswerCellWidget({
    required this.size,
    required this.onTap,
    required this.fontFamily,
    this.userInput,
    this.isSelected = false,
    this.isHighlighted = false,
    this.isSeed = false,
    this.hasRightSeparator = false,
    this.hasBottomSeparator = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final fillColor = isSelected
        ? AppColors.selection
        : isHighlighted
            ? AppColors.highlight
            : isSeed
                ? AppColors.seedCell
                : AppColors.paper;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: fillColor,
          border: Border(
            top: const BorderSide(color: AppColors.gridLine, width: 0.5),
            left: const BorderSide(color: AppColors.gridLine, width: 0.5),
            right: BorderSide(
              color: hasRightSeparator ? AppColors.separator : AppColors.gridLine,
              width: hasRightSeparator ? 2.0 : 0.5,
            ),
            bottom: BorderSide(
              color:
                  hasBottomSeparator ? AppColors.separator : AppColors.gridLine,
              width: hasBottomSeparator ? 2.0 : 0.5,
            ),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          userInput ?? '',
          style: AppTextStyles.answerLetter(size * 0.66, family: fontFamily),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Update `crossword_grid.dart` for the new cell types**

In `crossword_grid.dart`, change the entity import:

```dart
import '../../../../gameplay/data/entities/cell.dart';
```
to:
```dart
import '../../../../gameplay/domain/entities/cell.dart';
import '../../../../gameplay/domain/entities/direction.dart';
```

Then replace the `_buildCell` method body's `switch` and the `AnswerCell` branch so it reads the new types and passes separator/seed flags:

```dart
  Widget _buildCell(int row, int col, double cellSize, CrosswordCubit cubit) {
    final cell = state.puzzle.cells[(row, col)];
    if (cell == null) {
      return SizedBox(width: cellSize, height: cellSize);
    }

    final fontFamily = state.font.googleFamily;
    final edges = state.puzzle.separatorEdges[(row, col)] ?? const {};

    return switch (cell) {
      ClueCell() => HintCellWidget(
          cell: cell,
          size: cellSize,
          onTap: () => cubit.selectCell(row, col),
          fontFamily: fontFamily,
        ),
      AnswerCell() => AnswerCellWidget(
          userInput: state.userInputs[(row, col)],
          isSelected: state.selectedCell == (row, col),
          isHighlighted: state.highlightedCells.contains((row, col)),
          isSeed: cell.isSeed,
          hasRightSeparator: edges.contains(Direction.right),
          hasBottomSeparator: edges.contains(Direction.down),
          size: cellSize,
          onTap: () => cubit.selectCell(row, col),
          fontFamily: fontFamily,
        ),
      BlockCell() => BlockedCellWidget(size: cellSize),
      ImageCell() => SizedBox(width: cellSize, height: cellSize),
    };
  }
```

Also update `_buildImageOverlays` — it iterates `state.puzzle.cells.entries` and checks `cell is ImageCell`. That type now comes from the domain `cell.dart`, so no code change is needed there beyond the import already added. Leave it as-is.

- [ ] **Step 5: Verify the widgets analyze cleanly**

Run: `flutter analyze lib/gameplay/presentation/crossword_screen/widgets lib/common/data/constants/app_colors.dart`
Expected: `No issues found!` (the grid still imports `sample_puzzle`/old types only via files fixed in Task 8; if analyze reports errors that trace to `crossword_screen.dart` or `sample_puzzle.dart`, those are resolved in Task 8 — re-run full analyze there).

- [ ] **Step 6: Commit**

```bash
git add lib/common/data/constants/app_colors.dart lib/gameplay/presentation/crossword_screen/widgets
git commit -m "feat: render arrow shapes, seed cells, and answer separators"
```

---

## Task 8: Wire loading into the app and remove the old model

**Files:**
- Modify: `lib/gameplay/presentation/crossword_screen/crossword_screen.dart`
- Modify: `lib/main.dart`
- Delete: `lib/gameplay/data/sample_puzzle.dart`
- Delete: `lib/gameplay/data/entities/cell.dart`
- Delete: `lib/gameplay/data/entities/crossword_puzzle.dart`
- Delete: `lib/gameplay/data/entities/direction.dart`

- [ ] **Step 1: Make `CrosswordScreen` take a pre-loaded puzzle**

In `crossword_screen.dart`, replace the import:

```dart
import '../../../gameplay/data/sample_puzzle.dart';
```
with:
```dart
import '../../../gameplay/domain/entities/crossword_puzzle.dart';
```

Then change the `CrosswordScreen` wrapper to accept and pass the puzzle:

```dart
class CrosswordScreen extends StatelessWidget {
  final CrosswordPuzzle puzzle;

  const CrosswordScreen({required this.puzzle, super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => CrosswordCubit(
        puzzle: puzzle,
        fontService: context.read<FontService>(),
      ),
      child: const CrosswordScreenBuilder(),
    );
  }
}
```

(The rest of the file is unchanged.)

- [ ] **Step 2: Load the puzzle in `main.dart` before `runApp`**

In `main.dart`, add the import:

```dart
import 'gameplay/data/local_puzzle_data_source.dart';
import 'gameplay/domain/entities/crossword_puzzle.dart';
```

Change `main()` to load the puzzle and pass it down:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final fontService = FontService(prefs: prefs);
  final puzzle = await LocalPuzzleDataSource().loadGeneratedPuzzle();
  runApp(CrosswordsApp(fontService: fontService, puzzle: puzzle));
}
```

Update `CrosswordsApp` to hold and pass the puzzle:

```dart
class CrosswordsApp extends StatelessWidget {
  final FontService fontService;
  final CrosswordPuzzle puzzle;

  const CrosswordsApp({
    required this.fontService,
    required this.puzzle,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider<FontService>.value(
      value: fontService,
      child: MaterialApp(
        title: Strings.appTitle,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.brand,
            surface: AppColors.background,
          ),
          scaffoldBackgroundColor: AppColors.background,
          useMaterial3: true,
        ),
        home: CrosswordScreen(puzzle: puzzle),
      ),
    );
  }
}
```

- [ ] **Step 3: Delete the obsolete files**

Run:
```bash
git rm lib/gameplay/data/sample_puzzle.dart \
       lib/gameplay/data/entities/cell.dart \
       lib/gameplay/data/entities/crossword_puzzle.dart \
       lib/gameplay/data/entities/direction.dart
```

- [ ] **Step 4: Check for any leftover references to the old paths**

Run:
```bash
grep -rn "data/entities/cell\|data/entities/crossword_puzzle\|data/entities/direction\|sample_puzzle\|HintCell\|BlockedCell\|\.solution" lib test
```
Expected: no matches in `lib/`. If `test/gameplay/presentation/crossword_screen/crossword_screen_test.dart` references the old model or `buildSamplePuzzle`, update it to build a `CrosswordScreen(puzzle: ...)` using a small domain `CrosswordPuzzle` (mirror the cubit test's `_puzzle()` helper) — replace any `buildSamplePuzzle()` call and old entity imports with the domain entities.

- [ ] **Step 5: Analyze the whole project**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 6: Run the full test suite**

Run: `flutter test`
Expected: all tests pass.

- [ ] **Step 7: Manually verify the app renders the bundled puzzle**

Run: `flutter run` (or use the project `run` skill). Confirm: the 13×15 generated grid loads, arrows (including bent elbows) show in clue cells, tapping a clue selects and highlights its word, typing fills letters and advances along the word — including around a redirected word that turns a corner — and Swedish å/ä/ö display correctly.

- [ ] **Step 8: Commit**

```bash
git add lib/main.dart lib/gameplay/presentation/crossword_screen/crossword_screen.dart test
git commit -m "feat: load bundled puzzle at startup and remove the sample model"
```

---

## Self-Review Notes

- **Spec coverage:** bent arrows (Task 4 `_arrowShape` + Task 7 glyphs), two-clue cells (Task 4), redirects (Task 4 `_resolveWord`), separators (Task 4 edges + Task 7 dividers), seed highlight (Task 4 + Task 7), åäö (Task 4 test + Task 8 manual), asset loading (Tasks 1, 5, 8), data/domain split (Tasks 2, 3). All covered.
- **Open question carried from spec:** the redirect turn rule (right→down / down→right) is isolated in `_resolveWord`; if generator output later contradicts it, only that method changes.
- **Type consistency:** `ClueCell`/`AnswerCell`/`BlockCell`/`ImageCell`, `Word.cells: List<(int,int)>`, `Direction { right, down }`, `wordById`/`wordAt`, `separatorEdges` are used identically across tasks.
