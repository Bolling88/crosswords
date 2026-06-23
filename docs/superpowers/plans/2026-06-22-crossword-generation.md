# Crossword Generation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the user generate a fresh Swedish korsord from `POST https://api.ikors.se/crossword-puzzles/generate` and play it, with the generate screen as the app's landing screen.

**Architecture:** A new `crossword_api` package owns the endpoint (DTOs, http data source, mapper, repository, service). It maps the API response into the existing `crossword_core` `CrosswordPuzzle` so the current gameplay screen/renderer work unchanged. `crossword_ui` gains a `GenerateScreen` + cubit; each app injects its own gameplay screen via a `gameplayBuilder` callback.

**Tech Stack:** Flutter, flutter_bloc (Cubit), `http`, equatable, Dart pub workspace.

## Global Constraints

- SDK floor: `^3.11.5`; new package uses `resolution: workspace`.
- ALL widgets are `StatelessWidget`. No `setState`/`StatefulWidget`/`initState`/`dispose`/`ValueNotifier` in widgets. Local state lives in a Cubit.
- Cubit dependencies are private (`final X _x;` via `{required X x} : _x = x`).
- `TextEditingController`s live in the Cubit and are disposed in `close()`.
- Side effects (navigation, errors) use dedicated event-state classes, each with `final Key key = UniqueKey();` and `props` overridden. Never `copyWith` for side effects.
- Only Cubits access services; UI widgets never `context.read<Service>()` a service.
- No hardcoded user-facing strings — use `Strings`. Primary language Swedish (`sv`).
- No null-assertion `!`. Use `?.`, `??`, `== true`.
- Trailing commas; `const` where possible; `final` over `var`; single quotes; private members prefixed `_`.
- Import order: Dart/Flutter → packages → local, blank line between groups.
- Colors via `AppColors`; opacity via `withAlpha`.
- Commit after each task with a conventional-commit message.

---

### Task 1: Scaffold the `crossword_api` package

**Files:**
- Create: `packages/crossword_api/pubspec.yaml`
- Create: `packages/crossword_api/lib/crossword_api.dart`
- Create: `packages/crossword_api/analysis_options.yaml`
- Modify: `pubspec.yaml` (root `workspace:` list)
- Modify: `packages/crossword_ui/pubspec.yaml` (add path dep)

**Interfaces:**
- Produces: a workspace package `crossword_api` depending on `crossword_core` + `http`, importable from `crossword_ui` and the apps.

- [ ] **Step 1: Create the package pubspec**

`packages/crossword_api/pubspec.yaml`:
```yaml
name: crossword_api
description: Backend API client for crossword generation (ikors.se).
publish_to: 'none'
version: 0.0.1

environment:
  sdk: ^3.11.5

resolution: workspace

dependencies:
  flutter:
    sdk: flutter
  http: ^1.2.2
  equatable: ^2.0.7
  crossword_core:
    path: ../crossword_core

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
```

- [ ] **Step 2: Create the analysis options (mirror crossword_core)**

`packages/crossword_api/analysis_options.yaml`:
```yaml
include: package:flutter_lints/flutter.yaml
```

- [ ] **Step 3: Create an empty barrel**

`packages/crossword_api/lib/crossword_api.dart`:
```dart
// Barrel for the crossword generation API client. Exports are added per task.
```

- [ ] **Step 4: Register in the workspace**

In root `pubspec.yaml`, add to the `workspace:` list (keep alphabetical):
```yaml
  - packages/crossword_api
```

- [ ] **Step 5: Add the dependency to `crossword_ui`**

In `packages/crossword_ui/pubspec.yaml`, under `dependencies:` add:
```yaml
  crossword_api:
    path: ../crossword_api
```

- [ ] **Step 6: Resolve and verify it compiles**

Run: `flutter pub get`
Expected: resolves with no errors; `crossword_api` listed.

- [ ] **Step 7: Commit**

```bash
git add pubspec.yaml packages/crossword_api packages/crossword_ui/pubspec.yaml
git commit -m "build(api): scaffold crossword_api package"
```

---

### Task 2: Extract shared `ArrowShapeResolver` in `crossword_core`

**Files:**
- Create: `packages/crossword_core/lib/gameplay/domain/services/arrow_shape_resolver.dart`
- Modify: `packages/crossword_core/lib/gameplay/data/puzzle_resolver.dart` (use the new resolver, drop `_arrowShape`)
- Modify: `packages/crossword_core/lib/crossword_core.dart` (export resolver)
- Test: `packages/crossword_core/test/gameplay/domain/services/arrow_shape_resolver_test.dart`

**Interfaces:**
- Produces: `ArrowShapeResolver.resolve({required int clueRow, required int clueCol, required int startRow, required int startCol, required Direction base}) → ArrowShape`.

- [ ] **Step 1: Write the failing test**

`packages/crossword_core/test/gameplay/domain/services/arrow_shape_resolver_test.dart`:
```dart
import 'package:crossword_core/crossword_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ArrowShapeResolver', () {
    test('start directly right of clue, running right → straightRight', () {
      expect(
        ArrowShapeResolver.resolve(
          clueRow: 0, clueCol: 0, startRow: 0, startCol: 1,
          base: Direction.right),
        ArrowShape.straightRight,
      );
    });

    test('start below clue, running right → bentDownThenRight', () {
      expect(
        ArrowShapeResolver.resolve(
          clueRow: 0, clueCol: 0, startRow: 1, startCol: 0,
          base: Direction.right),
        ArrowShape.bentDownThenRight,
      );
    });

    test('start below clue, running down → straightDown', () {
      expect(
        ArrowShapeResolver.resolve(
          clueRow: 0, clueCol: 0, startRow: 1, startCol: 0,
          base: Direction.down),
        ArrowShape.straightDown,
      );
    });

    test('start left of clue, running down → bentLeftThenDown', () {
      expect(
        ArrowShapeResolver.resolve(
          clueRow: 0, clueCol: 1, startRow: 1, startCol: 0,
          base: Direction.down),
        ArrowShape.bentLeftThenDown,
      );
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/gameplay/domain/services/arrow_shape_resolver_test.dart` (from `packages/crossword_core`)
Expected: FAIL — `ArrowShapeResolver` undefined.

- [ ] **Step 3: Create the resolver**

`packages/crossword_core/lib/gameplay/domain/services/arrow_shape_resolver.dart`:
```dart
import '../entities/arrow_shape.dart';
import '../entities/direction.dart';

/// Picks the clue's arrow glyph from where its word starts relative to the
/// clue cell and which way the word travels. The start cell is adjacent to the
/// clue on one side; the word then runs in [base]. A start on the same axis as
/// travel is a straight arrow; a start on the perpendicular side is a bent
/// (L-shaped) arrow that leaves the clue toward the start and then turns.
class ArrowShapeResolver {
  const ArrowShapeResolver._();

  static ArrowShape resolve({
    required int clueRow,
    required int clueCol,
    required int startRow,
    required int startCol,
    required Direction base,
  }) {
    final dr = startRow - clueRow;
    final dc = startCol - clueCol;
    if (base == Direction.right) {
      if (dr == 0 && dc == 1) return ArrowShape.straightRight;
      if (dr == -1 && dc == 0) return ArrowShape.bentUpThenRight;
      return ArrowShape.bentDownThenRight; // start below (or fallback)
    }
    if (dr == 1 && dc == 0) return ArrowShape.straightDown;
    if (dr == 0 && dc == -1) return ArrowShape.bentLeftThenDown;
    return ArrowShape.bentRightThenDown; // start to the right (or fallback)
  }
}
```

- [ ] **Step 4: Export it**

In `packages/crossword_core/lib/crossword_core.dart`, add:
```dart
export 'gameplay/domain/services/arrow_shape_resolver.dart';
```

- [ ] **Step 5: Refactor `PuzzleResolver` to use it**

In `packages/crossword_core/lib/gameplay/data/puzzle_resolver.dart`:
- Add import: `import '../domain/services/arrow_shape_resolver.dart';`
- Replace the two `_arrowShape(r, c, cell.rightStart!, Direction.right)` / `...downStart!, Direction.down` calls with:
```dart
shape: ArrowShapeResolver.resolve(
  clueRow: r,
  clueCol: c,
  startRow: cell.rightStart!.row,
  startCol: cell.rightStart!.col,
  base: Direction.right,
),
```
and the down variant with `startRow: cell.downStart!.row, startCol: cell.downStart!.col, base: Direction.down`.
- Delete the private `static ArrowShape _arrowShape(...)` method.

- [ ] **Step 6: Run the resolver test and the existing resolver suite**

Run: `flutter test test/gameplay/domain/services/arrow_shape_resolver_test.dart test/` (from `packages/crossword_core`)
Expected: PASS — new test passes and the existing `puzzle_resolver` tests still pass (arrows unchanged).

- [ ] **Step 7: Commit**

```bash
git add packages/crossword_core
git commit -m "refactor(core): extract ArrowShapeResolver for reuse"
```

---

### Task 3: Request DTO — `CrosswordGenerationRequest`

**Files:**
- Create: `packages/crossword_api/lib/src/dto/crossword_generation_request.dart`
- Modify: `packages/crossword_api/lib/crossword_api.dart` (export)
- Test: `packages/crossword_api/test/dto/crossword_generation_request_test.dart`

**Interfaces:**
- Produces: `CrosswordGenerationRequest({required int width, required int height, required int maxWordLen, List<String> seedWords})` with `Map<String,dynamic> toJson()`.

- [ ] **Step 1: Write the failing test**

`packages/crossword_api/test/dto/crossword_generation_request_test.dart`:
```dart
import 'package:crossword_api/crossword_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('toJson sends user params plus fixed sv/pictures-off defaults', () {
    final json = const CrosswordGenerationRequest(
      width: 15,
      height: 15,
      maxWordLen: 6,
      seedWords: ['KATT', 'HUND'],
    ).toJson();

    expect(json['width'], 15);
    expect(json['height'], 15);
    expect(json['max_word_len'], 6);
    expect(json['seed_words'], ['KATT', 'HUND']);
    expect(json['language_code'], 'sv');
    expect(json['picture_cols'], 0);
    expect(json['picture_rows'], 0);
    expect(json['max_seconds'], 30);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/dto/crossword_generation_request_test.dart` (from `packages/crossword_api`)
Expected: FAIL — `CrosswordGenerationRequest` undefined.

- [ ] **Step 3: Create the DTO**

`packages/crossword_api/lib/src/dto/crossword_generation_request.dart`:
```dart
/// Request body for `POST /crossword-puzzles/generate`. Exposes the three
/// user-controlled params; language is fixed to Swedish and pictures are off
/// (image clues are not supported yet).
class CrosswordGenerationRequest {
  final int width;
  final int height;
  final int maxWordLen;
  final List<String> seedWords;

  const CrosswordGenerationRequest({
    required this.width,
    required this.height,
    required this.maxWordLen,
    this.seedWords = const [],
  });

  Map<String, dynamic> toJson() => {
        'width': width,
        'height': height,
        'language_code': 'sv',
        'seed_words': seedWords,
        'max_seconds': 30,
        'max_word_len': maxWordLen,
        'picture_cols': 0,
        'picture_rows': 0,
      };
}
```

- [ ] **Step 4: Export it**

In `packages/crossword_api/lib/crossword_api.dart`, add:
```dart
export 'src/dto/crossword_generation_request.dart';
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/dto/crossword_generation_request_test.dart` (from `packages/crossword_api`)
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add packages/crossword_api
git commit -m "feat(api): add CrosswordGenerationRequest DTO"
```

---

### Task 4: Response DTOs — `CrosswordGenerationResponse` + nested

**Files:**
- Create: `packages/crossword_api/lib/src/dto/crossword_generation_response.dart`
- Create: `packages/crossword_api/test/fixtures/generation_response_9x9.json` (the saved live sample)
- Modify: `packages/crossword_api/lib/crossword_api.dart` (export)
- Modify: `packages/crossword_api/pubspec.yaml` (add fixture under `flutter:` assets only if loaded via rootBundle — NOT needed; tests read the file directly)
- Test: `packages/crossword_api/test/dto/crossword_generation_response_test.dart`

**Interfaces:**
- Produces:
  - `CrosswordGenerationResponse.fromJson(Map<String,dynamic>)` with fields: `bool success`, `String? failureReason`, `List<List<GenerationGridCellDto>>? gridCells`, `List<GenerationSlotDto>? slots`, `List<GenerationAssignmentDto>? assignments`, `List<GenerationSeedCellDto>? seedCells`.
  - `GenerationGridCellDto`: `String kind`, `int row`, `int col`, `int rowspan`, `int colspan`, `String? letter`, `List<GenerationClueTagDto> clueTags`, `String sepRight`, `String sepBottom`.
  - `GenerationClueTagDto`: `int id`, `String arrow`.
  - `GenerationSlotDto`: `int slotId`, `int startRow`, `int startCol`, `String direction`, `int length`, `int clueRow`, `int clueCol`.
  - `GenerationAssignmentDto`: `int slotId`, `String word`.
  - `GenerationSeedCellDto`: `int row`, `int col`, `String letter`.

- [ ] **Step 1: Add the test fixture**

Copy the saved sample to the fixture path (run from repo root):
```bash
mkdir -p packages/crossword_api/test/fixtures
cp "$CLAUDE_JOB_DIR/tmp/real_response.json" packages/crossword_api/test/fixtures/generation_response_9x9.json
```
If that file is gone, regenerate it:
```bash
curl -s -X POST https://api.ikors.se/crossword-puzzles/generate \
  -H "Content-Type: application/json" \
  -d '{"width":9,"height":9,"language_code":"sv","max_seconds":15,"max_word_len":6,"picture_cols":0,"picture_rows":0,"random_seed":42}' \
  -o packages/crossword_api/test/fixtures/generation_response_9x9.json
```

- [ ] **Step 2: Write the failing test**

`packages/crossword_api/test/dto/crossword_generation_response_test.dart`:
```dart
import 'dart:convert';
import 'dart:io';

import 'package:crossword_api/crossword_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fromJson parses the live 9x9 sample', () {
    final raw = File('test/fixtures/generation_response_9x9.json')
        .readAsStringSync();
    final res = CrosswordGenerationResponse.fromJson(
        jsonDecode(raw) as Map<String, dynamic>);

    expect(res.success, isTrue);
    expect(res.failureReason, isNull);
    expect(res.gridCells, isNotNull);
    expect(res.gridCells!.length, 9);
    expect(res.gridCells!.first.length, 9);
    expect(res.slots!.length, 26);
    expect(res.assignments!.length, 26);

    final slot0 = res.slots!.firstWhere((s) => s.slotId == 0);
    expect(slot0.direction, 'right');
    expect(slot0.length, 5);
    expect(slot0.startRow, 1);
    expect(slot0.startCol, 0);

    final word0 =
        res.assignments!.firstWhere((a) => a.slotId == 0).word;
    expect(word0, 'KRÖKT');

    final clueCell = res.gridCells![0][0];
    expect(clueCell.kind, 'clue');
    expect(clueCell.clueTags.single.id, 0);
    expect(clueCell.clueTags.single.arrow, '→');
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/dto/crossword_generation_response_test.dart` (from `packages/crossword_api`)
Expected: FAIL — `CrosswordGenerationResponse` undefined.

- [ ] **Step 4: Create the response DTOs**

`packages/crossword_api/lib/src/dto/crossword_generation_response.dart`:
```dart
/// Parsed body of `POST /crossword-puzzles/generate`. Only the fields the
/// mapper needs are parsed; `cells`, `stats`, and clue-generation fields are
/// intentionally ignored for now.
class CrosswordGenerationResponse {
  final bool success;
  final String? failureReason;
  final List<List<GenerationGridCellDto>>? gridCells;
  final List<GenerationSlotDto>? slots;
  final List<GenerationAssignmentDto>? assignments;
  final List<GenerationSeedCellDto>? seedCells;

  const CrosswordGenerationResponse({
    required this.success,
    this.failureReason,
    this.gridCells,
    this.slots,
    this.assignments,
    this.seedCells,
  });

  factory CrosswordGenerationResponse.fromJson(Map<String, dynamic> json) {
    final rawGrid = json['grid_cells'] as List<dynamic>?;
    final rawSlots = json['slots'] as List<dynamic>?;
    final rawAssign = json['assignments'] as List<dynamic>?;
    final rawSeeds = json['seed_cells'] as List<dynamic>?;

    return CrosswordGenerationResponse(
      success: json['success'] as bool,
      failureReason: json['failure_reason'] as String?,
      gridCells: rawGrid
          ?.map((row) => (row as List<dynamic>)
              .map((c) =>
                  GenerationGridCellDto.fromJson(c as Map<String, dynamic>))
              .toList())
          .toList(),
      slots: rawSlots
          ?.map((s) => GenerationSlotDto.fromJson(s as Map<String, dynamic>))
          .toList(),
      assignments: rawAssign
          ?.map((a) =>
              GenerationAssignmentDto.fromJson(a as Map<String, dynamic>))
          .toList(),
      seedCells: rawSeeds
          ?.map((s) => GenerationSeedCellDto.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}

class GenerationGridCellDto {
  final String kind;
  final int row;
  final int col;
  final int rowspan;
  final int colspan;
  final String? letter;
  final List<GenerationClueTagDto> clueTags;
  final String sepRight;
  final String sepBottom;

  const GenerationGridCellDto({
    required this.kind,
    required this.row,
    required this.col,
    this.rowspan = 1,
    this.colspan = 1,
    this.letter,
    this.clueTags = const [],
    this.sepRight = '',
    this.sepBottom = '',
  });

  factory GenerationGridCellDto.fromJson(Map<String, dynamic> json) {
    final rawTags = json['clue_tags'] as List<dynamic>?;
    return GenerationGridCellDto(
      kind: json['kind'] as String,
      row: json['row'] as int,
      col: json['col'] as int,
      rowspan: json['rowspan'] as int? ?? 1,
      colspan: json['colspan'] as int? ?? 1,
      letter: json['letter'] as String?,
      clueTags: rawTags
              ?.map((t) =>
                  GenerationClueTagDto.fromJson(t as Map<String, dynamic>))
              .toList() ??
          const [],
      sepRight: json['sep_right'] as String? ?? '',
      sepBottom: json['sep_bottom'] as String? ?? '',
    );
  }
}

class GenerationClueTagDto {
  final int id;
  final String arrow;

  const GenerationClueTagDto({required this.id, required this.arrow});

  factory GenerationClueTagDto.fromJson(Map<String, dynamic> json) =>
      GenerationClueTagDto(
        id: json['id'] as int,
        arrow: json['arrow'] as String,
      );
}

class GenerationSlotDto {
  final int slotId;
  final int startRow;
  final int startCol;
  final String direction;
  final int length;
  final int clueRow;
  final int clueCol;

  const GenerationSlotDto({
    required this.slotId,
    required this.startRow,
    required this.startCol,
    required this.direction,
    required this.length,
    required this.clueRow,
    required this.clueCol,
  });

  factory GenerationSlotDto.fromJson(Map<String, dynamic> json) =>
      GenerationSlotDto(
        slotId: json['slot_id'] as int,
        startRow: json['start_row'] as int,
        startCol: json['start_col'] as int,
        direction: json['direction'] as String,
        length: json['length'] as int,
        clueRow: json['clue_row'] as int,
        clueCol: json['clue_col'] as int,
      );
}

class GenerationAssignmentDto {
  final int slotId;
  final String word;

  const GenerationAssignmentDto({required this.slotId, required this.word});

  factory GenerationAssignmentDto.fromJson(Map<String, dynamic> json) =>
      GenerationAssignmentDto(
        slotId: json['slot_id'] as int,
        word: json['word'] as String,
      );
}

class GenerationSeedCellDto {
  final int row;
  final int col;
  final String letter;

  const GenerationSeedCellDto({
    required this.row,
    required this.col,
    required this.letter,
  });

  factory GenerationSeedCellDto.fromJson(Map<String, dynamic> json) =>
      GenerationSeedCellDto(
        row: json['row'] as int,
        col: json['col'] as int,
        letter: json['letter'] as String,
      );
}
```

- [ ] **Step 5: Export it**

In `packages/crossword_api/lib/crossword_api.dart`, add:
```dart
export 'src/dto/crossword_generation_response.dart';
```

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/dto/crossword_generation_response_test.dart` (from `packages/crossword_api`)
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add packages/crossword_api
git commit -m "feat(api): add CrosswordGenerationResponse DTOs + fixture"
```

---

### Task 5: `GeneratedPuzzleMapper` — response → `CrosswordPuzzle`

**Files:**
- Create: `packages/crossword_api/lib/src/generated_puzzle_mapper.dart`
- Modify: `packages/crossword_api/lib/crossword_api.dart` (export)
- Test: `packages/crossword_api/test/generated_puzzle_mapper_test.dart`

**Interfaces:**
- Consumes: `CrosswordGenerationResponse` (Task 4); `ArrowShapeResolver`, `CrosswordPuzzle`, `Cell` subtypes, `Word`, `Direction`, `ClueArrow` (crossword_core).
- Produces: `GeneratedPuzzleMapper.map(CrosswordGenerationResponse response, {required String title}) → CrosswordPuzzle`.

- [ ] **Step 1: Write the failing test**

`packages/crossword_api/test/generated_puzzle_mapper_test.dart`:
```dart
import 'dart:convert';
import 'dart:io';

import 'package:crossword_api/crossword_api.dart';
import 'package:crossword_core/crossword_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late CrosswordPuzzle puzzle;

  setUp(() {
    final raw = File('test/fixtures/generation_response_9x9.json')
        .readAsStringSync();
    final res = CrosswordGenerationResponse.fromJson(
        jsonDecode(raw) as Map<String, dynamic>);
    puzzle = GeneratedPuzzleMapper.map(res, title: 'Test');
  });

  test('grid dimensions and language', () {
    expect(puzzle.rows, 9);
    expect(puzzle.cols, 9);
    expect(puzzle.languageCode, 'sv');
    expect(puzzle.title, 'Test');
  });

  test('answer cell letters come from grid_cells', () {
    final cell = puzzle.cells[(0, 2)];
    expect(cell, isA<AnswerCell>());
    expect((cell! as AnswerCell).value, 'R');
  });

  test('clue cells become ClueCell with arrows', () {
    expect(puzzle.cells[(0, 0)], isA<ClueCell>());
  });

  test('slot 0 word KRÖKT is built right from (1,0)', () {
    final word = puzzle.wordById('0');
    expect(word, isNotNull);
    expect(word!.direction, Direction.right);
    expect(word.cells.first, (1, 0));
    expect(word.cells.length, 5);
  });

  test('clue at (0,0) for rightward word starting (1,0) is bentDownThenRight',
      () {
    final clue = puzzle.cells[(0, 0)]! as ClueCell;
    final arrow = clue.arrows.firstWhere((a) => a.wordId == '0');
    expect(arrow.direction, Direction.right);
    expect(arrow.shape, ArrowShape.bentDownThenRight);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/generated_puzzle_mapper_test.dart` (from `packages/crossword_api`)
Expected: FAIL — `GeneratedPuzzleMapper` undefined.

- [ ] **Step 3: Create the mapper**

`packages/crossword_api/lib/src/generated_puzzle_mapper.dart`:
```dart
import 'package:crossword_core/crossword_core.dart';

import 'dto/crossword_generation_response.dart';

/// Converts a successful [CrosswordGenerationResponse] into a playable
/// [CrosswordPuzzle]. Slots are straight runs; each becomes one [Word], and
/// each clue tag becomes a [ClueArrow] whose glyph is derived from the clue's
/// position relative to its slot's start. Clue prose is not provided by the
/// generator yet, so [Word.clueText] stays null.
class GeneratedPuzzleMapper {
  const GeneratedPuzzleMapper._();

  static CrosswordPuzzle map(
    CrosswordGenerationResponse response, {
    required String title,
  }) {
    final gridCells = response.gridCells ?? const [];
    final slots = response.slots ?? const [];
    final assignments = response.assignments ?? const [];
    final seedCells = response.seedCells ?? const [];

    final rows = gridCells.length;
    final cols = rows == 0 ? 0 : gridCells.first.length;

    final wordBySlot = {for (final a in assignments) a.slotId: a.word};
    final slotById = {for (final s in slots) s.slotId: s};

    final cells = <(int, int), Cell>{};
    final separatorEdges = <(int, int), Set<Direction>>{};
    final seedPositions = <(int, int)>{
      for (final s in seedCells) (s.row, s.col),
    };

    for (final row in gridCells) {
      for (final c in row) {
        final pos = (c.row, c.col);
        switch (c.kind) {
          case 'answer':
            cells[pos] = AnswerCell(
              value: c.letter ?? '',
              isSeed: seedPositions.contains(pos),
            );
            if (c.sepRight.isNotEmpty) {
              separatorEdges
                  .putIfAbsent(pos, () => <Direction>{})
                  .add(Direction.right);
            }
            if (c.sepBottom.isNotEmpty) {
              separatorEdges
                  .putIfAbsent(pos, () => <Direction>{})
                  .add(Direction.down);
            }
          case 'clue':
            cells[pos] = ClueCell(
              arrows: [
                for (final tag in c.clueTags)
                  if (slotById[tag.id] case final slot?)
                    ClueArrow(
                      direction: _direction(slot.direction),
                      shape: ArrowShapeResolver.resolve(
                        clueRow: slot.clueRow,
                        clueCol: slot.clueCol,
                        startRow: slot.startRow,
                        startCol: slot.startCol,
                        base: _direction(slot.direction),
                      ),
                      wordId: slot.slotId.toString(),
                    ),
              ],
            );
          default:
            // 'picture' / 'arrow' kinds are not produced with pictures off;
            // treat anything else as an inert block.
            cells[pos] = const BlockCell();
        }
      }
    }

    final words = <Word>[];
    for (final slot in slots) {
      final dir = _direction(slot.direction);
      final path = <(int, int)>[];
      for (var i = 0; i < slot.length; i++) {
        final r = dir == Direction.right ? slot.startRow : slot.startRow + i;
        final cc = dir == Direction.right ? slot.startCol + i : slot.startCol;
        path.add((r, cc));
      }
      words.add(Word(
        id: slot.slotId.toString(),
        direction: dir,
        cells: path,
      ));
    }

    return CrosswordPuzzle(
      rows: rows,
      cols: cols,
      cells: cells,
      words: words,
      seedPositions: seedPositions,
      separatorEdges: separatorEdges,
      title: title,
      languageCode: 'sv',
    );
  }

  static Direction _direction(String raw) =>
      raw == 'down' ? Direction.down : Direction.right;
}
```

- [ ] **Step 4: Export it**

In `packages/crossword_api/lib/crossword_api.dart`, add:
```dart
export 'src/generated_puzzle_mapper.dart';
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/generated_puzzle_mapper_test.dart` (from `packages/crossword_api`)
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add packages/crossword_api
git commit -m "feat(api): map generation response to CrosswordPuzzle"
```

---

### Task 6: `CrosswordGenerationRemoteDataSource` + exception

**Files:**
- Create: `packages/crossword_api/lib/src/crossword_generation_exception.dart`
- Create: `packages/crossword_api/lib/src/crossword_generation_remote_data_source.dart`
- Modify: `packages/crossword_api/lib/crossword_api.dart` (exports)
- Test: `packages/crossword_api/test/crossword_generation_remote_data_source_test.dart`

**Interfaces:**
- Consumes: `CrosswordGenerationRequest`, `CrosswordGenerationResponse`; `package:http`.
- Produces:
  - `CrosswordGenerationException(String message)` (implements `Exception`, has `final String message`).
  - `CrosswordGenerationRemoteDataSource({http.Client? client, String baseUrl})` with `Future<CrosswordGenerationResponse> generate(CrosswordGenerationRequest request)`. Throws `CrosswordGenerationException` on non-200 or `success: false`.

- [ ] **Step 1: Write the failing test**

`packages/crossword_api/test/crossword_generation_remote_data_source_test.dart`:
```dart
import 'dart:convert';
import 'dart:io';

import 'package:crossword_api/crossword_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const request = CrosswordGenerationRequest(
    width: 9, height: 9, maxWordLen: 6,
  );

  test('posts to the generate endpoint and parses a success body', () async {
    final body =
        File('test/fixtures/generation_response_9x9.json').readAsStringSync();
    late http.Request captured;
    final client = MockClient((req) async {
      captured = req;
      return http.Response(body, 200,
          headers: {'content-type': 'application/json'});
    });

    final source = CrosswordGenerationRemoteDataSource(client: client);
    final res = await source.generate(request);

    expect(captured.method, 'POST');
    expect(captured.url.toString(),
        'https://api.ikors.se/crossword-puzzles/generate');
    expect((jsonDecode(captured.body) as Map)['width'], 9);
    expect(res.success, isTrue);
  });

  test('throws on non-200', () async {
    final client = MockClient((req) async => http.Response('nope', 500));
    final source = CrosswordGenerationRemoteDataSource(client: client);
    expect(
      () => source.generate(request),
      throwsA(isA<CrosswordGenerationException>()),
    );
  });

  test('throws on success:false carrying the failure reason', () async {
    final client = MockClient((req) async => http.Response(
        jsonEncode({'success': false, 'failure_reason': 'no fit', 'random_seed': 1, 'stats': {}}),
        200));
    final source = CrosswordGenerationRemoteDataSource(client: client);
    expect(
      () => source.generate(request),
      throwsA(predicate((e) =>
          e is CrosswordGenerationException && e.message.contains('no fit'))),
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/crossword_generation_remote_data_source_test.dart` (from `packages/crossword_api`)
Expected: FAIL — types undefined.

- [ ] **Step 3: Create the exception**

`packages/crossword_api/lib/src/crossword_generation_exception.dart`:
```dart
/// Raised when crossword generation fails — a transport error, a non-200
/// response, or a body with `success: false`.
class CrosswordGenerationException implements Exception {
  final String message;

  const CrosswordGenerationException(this.message);

  @override
  String toString() => 'CrosswordGenerationException: $message';
}
```

- [ ] **Step 4: Create the remote data source**

`packages/crossword_api/lib/src/crossword_generation_remote_data_source.dart`:
```dart
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'crossword_generation_exception.dart';
import 'dto/crossword_generation_request.dart';
import 'dto/crossword_generation_response.dart';

/// Calls `POST /crossword-puzzles/generate` and returns the parsed response.
class CrosswordGenerationRemoteDataSource {
  static const String _defaultBaseUrl = 'https://api.ikors.se';

  final http.Client _client;
  final String _baseUrl;

  CrosswordGenerationRemoteDataSource({
    http.Client? client,
    String baseUrl = _defaultBaseUrl,
  })  : _client = client ?? http.Client(),
        _baseUrl = baseUrl;

  Future<CrosswordGenerationResponse> generate(
    CrosswordGenerationRequest request,
  ) async {
    final uri = Uri.parse('$_baseUrl/crossword-puzzles/generate');
    final http.Response response;
    try {
      response = await _client.post(
        uri,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode(request.toJson()),
      );
    } catch (e) {
      throw CrosswordGenerationException('Network error: $e');
    }

    if (response.statusCode != 200) {
      throw CrosswordGenerationException(
        'Server returned ${response.statusCode}',
      );
    }

    final parsed = CrosswordGenerationResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
    if (!parsed.success) {
      throw CrosswordGenerationException(
        parsed.failureReason ?? 'Generation failed',
      );
    }
    return parsed;
  }
}
```

- [ ] **Step 5: Export them**

In `packages/crossword_api/lib/crossword_api.dart`, add:
```dart
export 'src/crossword_generation_exception.dart';
export 'src/crossword_generation_remote_data_source.dart';
```

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/crossword_generation_remote_data_source_test.dart` (from `packages/crossword_api`)
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add packages/crossword_api
git commit -m "feat(api): add generation remote data source"
```

---

### Task 7: `CrosswordGenerationRepository`

**Files:**
- Create: `packages/crossword_api/lib/src/crossword_generation_repository.dart`
- Modify: `packages/crossword_api/lib/crossword_api.dart` (export)
- Test: `packages/crossword_api/test/crossword_generation_repository_test.dart`

**Interfaces:**
- Consumes: `CrosswordGenerationRemoteDataSource`, `CrosswordGenerationRequest`, `GeneratedPuzzleMapper`.
- Produces: `CrosswordGenerationRepository({required CrosswordGenerationRemoteDataSource remoteDataSource})` with `Future<CrosswordPuzzle> generate({required int width, required int height, required int maxWordLen, List<String> seedWords, required String title})`.

- [ ] **Step 1: Write the failing test**

`packages/crossword_api/test/crossword_generation_repository_test.dart`:
```dart
import 'dart:convert';
import 'dart:io';

import 'package:crossword_api/crossword_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  CrosswordGenerationRepository repoWith(MockClient client) =>
      CrosswordGenerationRepository(
        remoteDataSource:
            CrosswordGenerationRemoteDataSource(client: client),
      );

  test('returns a mapped CrosswordPuzzle on success', () async {
    final body =
        File('test/fixtures/generation_response_9x9.json').readAsStringSync();
    final repo = repoWith(MockClient((req) async => http.Response(body, 200)));

    final puzzle = await repo.generate(
      width: 9, height: 9, maxWordLen: 6, title: 'Nytt korsord',
    );

    expect(puzzle.rows, 9);
    expect(puzzle.title, 'Nytt korsord');
    expect(puzzle.wordById('0'), isNotNull);
  });

  test('propagates CrosswordGenerationException on failure', () async {
    final repo = repoWith(MockClient((req) async => http.Response('x', 500)));
    expect(
      () => repo.generate(width: 9, height: 9, maxWordLen: 6, title: 'x'),
      throwsA(isA<CrosswordGenerationException>()),
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/crossword_generation_repository_test.dart` (from `packages/crossword_api`)
Expected: FAIL — `CrosswordGenerationRepository` undefined.

- [ ] **Step 3: Create the repository**

`packages/crossword_api/lib/src/crossword_generation_repository.dart`:
```dart
import 'package:crossword_core/crossword_core.dart';

import 'crossword_generation_remote_data_source.dart';
import 'dto/crossword_generation_request.dart';
import 'generated_puzzle_mapper.dart';

/// Coordinates the remote data source and the mapper, returning a playable
/// [CrosswordPuzzle].
class CrosswordGenerationRepository {
  final CrosswordGenerationRemoteDataSource _remoteDataSource;

  CrosswordGenerationRepository({
    required CrosswordGenerationRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  Future<CrosswordPuzzle> generate({
    required int width,
    required int height,
    required int maxWordLen,
    required String title,
    List<String> seedWords = const [],
  }) async {
    final response = await _remoteDataSource.generate(
      CrosswordGenerationRequest(
        width: width,
        height: height,
        maxWordLen: maxWordLen,
        seedWords: seedWords,
      ),
    );
    return GeneratedPuzzleMapper.map(response, title: title);
  }
}
```

- [ ] **Step 4: Export it**

In `packages/crossword_api/lib/crossword_api.dart`, add:
```dart
export 'src/crossword_generation_repository.dart';
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/crossword_generation_repository_test.dart` (from `packages/crossword_api`)
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add packages/crossword_api
git commit -m "feat(api): add CrosswordGenerationRepository"
```

---

### Task 8: `PuzzleGenerationService`

**Files:**
- Create: `packages/crossword_api/lib/src/puzzle_generation_service.dart`
- Modify: `packages/crossword_api/lib/crossword_api.dart` (export)
- Test: `packages/crossword_api/test/puzzle_generation_service_test.dart`

**Interfaces:**
- Consumes: `CrosswordGenerationRepository`; `loadBundledPuzzle` (crossword_core).
- Produces: `PuzzleGenerationService({required CrosswordGenerationRepository repository, Future<CrosswordPuzzle> Function()? loadTestPuzzleFn})` with:
  - `Future<CrosswordPuzzle> generate({required int width, required int height, required int maxWordLen, required String title, List<String> seedWords})`
  - `Future<CrosswordPuzzle> loadTestPuzzle()`

  The optional `loadTestPuzzleFn` defaults to `loadBundledPuzzle` and exists so tests can inject a fake.

- [ ] **Step 1: Write the failing test**

`packages/crossword_api/test/puzzle_generation_service_test.dart`:
```dart
import 'dart:convert';
import 'dart:io';

import 'package:crossword_api/crossword_api.dart';
import 'package:crossword_core/crossword_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('generate delegates to the repository', () async {
    final body =
        File('test/fixtures/generation_response_9x9.json').readAsStringSync();
    final service = PuzzleGenerationService(
      repository: CrosswordGenerationRepository(
        remoteDataSource: CrosswordGenerationRemoteDataSource(
          client: MockClient((req) async => http.Response(body, 200)),
        ),
      ),
    );

    final puzzle = await service.generate(
      width: 9, height: 9, maxWordLen: 6, title: 'X',
    );
    expect(puzzle.rows, 9);
  });

  test('loadTestPuzzle uses the injected loader', () async {
    final fake = CrosswordPuzzle(
      rows: 1, cols: 1, cells: const {}, words: const [],
      title: 'bundled', languageCode: 'sv',
    );
    final service = PuzzleGenerationService(
      repository: CrosswordGenerationRepository(
        remoteDataSource: CrosswordGenerationRemoteDataSource(
          client: MockClient((req) async => http.Response('{}', 500)),
        ),
      ),
      loadTestPuzzleFn: () async => fake,
    );

    final puzzle = await service.loadTestPuzzle();
    expect(puzzle.title, 'bundled');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/puzzle_generation_service_test.dart` (from `packages/crossword_api`)
Expected: FAIL — `PuzzleGenerationService` undefined.

- [ ] **Step 3: Create the service**

`packages/crossword_api/lib/src/puzzle_generation_service.dart`:
```dart
import 'package:crossword_core/crossword_core.dart';

import 'crossword_generation_repository.dart';

/// Domain entry point for puzzle acquisition. Cubits depend on this rather than
/// the repository directly. [loadTestPuzzle] returns the bundled developer
/// puzzle.
class PuzzleGenerationService {
  final CrosswordGenerationRepository _repository;
  final Future<CrosswordPuzzle> Function() _loadTestPuzzleFn;

  PuzzleGenerationService({
    required CrosswordGenerationRepository repository,
    Future<CrosswordPuzzle> Function()? loadTestPuzzleFn,
  })  : _repository = repository,
        _loadTestPuzzleFn = loadTestPuzzleFn ?? loadBundledPuzzle;

  Future<CrosswordPuzzle> generate({
    required int width,
    required int height,
    required int maxWordLen,
    required String title,
    List<String> seedWords = const [],
  }) =>
      _repository.generate(
        width: width,
        height: height,
        maxWordLen: maxWordLen,
        title: title,
        seedWords: seedWords,
      );

  Future<CrosswordPuzzle> loadTestPuzzle() => _loadTestPuzzleFn();
}
```

- [ ] **Step 4: Export it**

In `packages/crossword_api/lib/crossword_api.dart`, add:
```dart
export 'src/puzzle_generation_service.dart';
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/puzzle_generation_service_test.dart` (from `packages/crossword_api`)
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add packages/crossword_api
git commit -m "feat(api): add PuzzleGenerationService"
```

---

### Task 9: Add Swedish strings for the generate screen

**Files:**
- Modify: `packages/crossword_ui/lib/common/data/constants/strings.dart`

**Interfaces:**
- Produces: new `Strings` constants used by Task 10/11: `generateTitle`, `generateSizeLabel`, `generateMaxWordLenLabel`, `generateSeedWordsLabel`, `generateSeedWordsHint`, `generateAction`, `generatingLabel`, `generateTestPuzzleAction`, `generatedPuzzleTitle`, `generationErrorMessage`.

- [ ] **Step 1: Add the constants**

Append inside the `Strings` class in `packages/crossword_ui/lib/common/data/constants/strings.dart`:
```dart
  /// Generate screen.
  static const String generateTitle = 'Skapa korsord';
  static const String generateSizeLabel = 'Storlek';
  static const String generateMaxWordLenLabel = 'Längsta ord';
  static const String generateSeedWordsLabel = 'Egna ord';
  static const String generateSeedWordsHint = 'Skilj orden med komma';
  static const String generateAction = 'Skapa';
  static const String generatingLabel = 'Skapar…';
  static const String generateTestPuzzleAction = 'Testkorsord';
  static const String generatedPuzzleTitle = 'Korsord';
  static const String generationErrorMessage =
      'Kunde inte skapa korsordet. Försök igen.';
```

- [ ] **Step 2: Verify it compiles**

Run: `flutter analyze packages/crossword_ui/lib/common/data/constants/strings.dart`
Expected: No issues.

- [ ] **Step 3: Commit**

```bash
git add packages/crossword_ui/lib/common/data/constants/strings.dart
git commit -m "feat(ui): add generate-screen strings"
```

---

### Task 10: `GeneratePuzzleCubit` + state

**Files:**
- Create: `packages/crossword_ui/lib/gameplay/presentation/generate_screen/cubit/generate_state.dart`
- Create: `packages/crossword_ui/lib/gameplay/presentation/generate_screen/cubit/generate_cubit.dart`
- Modify: `packages/crossword_ui/lib/crossword_ui.dart` (exports)
- Test: `packages/crossword_ui/test/gameplay/presentation/generate_screen/generate_cubit_test.dart`

**Interfaces:**
- Consumes: `PuzzleGenerationService` (crossword_api); `CrosswordPuzzle` (crossword_core); `Strings`.
- Produces:
  - `GenerateState({int width, int height, int maxWordLen, bool isGenerating})` with `copyWith`, presets list constants, and `props`. Defaults: `width=15, height=15, maxWordLen=6, isGenerating=false`.
  - Event states `GenerationSucceeded(CrosswordPuzzle puzzle)` and `ShowGenerationError(String message)`, each `extends GenerateState`, with `final Key key = UniqueKey();`.
  - `GeneratePuzzleCubit({required PuzzleGenerationService service})` with `TextEditingController seedWordsController`, methods `selectSize(int)`, `selectMaxWordLen(int)`, `generate()`, `openTestPuzzle()`, and `close()` disposing the controller.

- [ ] **Step 1: Write the failing test**

`packages/crossword_ui/test/gameplay/presentation/generate_screen/generate_cubit_test.dart`:

> Convention: this repo does NOT use `bloc_test`. Match the existing cubit
> tests — drive the cubit and assert on `cubit.state` / collected stream
> emissions with plain `test()`.

```dart
import 'package:crossword_api/crossword_api.dart';
import 'package:crossword_core/crossword_core.dart';
import 'package:crossword_ui/crossword_ui.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeService implements PuzzleGenerationService {
  final CrosswordPuzzle? puzzle;
  final Object? error;
  _FakeService({this.puzzle, this.error});

  @override
  Future<CrosswordPuzzle> generate({
    required int width,
    required int height,
    required int maxWordLen,
    required String title,
    List<String> seedWords = const [],
  }) async {
    if (error != null) throw error!;
    return puzzle!;
  }

  @override
  Future<CrosswordPuzzle> loadTestPuzzle() async {
    if (error != null) throw error!;
    return puzzle!;
  }
}

CrosswordPuzzle _puzzle() => const CrosswordPuzzle(
      rows: 1, cols: 1, cells: {}, words: [],
      title: 'X', languageCode: 'sv',
    );

/// Runs [action], collecting every state the cubit emits during it.
Future<List<GenerateState>> _collect(
  GeneratePuzzleCubit cubit,
  Future<void> Function() action,
) async {
  final states = <GenerateState>[];
  final sub = cubit.stream.listen(states.add);
  await action();
  await sub.cancel();
  return states;
}

void main() {
  test('selectSize updates width and height', () async {
    final cubit = GeneratePuzzleCubit(service: _FakeService());
    cubit.selectSize(17);
    expect(cubit.state.width, 17);
    expect(cubit.state.height, 17);
    await cubit.close();
  });

  test('selectMaxWordLen updates maxWordLen', () async {
    final cubit = GeneratePuzzleCubit(service: _FakeService());
    cubit.selectMaxWordLen(8);
    expect(cubit.state.maxWordLen, 8);
    await cubit.close();
  });

  test('generate emits generating then GenerationSucceeded', () async {
    final cubit = GeneratePuzzleCubit(service: _FakeService(puzzle: _puzzle()));
    final states = await _collect(cubit, cubit.generate);
    expect(states.first.isGenerating, isTrue);
    expect(states.last, isA<GenerationSucceeded>());
    expect((states.last as GenerationSucceeded).puzzle.title, 'X');
    await cubit.close();
  });

  test('generate emits ShowGenerationError on failure', () async {
    final cubit = GeneratePuzzleCubit(
      service: _FakeService(error: const CrosswordGenerationException('x')),
    );
    final states = await _collect(cubit, cubit.generate);
    expect(states.first.isGenerating, isTrue);
    expect(states.last, isA<ShowGenerationError>());
    expect(states.last.isGenerating, isFalse);
    await cubit.close();
  });

  test('openTestPuzzle emits GenerationSucceeded', () async {
    final cubit = GeneratePuzzleCubit(service: _FakeService(puzzle: _puzzle()));
    final states = await _collect(cubit, cubit.openTestPuzzle);
    expect(states.last, isA<GenerationSucceeded>());
    await cubit.close();
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/gameplay/presentation/generate_screen/generate_cubit_test.dart` (from `packages/crossword_ui`)
Expected: FAIL — `GeneratePuzzleCubit` undefined.

- [ ] **Step 3: Create the state**

`packages/crossword_ui/lib/gameplay/presentation/generate_screen/cubit/generate_state.dart`:
```dart
import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart' show Key, UniqueKey;

import 'package:crossword_core/crossword_core.dart';

class GenerateState extends Equatable {
  static const List<int> sizePresets = [11, 15, 17];
  static const List<int> maxWordLenPresets = [5, 6, 8];

  final int width;
  final int height;
  final int maxWordLen;
  final bool isGenerating;

  const GenerateState({
    this.width = 15,
    this.height = 15,
    this.maxWordLen = 6,
    this.isGenerating = false,
  });

  @override
  List<Object?> get props => [width, height, maxWordLen, isGenerating];

  GenerateState copyWith({
    int? width,
    int? height,
    int? maxWordLen,
    bool? isGenerating,
  }) {
    return GenerateState(
      width: width ?? this.width,
      height: height ?? this.height,
      maxWordLen: maxWordLen ?? this.maxWordLen,
      isGenerating: isGenerating ?? this.isGenerating,
    );
  }

  GenerateState.copy(GenerateState state)
      : width = state.width,
        height = state.height,
        maxWordLen = state.maxWordLen,
        isGenerating = state.isGenerating;
}

class GenerationSucceeded extends GenerateState {
  final CrosswordPuzzle puzzle;
  final Key key = UniqueKey();

  GenerationSucceeded({required GenerateState state, required this.puzzle})
      : super.copy(state);

  @override
  List<Object?> get props => [...super.props, puzzle, key];
}

class ShowGenerationError extends GenerateState {
  final String message;
  final Key key = UniqueKey();

  ShowGenerationError({required GenerateState state, required this.message})
      : super.copy(state);

  @override
  List<Object?> get props => [...super.props, message, key];
}
```

- [ ] **Step 4: Create the cubit**

`packages/crossword_ui/lib/gameplay/presentation/generate_screen/cubit/generate_cubit.dart`:
```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:crossword_api/crossword_api.dart';

import '../../../../common/data/constants/strings.dart';
import 'generate_state.dart';

class GeneratePuzzleCubit extends Cubit<GenerateState> {
  final PuzzleGenerationService _service;
  final TextEditingController seedWordsController = TextEditingController();

  GeneratePuzzleCubit({required PuzzleGenerationService service})
      : _service = service,
        super(const GenerateState());

  void selectSize(int size) =>
      emit(state.copyWith(width: size, height: size));

  void selectMaxWordLen(int value) =>
      emit(state.copyWith(maxWordLen: value));

  Future<void> generate() async {
    emit(state.copyWith(isGenerating: true));
    try {
      final puzzle = await _service.generate(
        width: state.width,
        height: state.height,
        maxWordLen: state.maxWordLen,
        title: Strings.generatedPuzzleTitle,
        seedWords: _parseSeedWords(seedWordsController.text),
      );
      emit(GenerationSucceeded(
        state: state.copyWith(isGenerating: false),
        puzzle: puzzle,
      ));
    } catch (_) {
      emit(ShowGenerationError(
        state: state.copyWith(isGenerating: false),
        message: Strings.generationErrorMessage,
      ));
    }
  }

  Future<void> openTestPuzzle() async {
    try {
      final puzzle = await _service.loadTestPuzzle();
      emit(GenerationSucceeded(state: state, puzzle: puzzle));
    } catch (_) {
      emit(ShowGenerationError(
        state: state,
        message: Strings.generationErrorMessage,
      ));
    }
  }

  List<String> _parseSeedWords(String raw) => raw
      .split(RegExp(r'[,\s]+'))
      .map((w) => w.trim().toUpperCase())
      .where((w) => w.isNotEmpty)
      .toList();

  @override
  Future<void> close() {
    seedWordsController.dispose();
    return super.close();
  }
}
```

- [ ] **Step 5: Export both**

In `packages/crossword_ui/lib/crossword_ui.dart`, add:
```dart
export 'gameplay/presentation/generate_screen/cubit/generate_cubit.dart';
export 'gameplay/presentation/generate_screen/cubit/generate_state.dart';
```

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/gameplay/presentation/generate_screen/generate_cubit_test.dart` (from `packages/crossword_ui`)
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add packages/crossword_ui
git commit -m "feat(ui): add GeneratePuzzleCubit + state"
```

---

### Task 11: `GenerateScreen` (three-widget structure)

**Files:**
- Create: `packages/crossword_ui/lib/gameplay/presentation/generate_screen/generate_screen.dart`
- Modify: `packages/crossword_ui/lib/crossword_ui.dart` (export)
- Test: `packages/crossword_ui/test/gameplay/presentation/generate_screen/generate_screen_test.dart`

**Interfaces:**
- Consumes: `GeneratePuzzleCubit`, `GenerateState`, `GenerationSucceeded`, `ShowGenerationError`, `PuzzleGenerationService`, `Strings`, `AppColors`, `BrandAppBar`, `CrosswordPuzzle`.
- Produces: `GenerateScreen({required PuzzleGenerationService service, required Widget Function(BuildContext, CrosswordPuzzle) gameplayBuilder})` — the landing screen. On `GenerationSucceeded` it `Navigator.push`es `gameplayBuilder(context, puzzle)`; on `ShowGenerationError` it shows a SnackBar.

- [ ] **Step 1: Write the failing widget test**

`packages/crossword_ui/test/gameplay/presentation/generate_screen/generate_screen_test.dart`:
```dart
import 'package:crossword_api/crossword_api.dart';
import 'package:crossword_core/crossword_core.dart';
import 'package:crossword_ui/crossword_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeService implements PuzzleGenerationService {
  @override
  Future<CrosswordPuzzle> generate({
    required int width,
    required int height,
    required int maxWordLen,
    required String title,
    List<String> seedWords = const [],
  }) async =>
      CrosswordPuzzle(
        rows: 1, cols: 1, cells: const {}, words: const [],
        title: title, languageCode: 'sv',
      );

  @override
  Future<CrosswordPuzzle> loadTestPuzzle() async => generate(
        width: 1, height: 1, maxWordLen: 6, title: 'bundled',
      );
}

void main() {
  testWidgets('shows controls and navigates on generate', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: GenerateScreen(
        service: _FakeService(),
        gameplayBuilder: (_, puzzle) =>
            Scaffold(body: Text('PLAYING ${puzzle.title}')),
      ),
    ));

    expect(find.text(Strings.generateTitle), findsOneWidget);
    expect(find.text(Strings.generateAction), findsOneWidget);

    await tester.tap(find.text(Strings.generateAction));
    await tester.pumpAndSettle();

    expect(find.text('PLAYING ${Strings.generatedPuzzleTitle}'),
        findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/gameplay/presentation/generate_screen/generate_screen_test.dart` (from `packages/crossword_ui`)
Expected: FAIL — `GenerateScreen` undefined.

- [ ] **Step 3: Create the screen (three-widget structure)**

`packages/crossword_ui/lib/gameplay/presentation/generate_screen/generate_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:crossword_api/crossword_api.dart';
import 'package:crossword_core/crossword_core.dart';

import '../../../common/data/constants/app_colors.dart';
import '../../../common/data/constants/strings.dart';
import '../../../common/presentation/widgets/brand_app_bar.dart';
import 'cubit/generate_cubit.dart';
import 'cubit/generate_state.dart';

typedef GameplayBuilder = Widget Function(
  BuildContext context,
  CrosswordPuzzle puzzle,
);

class GenerateScreen extends StatelessWidget {
  final PuzzleGenerationService service;
  final GameplayBuilder gameplayBuilder;

  const GenerateScreen({
    required this.service,
    required this.gameplayBuilder,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => GeneratePuzzleCubit(service: service),
      child: _GenerateScreenBuilder(gameplayBuilder: gameplayBuilder),
    );
  }
}

class _GenerateScreenBuilder extends StatelessWidget {
  final GameplayBuilder gameplayBuilder;

  const _GenerateScreenBuilder({required this.gameplayBuilder});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GeneratePuzzleCubit, GenerateState>(
      listener: (context, state) {
        if (state is GenerationSucceeded) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => gameplayBuilder(context, state.puzzle),
            ),
          );
        } else if (state is ShowGenerationError) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(state.message)));
        }
      },
      builder: (context, state) => _GenerateScreenContent(state: state),
    );
  }
}

class _GenerateScreenContent extends StatelessWidget {
  final GenerateState state;

  const _GenerateScreenContent({required this.state});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<GeneratePuzzleCubit>();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const BrandAppBar(title: Strings.generateTitle),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(Strings.generateSizeLabel),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final size in GenerateState.sizePresets)
                    ChoiceChip(
                      label: Text('$size×$size'),
                      selected: state.width == size,
                      onSelected: state.isGenerating
                          ? null
                          : (_) => cubit.selectSize(size),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(Strings.generateMaxWordLenLabel),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final len in GenerateState.maxWordLenPresets)
                    ChoiceChip(
                      label: Text('$len'),
                      selected: state.maxWordLen == len,
                      onSelected: state.isGenerating
                          ? null
                          : (_) => cubit.selectMaxWordLen(len),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(Strings.generateSeedWordsLabel),
              const SizedBox(height: 8),
              TextField(
                controller: cubit.seedWordsController,
                enabled: !state.isGenerating,
                decoration: const InputDecoration(
                  hintText: Strings.generateSeedWordsHint,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: state.isGenerating ? null : cubit.generate,
                  child: state.isGenerating
                      ? const Text(Strings.generatingLabel)
                      : const Text(Strings.generateAction),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed:
                      state.isGenerating ? null : cubit.openTestPuzzle,
                  child: const Text(Strings.generateTestPuzzleAction),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Export it**

In `packages/crossword_ui/lib/crossword_ui.dart`, add:
```dart
export 'gameplay/presentation/generate_screen/generate_screen.dart';
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/gameplay/presentation/generate_screen/generate_screen_test.dart` (from `packages/crossword_ui`)
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add packages/crossword_ui
git commit -m "feat(ui): add GenerateScreen"
```

---

### Task 12: Wire `apps/mobile` to launch into the generate screen

**Files:**
- Modify: `apps/mobile/lib/main.dart`
- Modify: `apps/mobile/pubspec.yaml` (add `crossword_api` + `http` if not transitively available for construction)

**Interfaces:**
- Consumes: `PuzzleGenerationService`, `CrosswordGenerationRepository`, `CrosswordGenerationRemoteDataSource` (crossword_api); `GenerateScreen` (crossword_ui); `MobileCrosswordScreen`.

- [ ] **Step 1: Add the dependency**

In `apps/mobile/pubspec.yaml` under `dependencies:` add (if absent):
```yaml
  crossword_api:
    path: ../../packages/crossword_api
```
Run `flutter pub get` from `apps/mobile`.

- [ ] **Step 2: Build the service and use the generate screen as home**

In `apps/mobile/lib/main.dart`:
- Add imports:
```dart
import 'package:crossword_api/crossword_api.dart';
```
- In `main()`, replace `final puzzle = await loadBundledPuzzle();` and the `puzzle:` argument with a service:
```dart
  final generationService = PuzzleGenerationService(
    repository: CrosswordGenerationRepository(
      remoteDataSource: CrosswordGenerationRemoteDataSource(),
    ),
  );
  runApp(CrosswordsApp(
    fontService: fontService,
    settingsService: settingsService,
    progressService: progressService,
    authService: authService,
    generationService: generationService,
  ));
```
- In `CrosswordsApp`, replace the `final CrosswordPuzzle puzzle;` field (and its constructor param) with `final PuzzleGenerationService generationService;`.
- Replace the `home:` child:
```dart
        home: AuthGate(
          authService: authService,
          child: GenerateScreen(
            service: generationService,
            gameplayBuilder: (context, puzzle) =>
                MobileCrosswordScreen(puzzle: puzzle),
          ),
        ),
```
- Remove the now-unused `crossword_core` `loadBundledPuzzle` usage. Keep the `crossword_core` import (still used for `CrosswordPuzzle` type in `MobileCrosswordScreen`); remove it from `main.dart` only if no longer referenced there.

- [ ] **Step 3: Analyze**

Run: `flutter analyze` (from `apps/mobile`)
Expected: No issues (no unused imports, no undefined names).

- [ ] **Step 4: Smoke-run the build**

Run: `flutter build apk --debug` (from `apps/mobile`) OR `flutter run` and confirm the generate screen appears with size/word-length chips and a Skapa button.
Expected: App launches to the generate screen; tapping Skapa generates and opens the grid; Testkorsord opens the bundled puzzle.

- [ ] **Step 5: Commit**

```bash
git add apps/mobile
git commit -m "feat(mobile): launch into the generate screen"
```

---

### Task 13: Wire `apps/web` to launch into the generate screen

**Files:**
- Modify: `apps/web/lib/main.dart`
- Modify: `apps/web/pubspec.yaml` (add `crossword_api`)

**Interfaces:**
- Consumes: same as Task 12, but pushes `WebCrosswordScreen`.

- [ ] **Step 1: Add the dependency**

In `apps/web/pubspec.yaml` under `dependencies:` add (if absent):
```yaml
  crossword_api:
    path: ../../packages/crossword_api
```
Run `flutter pub get` from `apps/web`.

- [ ] **Step 2: Build the service and use the generate screen as home**

In `apps/web/lib/main.dart`, apply the same changes as Task 12 Step 2, but:
- The class is `CrosswordsWebApp`.
- The gameplay builder pushes `WebCrosswordScreen`:
```dart
          child: GenerateScreen(
            service: generationService,
            gameplayBuilder: (context, puzzle) =>
                WebCrosswordScreen(puzzle: puzzle),
          ),
```
Add `import 'package:crossword_api/crossword_api.dart';`, replace the `puzzle` field with `generationService`, and drop the `loadBundledPuzzle()` call.

- [ ] **Step 3: Analyze**

Run: `flutter analyze` (from `apps/web`)
Expected: No issues.

- [ ] **Step 4: Smoke-run the build**

Run: `flutter build web` (from `apps/web`)
Expected: Builds cleanly.

- [ ] **Step 5: Commit**

```bash
git add apps/web
git commit -m "feat(web): launch into the generate screen"
```

---

### Task 14: Full-workspace verification

**Files:** none (verification only).

- [ ] **Step 1: Analyze the whole workspace**

Run: `flutter analyze` (from repo root)
Expected: No issues found.

- [ ] **Step 2: Run all tests**

Run: `flutter test` in each package that has tests:
```bash
(cd packages/crossword_core && flutter test)
(cd packages/crossword_api && flutter test)
(cd packages/crossword_ui && flutter test)
```
Expected: all green.

- [ ] **Step 3: Commit any formatting fixes**

If `dart format .` changed files:
```bash
dart format .
git add -A
git commit -m "style: dart format"
```

---

## Notes for the implementer

- The generator returns no clue prose (`generated_clues` is null), so `Word.clueText` stays null and clue cells render arrows only — this matches the current bundled puzzle exactly; do not invent clue text.
- Slots are straight runs, so generated words never bend. Do not add redirect handling.
- `ChoiceChip`/`TextField`/`FilledButton`/`TextButton` are framework widgets — acceptable here (the InkWell-in-Material rule targets custom tappable surfaces, not Material form controls).
- Keep `loadBundledPuzzle()` and its asset; it now backs the "Testkorsord" action only.
