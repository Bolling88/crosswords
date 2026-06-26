# All Generation Fields Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expose all 9 fields of the `POST /crossword-puzzles/generate` request as user-editable controls in the shared Generate screen, so both the web and mobile apps support them.

**Architecture:** Bottom-up through the existing layers — extend the request DTO, forward the new params through repository and service, hold the new state in `GenerateState` + cubit (with a `TextEditingController` for the optional random seed), then render new chip/stepper/text controls in the shared `generate_screen.dart`. Both apps inherit the change via the `crossword_ui` / `crossword_api` packages.

**Tech Stack:** Flutter 3.41.9, flutter_bloc (Cubit), Equatable, flutter_test + bloc_test.

## Global Constraints

- ALL widgets MUST be `StatelessWidget` — no `StatefulWidget`/`setState`/`initState`/`dispose` in widgets. Local state and controllers live in the Cubit.
- Controllers (`TextEditingController`) live in the Cubit and are disposed in `close()`.
- Event states (side effects) use a `final Key key = UniqueKey();` and override `props`; never `copyWith` for side effects. (Already true for `GenerationSucceeded` / `ShowGenerationError` — do not regress.)
- Never hardcode user-facing strings — add to `Strings` (`packages/crossword_ui/lib/common/data/constants/strings.dart`). Primary language Swedish (`'sv'`).
- Never use the null-assertion operator `!`. Use `?.`, `??`, `int.tryParse`.
- Never use sentinel values in `copyWith`; nullable handled via dedicated method if needed.
- Use `AppColors` constants, `withAlpha()` not `withOpacity()`.
- Tappable UI uses `InkWell`/`IconButton` (which use ink internally), never `GestureDetector` (grid cells excepted — not relevant here).
- Trailing commas required; prefer `const`; prefer `final`; single quotes; private members prefixed `_`.
- Import order: Dart/Flutter → packages → local, blank line between groups.
- Run `flutter analyze` clean before each commit.

---

### Task 1: Extend the request DTO

**Files:**
- Modify: `packages/crossword_api/lib/src/dto/crossword_generation_request.dart`
- Test: `packages/crossword_api/test/dto/crossword_generation_request_test.dart` (create if absent; otherwise add to it)

**Interfaces:**
- Consumes: nothing.
- Produces: `CrosswordGenerationRequest({required int width, required int height, required int maxWordLen, List<String> seedWords = const [], String languageCode = 'sv', int? randomSeed, int maxSeconds = 30, int pictureCols = 0, int pictureRows = 0})` with `Map<String, dynamic> toJson()`. `toJson` always includes `width, height, language_code, seed_words, max_seconds, max_word_len, picture_cols, picture_rows`; includes `random_seed` only when `randomSeed != null`.

- [ ] **Step 1: Check whether a DTO test file already exists**

Run: `ls packages/crossword_api/test/dto/`
If `crossword_generation_request_test.dart` exists, add the tests below to it; otherwise create it with the import header:

```dart
import 'package:crossword_api/crossword_api.dart';
import 'package:flutter_test/flutter_test.dart';
```

If `CrosswordGenerationRequest` is not exported from `crossword_api.dart`, import it directly instead:

```dart
import 'package:crossword_api/src/dto/crossword_generation_request.dart';
```

(Verify with `grep -n crossword_generation_request packages/crossword_api/lib/crossword_api.dart`.)

- [ ] **Step 2: Write the failing tests**

```dart
void main() {
  group('CrosswordGenerationRequest.toJson', () {
    test('includes all fields with defaults and omits null random_seed', () {
      const request = CrosswordGenerationRequest(
        width: 15,
        height: 15,
        maxWordLen: 6,
      );

      final json = request.toJson();

      expect(json['width'], 15);
      expect(json['height'], 15);
      expect(json['language_code'], 'sv');
      expect(json['seed_words'], <String>[]);
      expect(json['max_seconds'], 30);
      expect(json['max_word_len'], 6);
      expect(json['picture_cols'], 0);
      expect(json['picture_rows'], 0);
      expect(json.containsKey('random_seed'), isFalse);
    });

    test('includes random_seed and overridden fields when set', () {
      const request = CrosswordGenerationRequest(
        width: 17,
        height: 13,
        maxWordLen: 8,
        seedWords: ['KATT', 'HUND'],
        languageCode: 'sv',
        randomSeed: 42,
        maxSeconds: 60,
        pictureCols: 8,
        pictureRows: 6,
      );

      final json = request.toJson();

      expect(json['random_seed'], 42);
      expect(json['max_seconds'], 60);
      expect(json['picture_cols'], 8);
      expect(json['picture_rows'], 6);
      expect(json['seed_words'], ['KATT', 'HUND']);
    });
  });
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `flutter test packages/crossword_api/test/dto/crossword_generation_request_test.dart`
Expected: FAIL — named params `languageCode`/`randomSeed`/`maxSeconds`/`pictureCols`/`pictureRows` are undefined.

- [ ] **Step 4: Implement the DTO**

Replace the full contents of `crossword_generation_request.dart` with:

```dart
/// Request body for `POST /crossword-puzzles/generate`. Carries every field of
/// the generation schema. `random_seed` is omitted when null so the backend
/// picks its own seed; image clues use [pictureCols]/[pictureRows] (0 = off).
class CrosswordGenerationRequest {
  final int width;
  final int height;
  final int maxWordLen;
  final List<String> seedWords;
  final String languageCode;
  final int? randomSeed;
  final int maxSeconds;
  final int pictureCols;
  final int pictureRows;

  const CrosswordGenerationRequest({
    required this.width,
    required this.height,
    required this.maxWordLen,
    this.seedWords = const [],
    this.languageCode = 'sv',
    this.randomSeed,
    this.maxSeconds = 30,
    this.pictureCols = 0,
    this.pictureRows = 0,
  });

  Map<String, dynamic> toJson() => {
        'width': width,
        'height': height,
        'language_code': languageCode,
        'seed_words': seedWords,
        if (randomSeed != null) 'random_seed': randomSeed,
        'max_seconds': maxSeconds,
        'max_word_len': maxWordLen,
        'picture_cols': pictureCols,
        'picture_rows': pictureRows,
      };
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test packages/crossword_api/test/dto/crossword_generation_request_test.dart`
Expected: PASS

- [ ] **Step 6: Analyze and commit**

```bash
flutter analyze packages/crossword_api
git add packages/crossword_api/lib/src/dto/crossword_generation_request.dart packages/crossword_api/test/dto/crossword_generation_request_test.dart
git commit -m "feat(api): carry all generation fields in request DTO"
```

---

### Task 2: Forward new params through repository and service

**Files:**
- Modify: `packages/crossword_api/lib/src/crossword_generation_repository.dart`
- Modify: `packages/crossword_api/lib/src/puzzle_generation_service.dart`
- Test: `packages/crossword_api/test/crossword_generation_repository_test.dart` (create if absent)

**Interfaces:**
- Consumes: `CrosswordGenerationRequest` (Task 1); `CrosswordGenerationRemoteDataSource.generate(CrosswordGenerationRequest)`.
- Produces:
  - `CrosswordGenerationRepository.generate({required int width, required int height, required int maxWordLen, required String title, List<String> seedWords = const [], String languageCode = 'sv', int? randomSeed, int maxSeconds = 30, int pictureCols = 0, int pictureRows = 0})`.
  - `PuzzleGenerationService.generate({...same named params...})` with identical signature, forwarding to the repository.

- [ ] **Step 1: Inspect the remote data source and mapper signatures**

Run: `sed -n '1,60p' packages/crossword_api/lib/src/crossword_generation_remote_data_source.dart`
Confirm `generate(CrosswordGenerationRequest request)` returns `Future<CrosswordGenerationResponse>` and note the constructor params (needed to build the test fake). Also confirm `GeneratedPuzzleMapper.map(response, title: ...)`.

- [ ] **Step 2: Write the failing repository test**

Create `packages/crossword_api/test/crossword_generation_repository_test.dart`. Use a fake remote data source that captures the request. Adjust the `extends`/constructor to match what Step 1 revealed (it may require a base class or named constructor params).

```dart
import 'package:crossword_api/crossword_api.dart';
import 'package:crossword_api/src/crossword_generation_remote_data_source.dart';
import 'package:crossword_api/src/crossword_generation_repository.dart';
import 'package:crossword_api/src/dto/crossword_generation_request.dart';
import 'package:crossword_api/src/dto/crossword_generation_response.dart';
import 'package:flutter_test/flutter_test.dart';

class _CapturingRemoteDataSource implements CrosswordGenerationRemoteDataSource {
  CrosswordGenerationRequest? captured;

  @override
  Future<CrosswordGenerationResponse> generate(
    CrosswordGenerationRequest request,
  ) async {
    captured = request;
    // Minimal failure response is enough; the mapper is exercised elsewhere.
    return const CrosswordGenerationResponse(
      success: false,
      failureReason: 'test',
      gridCells: [],
      slots: [],
      assignments: [],
      seedCells: [],
    );
  }
}

void main() {
  test('repository forwards every field into the request DTO', () async {
    final remote = _CapturingRemoteDataSource();
    final repository =
        CrosswordGenerationRepository(remoteDataSource: remote);

    try {
      await repository.generate(
        width: 17,
        height: 13,
        maxWordLen: 8,
        title: 'T',
        seedWords: ['KATT'],
        languageCode: 'sv',
        randomSeed: 42,
        maxSeconds: 60,
        pictureCols: 8,
        pictureRows: 6,
      );
    } catch (_) {
      // Mapper may throw on the minimal failure response; we only assert the
      // captured request below.
    }

    final captured = remote.captured;
    expect(captured, isNotNull);
    expect(captured?.width, 17);
    expect(captured?.height, 13);
    expect(captured?.maxWordLen, 8);
    expect(captured?.seedWords, ['KATT']);
    expect(captured?.languageCode, 'sv');
    expect(captured?.randomSeed, 42);
    expect(captured?.maxSeconds, 60);
    expect(captured?.pictureCols, 8);
    expect(captured?.pictureRows, 6);
  });
}
```

> Note: if `implements CrosswordGenerationRemoteDataSource` fails because it is a concrete class with no implicit interface issues, keep `implements`; if it has non-trivial members, switch to `extends` with a `super` call. If `CrosswordGenerationResponse`'s const constructor differs from the shape above, match the actual constructor (check `crossword_generation_response.dart`).

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test packages/crossword_api/test/crossword_generation_repository_test.dart`
Expected: FAIL — repository `generate` does not accept `languageCode`/`randomSeed`/etc.

- [ ] **Step 4: Update the repository**

Replace the `generate` method in `crossword_generation_repository.dart` with:

```dart
  Future<CrosswordPuzzle> generate({
    required int width,
    required int height,
    required int maxWordLen,
    required String title,
    List<String> seedWords = const [],
    String languageCode = 'sv',
    int? randomSeed,
    int maxSeconds = 30,
    int pictureCols = 0,
    int pictureRows = 0,
  }) async {
    final response = await _remoteDataSource.generate(
      CrosswordGenerationRequest(
        width: width,
        height: height,
        maxWordLen: maxWordLen,
        seedWords: seedWords,
        languageCode: languageCode,
        randomSeed: randomSeed,
        maxSeconds: maxSeconds,
        pictureCols: pictureCols,
        pictureRows: pictureRows,
      ),
    );
    return GeneratedPuzzleMapper.map(response, title: title);
  }
```

- [ ] **Step 5: Update the service**

Replace the `generate` method in `puzzle_generation_service.dart` with:

```dart
  Future<CrosswordPuzzle> generate({
    required int width,
    required int height,
    required int maxWordLen,
    required String title,
    List<String> seedWords = const [],
    String languageCode = 'sv',
    int? randomSeed,
    int maxSeconds = 30,
    int pictureCols = 0,
    int pictureRows = 0,
  }) =>
      _repository.generate(
        width: width,
        height: height,
        maxWordLen: maxWordLen,
        title: title,
        seedWords: seedWords,
        languageCode: languageCode,
        randomSeed: randomSeed,
        maxSeconds: maxSeconds,
        pictureCols: pictureCols,
        pictureRows: pictureRows,
      );
```

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test packages/crossword_api/test/crossword_generation_repository_test.dart`
Expected: PASS

- [ ] **Step 7: Analyze and commit**

```bash
flutter analyze packages/crossword_api
git add packages/crossword_api/lib/src/crossword_generation_repository.dart packages/crossword_api/lib/src/puzzle_generation_service.dart packages/crossword_api/test/crossword_generation_repository_test.dart
git commit -m "feat(api): forward all generation params through repository and service"
```

---

### Task 3: Add Swedish strings for the new controls

**Files:**
- Modify: `packages/crossword_ui/lib/common/data/constants/strings.dart`

**Interfaces:**
- Produces (all `static const String` on `Strings`): `generateLanguageLabel`, `generateMaxSecondsLabel`, `generatePictureColsLabel`, `generatePictureRowsLabel`, `generateRandomSeedLabel`, `generateRandomSeedHint`.

- [ ] **Step 1: Add the strings**

In `strings.dart`, inside the `Strings` class under the `/// Generate screen.` group (after `generateSeedWordsHint`, before `generateAction`), add:

```dart
  static const String generateLanguageLabel = 'Språk';
  static const String generateLanguageSwedish = 'Svenska';
  static const String generateMaxSecondsLabel = 'Max tid (s)';
  static const String generatePictureColsLabel = 'Bildrutor (bredd)';
  static const String generatePictureRowsLabel = 'Bildrutor (höjd)';
  static const String generateRandomSeedLabel = 'Slumpfrö';
  static const String generateRandomSeedHint = 'Lämna tomt för slumpmässigt';
```

- [ ] **Step 2: Analyze and commit**

```bash
flutter analyze packages/crossword_ui/lib/common/data/constants/strings.dart
git add packages/crossword_ui/lib/common/data/constants/strings.dart
git commit -m "feat(ui): add strings for new generation fields"
```

---

### Task 4: Extend GenerateState with the new fields

**Files:**
- Modify: `packages/crossword_ui/lib/gameplay/presentation/generate_screen/cubit/generate_state.dart`
- Test: `packages/crossword_ui/test/gameplay/presentation/generate_screen/cubit/generate_state_test.dart` (create if absent)

**Interfaces:**
- Consumes: nothing new.
- Produces — `GenerateState` gains fields `String languageCode` (default `'sv'`), `int maxSeconds` (default 30), `int pictureCols` (default 0), `int pictureRows` (default 0); constants `static const int minMaxSeconds = 5`, `maxMaxSeconds = 120`, `maxSecondsStep = 5`, `minPictureDim = 0`; all wired into `copyWith`, `props`, and the `.copy` constructor. Existing fields (`width`, `height`, `maxWordLen`, `isGenerating`) and event states unchanged.

- [ ] **Step 1: Write the failing test**

Create `packages/crossword_ui/test/gameplay/presentation/generate_screen/cubit/generate_state_test.dart`:

```dart
import 'package:crossword_ui/gameplay/presentation/generate_screen/cubit/generate_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GenerateState', () {
    test('has expected defaults for new fields', () {
      const state = GenerateState();
      expect(state.languageCode, 'sv');
      expect(state.maxSeconds, 30);
      expect(state.pictureCols, 0);
      expect(state.pictureRows, 0);
    });

    test('copyWith updates new fields and preserves the rest', () {
      const state = GenerateState();
      final updated = state.copyWith(
        maxSeconds: 60,
        pictureCols: 8,
        pictureRows: 6,
      );
      expect(updated.maxSeconds, 60);
      expect(updated.pictureCols, 8);
      expect(updated.pictureRows, 6);
      expect(updated.width, state.width);
      expect(updated.languageCode, 'sv');
    });

    test('new fields participate in equality', () {
      const a = GenerateState();
      final b = a.copyWith(maxSeconds: 60);
      expect(a == b, isFalse);
      expect(a == a.copyWith(), isTrue);
    });
  });
}
```

> Verify the import path matches the package name. Check `grep '^name:' packages/crossword_ui/pubspec.yaml` — if the package is not `crossword_ui`, adjust the import prefix accordingly.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test packages/crossword_ui/test/gameplay/presentation/generate_screen/cubit/generate_state_test.dart`
Expected: FAIL — `languageCode`/`maxSeconds`/`pictureCols`/`pictureRows` undefined.

- [ ] **Step 3: Implement the state**

Replace the base `GenerateState` class (the non-event part, lines defining fields through the `.copy` constructor) with the version below. Leave `GenerationSucceeded` and `ShowGenerationError` untouched.

```dart
class GenerateState extends Equatable {
  static const List<int> sizePresets = [11, 15, 17];
  static const List<int> maxWordLenPresets = [5, 6, 8];

  static const int minMaxSeconds = 5;
  static const int maxMaxSeconds = 120;
  static const int maxSecondsStep = 5;
  static const int minPictureDim = 0;

  final int width;
  final int height;
  final int maxWordLen;
  final String languageCode;
  final int maxSeconds;
  final int pictureCols;
  final int pictureRows;
  final bool isGenerating;

  const GenerateState({
    this.width = 15,
    this.height = 15,
    this.maxWordLen = 6,
    this.languageCode = 'sv',
    this.maxSeconds = 30,
    this.pictureCols = 0,
    this.pictureRows = 0,
    this.isGenerating = false,
  });

  @override
  List<Object?> get props => [
        width,
        height,
        maxWordLen,
        languageCode,
        maxSeconds,
        pictureCols,
        pictureRows,
        isGenerating,
      ];

  GenerateState copyWith({
    int? width,
    int? height,
    int? maxWordLen,
    String? languageCode,
    int? maxSeconds,
    int? pictureCols,
    int? pictureRows,
    bool? isGenerating,
  }) {
    return GenerateState(
      width: width ?? this.width,
      height: height ?? this.height,
      maxWordLen: maxWordLen ?? this.maxWordLen,
      languageCode: languageCode ?? this.languageCode,
      maxSeconds: maxSeconds ?? this.maxSeconds,
      pictureCols: pictureCols ?? this.pictureCols,
      pictureRows: pictureRows ?? this.pictureRows,
      isGenerating: isGenerating ?? this.isGenerating,
    );
  }

  GenerateState.copy(GenerateState state)
      : width = state.width,
        height = state.height,
        maxWordLen = state.maxWordLen,
        languageCode = state.languageCode,
        maxSeconds = state.maxSeconds,
        pictureCols = state.pictureCols,
        pictureRows = state.pictureRows,
        isGenerating = state.isGenerating;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test packages/crossword_ui/test/gameplay/presentation/generate_screen/cubit/generate_state_test.dart`
Expected: PASS

- [ ] **Step 5: Analyze and commit**

```bash
flutter analyze packages/crossword_ui/lib/gameplay/presentation/generate_screen/cubit/generate_state.dart
git add packages/crossword_ui/lib/gameplay/presentation/generate_screen/cubit/generate_state.dart packages/crossword_ui/test/gameplay/presentation/generate_screen/cubit/generate_state_test.dart
git commit -m "feat(ui): add new generation fields to GenerateState"
```

---

### Task 5: Add cubit mutators and forward all params

**Files:**
- Modify: `packages/crossword_ui/lib/gameplay/presentation/generate_screen/cubit/generate_cubit.dart`
- Test: `packages/crossword_ui/test/gameplay/presentation/generate_screen/cubit/generate_cubit_test.dart` (create if absent; add to it if present)

**Interfaces:**
- Consumes: `GenerateState` (Task 4); `PuzzleGenerationService.generate({...})` (Task 2).
- Produces on `GeneratePuzzleCubit`:
  - `TextEditingController randomSeedController` (disposed in `close()`).
  - `void selectLanguage(String code)` → `emit(state.copyWith(languageCode: code))`.
  - `void incrementMaxSeconds()` / `void decrementMaxSeconds()` — clamp to `[minMaxSeconds, maxMaxSeconds]` in steps of `maxSecondsStep`.
  - `void incrementPictureCols()` / `void decrementPictureCols()` — clamp to `[0, state.width]`.
  - `void incrementPictureRows()` / `void decrementPictureRows()` — clamp to `[0, state.height]`.
  - `selectSize(int size)` additionally clamps `pictureCols`/`pictureRows` down to the new size.
  - `generate()` forwards `languageCode`, parsed `randomSeed` (`int.tryParse` of trimmed text → null if blank/invalid), `maxSeconds`, `pictureCols`, `pictureRows` into the service.

- [ ] **Step 1: Inspect any existing cubit test / mock setup**

Run: `ls packages/crossword_ui/test/gameplay/presentation/generate_screen/cubit/ 2>/dev/null; grep -rln "PuzzleGenerationService" packages/crossword_ui/test 2>/dev/null`
If a mock/fake `PuzzleGenerationService` already exists in the test suite, reuse it. Otherwise create the fake shown below. Check whether the project uses `mocktail` or `mockito`: `grep -E "mocktail|mockito" packages/crossword_ui/pubspec.yaml`. The plan below uses a hand-written fake (no mocking package required).

- [ ] **Step 2: Write the failing tests**

Create `packages/crossword_ui/test/gameplay/presentation/generate_screen/cubit/generate_cubit_test.dart`. Build a fake service that records the args of `generate` and returns a puzzle. Construct a minimal `CrosswordPuzzle` — check its required constructor params first with `grep -n "CrosswordPuzzle(" packages/crossword_core/lib` and match them; if construction is heavy, instead have the fake throw a sentinel and assert on the captured args before the throw (same pattern as Task 2).

```dart
import 'package:crossword_api/crossword_api.dart';
import 'package:crossword_ui/gameplay/presentation/generate_screen/cubit/generate_cubit.dart';
import 'package:crossword_ui/gameplay/presentation/generate_screen/cubit/generate_state.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeService implements PuzzleGenerationService {
  Map<String, dynamic>? captured;

  @override
  Future<CrosswordPuzzle> generate({
    required int width,
    required int height,
    required int maxWordLen,
    required String title,
    List<String> seedWords = const [],
    String languageCode = 'sv',
    int? randomSeed,
    int maxSeconds = 30,
    int pictureCols = 0,
    int pictureRows = 0,
  }) async {
    captured = {
      'width': width,
      'height': height,
      'maxWordLen': maxWordLen,
      'seedWords': seedWords,
      'languageCode': languageCode,
      'randomSeed': randomSeed,
      'maxSeconds': maxSeconds,
      'pictureCols': pictureCols,
      'pictureRows': pictureRows,
    };
    throw _StopAfterCapture();
  }

  @override
  Future<CrosswordPuzzle> loadTestPuzzle() => throw UnimplementedError();
}

class _StopAfterCapture implements Exception {}

void main() {
  group('GeneratePuzzleCubit', () {
    test('max seconds stepper clamps within bounds', () {
      final cubit = GeneratePuzzleCubit(service: _FakeService());
      // default 30 -> repeatedly decrement past the floor.
      for (var i = 0; i < 20; i++) {
        cubit.decrementMaxSeconds();
      }
      expect(cubit.state.maxSeconds, GenerateState.minMaxSeconds);
      for (var i = 0; i < 60; i++) {
        cubit.incrementMaxSeconds();
      }
      expect(cubit.state.maxSeconds, GenerateState.maxMaxSeconds);
      cubit.close();
    });

    test('picture cols clamp to grid width and never below zero', () {
      final cubit = GeneratePuzzleCubit(service: _FakeService());
      cubit.selectSize(11);
      for (var i = 0; i < 20; i++) {
        cubit.incrementPictureCols();
      }
      expect(cubit.state.pictureCols, 11);
      // shrinking the grid clamps pictures down.
      cubit.selectSize(11); // already 11; now ensure decrement floor
      for (var i = 0; i < 20; i++) {
        cubit.decrementPictureCols();
      }
      expect(cubit.state.pictureCols, 0);
      cubit.close();
    });

    test('selectSize clamps existing picture dims down to new size', () {
      final cubit = GeneratePuzzleCubit(service: _FakeService());
      cubit.selectSize(17);
      for (var i = 0; i < 17; i++) {
        cubit.incrementPictureCols();
        cubit.incrementPictureRows();
      }
      expect(cubit.state.pictureCols, 17);
      cubit.selectSize(11);
      expect(cubit.state.pictureCols, 11);
      expect(cubit.state.pictureRows, 11);
      cubit.close();
    });

    test('generate forwards all fields including parsed random seed', () async {
      final service = _FakeService();
      final cubit = GeneratePuzzleCubit(service: service);
      cubit.selectSize(17);
      cubit.selectMaxWordLen(8);
      cubit.incrementMaxSeconds(); // 30 -> 35
      cubit.seedWordsController.text = 'katt, hund';
      cubit.randomSeedController.text = '42';

      await cubit.generate();

      expect(service.captured?['width'], 17);
      expect(service.captured?['maxWordLen'], 8);
      expect(service.captured?['maxSeconds'], 35);
      expect(service.captured?['languageCode'], 'sv');
      expect(service.captured?['randomSeed'], 42);
      expect(service.captured?['seedWords'], ['KATT', 'HUND']);
      cubit.close();
    });

    test('blank random seed is forwarded as null', () async {
      final service = _FakeService();
      final cubit = GeneratePuzzleCubit(service: service);
      cubit.randomSeedController.text = '   ';

      await cubit.generate();

      expect(service.captured?['randomSeed'], isNull);
      cubit.close();
    });
  });
}
```

> If constructing the real `PuzzleGenerationService` interface via `implements` fails (e.g. `loadBundledPuzzle` is a top-level not on the class), the fake only needs the two instance methods `generate` and `loadTestPuzzle` — match the actual class members shown in `puzzle_generation_service.dart`.

- [ ] **Step 3: Run tests to verify they fail**

Run: `flutter test packages/crossword_ui/test/gameplay/presentation/generate_screen/cubit/generate_cubit_test.dart`
Expected: FAIL — `randomSeedController`, `incrementMaxSeconds`, `incrementPictureCols`, etc. undefined.

- [ ] **Step 4: Implement the cubit**

Replace the contents of `generate_cubit.dart` with:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:crossword_api/crossword_api.dart';

import '../../../../common/data/constants/strings.dart';
import 'generate_state.dart';

class GeneratePuzzleCubit extends Cubit<GenerateState> {
  final PuzzleGenerationService _service;
  final TextEditingController seedWordsController = TextEditingController();
  final TextEditingController randomSeedController = TextEditingController();

  GeneratePuzzleCubit({required PuzzleGenerationService service})
      : _service = service,
        super(const GenerateState());

  void selectSize(int size) => emit(
        state.copyWith(
          width: size,
          height: size,
          pictureCols:
              state.pictureCols > size ? size : state.pictureCols,
          pictureRows:
              state.pictureRows > size ? size : state.pictureRows,
        ),
      );

  void selectMaxWordLen(int value) =>
      emit(state.copyWith(maxWordLen: value));

  void selectLanguage(String code) =>
      emit(state.copyWith(languageCode: code));

  void incrementMaxSeconds() => emit(
        state.copyWith(
          maxSeconds: _clamp(
            state.maxSeconds + GenerateState.maxSecondsStep,
            GenerateState.minMaxSeconds,
            GenerateState.maxMaxSeconds,
          ),
        ),
      );

  void decrementMaxSeconds() => emit(
        state.copyWith(
          maxSeconds: _clamp(
            state.maxSeconds - GenerateState.maxSecondsStep,
            GenerateState.minMaxSeconds,
            GenerateState.maxMaxSeconds,
          ),
        ),
      );

  void incrementPictureCols() => emit(
        state.copyWith(
          pictureCols: _clamp(
            state.pictureCols + 1,
            GenerateState.minPictureDim,
            state.width,
          ),
        ),
      );

  void decrementPictureCols() => emit(
        state.copyWith(
          pictureCols: _clamp(
            state.pictureCols - 1,
            GenerateState.minPictureDim,
            state.width,
          ),
        ),
      );

  void incrementPictureRows() => emit(
        state.copyWith(
          pictureRows: _clamp(
            state.pictureRows + 1,
            GenerateState.minPictureDim,
            state.height,
          ),
        ),
      );

  void decrementPictureRows() => emit(
        state.copyWith(
          pictureRows: _clamp(
            state.pictureRows - 1,
            GenerateState.minPictureDim,
            state.height,
          ),
        ),
      );

  Future<void> generate() async {
    emit(state.copyWith(isGenerating: true));
    try {
      final puzzle = await _service.generate(
        width: state.width,
        height: state.height,
        maxWordLen: state.maxWordLen,
        title: Strings.generatedPuzzleTitle,
        seedWords: _parseSeedWords(seedWordsController.text),
        languageCode: state.languageCode,
        randomSeed: _parseRandomSeed(randomSeedController.text),
        maxSeconds: state.maxSeconds,
        pictureCols: state.pictureCols,
        pictureRows: state.pictureRows,
      );
      emit(GenerationSucceeded(
        state: state.copyWith(isGenerating: false),
        puzzle: puzzle,
      ));
    } catch (e, stack) {
      debugPrint('Puzzle generation failed: $e');
      debugPrint('$stack');
      emit(ShowGenerationError(
        state: state.copyWith(isGenerating: false),
        message: Strings.generationErrorMessage,
      ));
    }
  }

  Future<void> openTestPuzzle() async {
    emit(state.copyWith(isGenerating: true));
    try {
      final puzzle = await _service.loadTestPuzzle();
      emit(GenerationSucceeded(
        state: state.copyWith(isGenerating: false),
        puzzle: puzzle,
      ));
    } catch (e, stack) {
      debugPrint('Test puzzle load failed: $e');
      debugPrint('$stack');
      emit(ShowGenerationError(
        state: state.copyWith(isGenerating: false),
        message: Strings.generationErrorMessage,
      ));
    }
  }

  int _clamp(int value, int min, int max) =>
      value < min ? min : (value > max ? max : value);

  List<String> _parseSeedWords(String raw) => raw
      .split(RegExp(r'[,\s]+'))
      .map((w) => w.trim().toUpperCase())
      .where((w) => w.isNotEmpty)
      .toList();

  int? _parseRandomSeed(String raw) => int.tryParse(raw.trim());

  @override
  Future<void> close() {
    seedWordsController.dispose();
    randomSeedController.dispose();
    return super.close();
  }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test packages/crossword_ui/test/gameplay/presentation/generate_screen/cubit/generate_cubit_test.dart`
Expected: PASS

- [ ] **Step 6: Analyze and commit**

```bash
flutter analyze packages/crossword_ui/lib/gameplay/presentation/generate_screen/cubit/generate_cubit.dart
git add packages/crossword_ui/lib/gameplay/presentation/generate_screen/cubit/generate_cubit.dart packages/crossword_ui/test/gameplay/presentation/generate_screen/cubit/generate_cubit_test.dart
git commit -m "feat(ui): cubit mutators and forwarding for all generation fields"
```

---

### Task 6: Render the new controls in the Generate screen

**Files:**
- Modify: `packages/crossword_ui/lib/gameplay/presentation/generate_screen/generate_screen.dart`
- Test: `packages/crossword_ui/test/gameplay/presentation/generate_screen/generate_screen_test.dart` (create)

**Interfaces:**
- Consumes: `GeneratePuzzleCubit` mutators + `randomSeedController` (Task 5); `GenerateState` fields (Task 4); `Strings.*` (Task 3).
- Produces: a private `_LabeledStepper` `StatelessWidget`; new sections in `_GenerateScreenContent` for language, max seconds, pictures, and random seed. No public API change to `GenerateScreen`.

- [ ] **Step 1: Write the failing widget test**

Create `packages/crossword_ui/test/gameplay/presentation/generate_screen/generate_screen_test.dart`. This test mounts the content widget with a real cubit + fake service and checks the new labels render and a stepper button updates state. Reuse the `_FakeService` pattern from Task 5 (copy it into this file or extract a shared test helper under `test/helpers/`).

```dart
import 'package:crossword_api/crossword_api.dart';
import 'package:crossword_ui/common/data/constants/strings.dart';
import 'package:crossword_ui/gameplay/presentation/generate_screen/cubit/generate_cubit.dart';
import 'package:crossword_ui/gameplay/presentation/generate_screen/cubit/generate_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeService implements PuzzleGenerationService {
  @override
  Future<CrosswordPuzzle> generate({
    required int width,
    required int height,
    required int maxWordLen,
    required String title,
    List<String> seedWords = const [],
    String languageCode = 'sv',
    int? randomSeed,
    int maxSeconds = 30,
    int pictureCols = 0,
    int pictureRows = 0,
  }) =>
      throw UnimplementedError();

  @override
  Future<CrosswordPuzzle> loadTestPuzzle() => throw UnimplementedError();
}

void main() {
  testWidgets('renders new field labels', (tester) async {
    final cubit = GeneratePuzzleCubit(service: _FakeService());
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: cubit,
          // Pump the screen via its public widget; see note below.
          child: const _Harness(),
        ),
      ),
    );

    expect(find.text(Strings.generateLanguageLabel), findsOneWidget);
    expect(find.text(Strings.generateMaxSecondsLabel), findsOneWidget);
    expect(find.text(Strings.generatePictureColsLabel), findsOneWidget);
    expect(find.text(Strings.generatePictureRowsLabel), findsOneWidget);
    expect(find.text(Strings.generateRandomSeedLabel), findsOneWidget);

    await cubit.close();
  });
}
```

> **Harness note:** `_GenerateScreenContent` is private, so the test cannot construct it directly. Two options — pick one and implement it:
> 1. Mount the public `GenerateScreen(gameplayBuilder: (_, __) => const SizedBox())` inside `MaterialApp` and remove the manual `BlocProvider` (the screen provides its own cubit; read `PuzzleGenerationService` via a `RepositoryProvider.value(value: _FakeService())` above it). Replace `_Harness` usage accordingly.
> 2. Add a `@visibleForTesting` public widget alias for the content in `generate_screen.dart`.
>
> Prefer option 1 (no production code added for tests):
> ```dart
> await tester.pumpWidget(
>   MaterialApp(
>     home: RepositoryProvider<PuzzleGenerationService>.value(
>       value: _FakeService(),
>       child: GenerateScreen(gameplayBuilder: (_, __) => const SizedBox()),
>     ),
>   ),
> );
> ```
> Then delete the `_Harness`/`BlocProvider.value` scaffold and the trailing `cubit.close()`.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test packages/crossword_ui/test/gameplay/presentation/generate_screen/generate_screen_test.dart`
Expected: FAIL — new labels not found.

- [ ] **Step 3: Add the `_LabeledStepper` widget**

At the bottom of `generate_screen.dart`, add:

```dart
/// A label with `−`/`+` buttons around a current numeric [value]. Buttons are
/// disabled when [enabled] is false or when the corresponding callback is null.
class _LabeledStepper extends StatelessWidget {
  final String label;
  final int value;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;
  final bool enabled;

  const _LabeledStepper({
    required this.label,
    required this.value,
    required this.onDecrement,
    required this.onIncrement,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Row(
          children: [
            IconButton(
              onPressed: enabled ? onDecrement : null,
              icon: const Icon(Icons.remove),
            ),
            SizedBox(
              width: 40,
              child: Text(
                '$value',
                textAlign: TextAlign.center,
              ),
            ),
            IconButton(
              onPressed: enabled ? onIncrement : null,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Insert the new sections into `_GenerateScreenContent`**

In the `Column` children of `_GenerateScreenContent.build`, insert these blocks. Place the **language** block first (before the existing size `Text(Strings.generateSizeLabel)`):

```dart
              const Text(Strings.generateLanguageLabel),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text(Strings.generateLanguageSwedish),
                    selected: state.languageCode == 'sv',
                    onSelected: state.isGenerating
                        ? null
                        : (_) => cubit.selectLanguage('sv'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
```

After the existing **max word length** `Wrap` and its trailing `const SizedBox(height: 24),`, insert the max-seconds and picture steppers:

```dart
              _LabeledStepper(
                label: Strings.generateMaxSecondsLabel,
                value: state.maxSeconds,
                enabled: !state.isGenerating,
                onDecrement: cubit.decrementMaxSeconds,
                onIncrement: cubit.incrementMaxSeconds,
              ),
              const SizedBox(height: 16),
              _LabeledStepper(
                label: Strings.generatePictureColsLabel,
                value: state.pictureCols,
                enabled: !state.isGenerating,
                onDecrement: cubit.decrementPictureCols,
                onIncrement: cubit.incrementPictureCols,
              ),
              const SizedBox(height: 16),
              _LabeledStepper(
                label: Strings.generatePictureRowsLabel,
                value: state.pictureRows,
                enabled: !state.isGenerating,
                onDecrement: cubit.decrementPictureRows,
                onIncrement: cubit.incrementPictureRows,
              ),
              const SizedBox(height: 24),
```

After the existing **seed words** `TextField` and its trailing `const SizedBox(height: 32),`, but BEFORE the generate `FilledButton`, insert the random-seed field. (Move the existing `const SizedBox(height: 32)` to after this block, or add a `const SizedBox(height: 24)` before and keep the `32` after.)

```dart
              const Text(Strings.generateRandomSeedLabel),
              const SizedBox(height: 8),
              TextField(
                controller: cubit.randomSeedController,
                enabled: !state.isGenerating,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: Strings.generateRandomSeedHint,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 32),
```

> Verify spacing visually after edit: the layout order should be Language → Storlek → Längsta ord → Max tid → Bildrutor (bredd) → Bildrutor (höjd) → Egna ord → Slumpfrö → Skapa → Testkorsord. Ensure exactly one separating `SizedBox` between sections (no doubled `height: 32`).

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test packages/crossword_ui/test/gameplay/presentation/generate_screen/generate_screen_test.dart`
Expected: PASS

- [ ] **Step 6: Full analyze + package test sweep**

Run:
```bash
flutter analyze packages/crossword_ui packages/crossword_api
flutter test packages/crossword_ui packages/crossword_api
```
Expected: no analyzer issues; all tests pass.

- [ ] **Step 7: Commit**

```bash
git add packages/crossword_ui/lib/gameplay/presentation/generate_screen/generate_screen.dart packages/crossword_ui/test/gameplay/presentation/generate_screen/generate_screen_test.dart
git commit -m "feat(ui): render all generation field controls in Generate screen"
```

---

### Task 7: Manual verification in both apps

**Files:** none (manual).

- [ ] **Step 1: Run the mobile app**

Run: `cd apps/mobile && flutter run`
Navigate to the Generate screen. Confirm all controls render: language chip (Svenska), size chips, max word length chips, max-seconds stepper, two picture steppers, seed words field, random-seed field. Verify steppers clamp at bounds and that shrinking size clamps picture dims down.

- [ ] **Step 2: Generate a puzzle and confirm the request**

With DevTools network view (or backend logs), trigger "Skapa" and confirm the POST body includes all fields, with `random_seed` present only when the field is filled. Set a random seed, generate twice with identical settings, and confirm reproducible output.

- [ ] **Step 3: Run the web app**

Run: `cd apps/web && flutter run -d chrome`
Repeat the visual checks. (Both apps share `crossword_ui`, so behavior should be identical.)

- [ ] **Step 4: Final commit (if any tweaks were needed)**

```bash
git add -A
git commit -m "chore: manual verification tweaks for generation fields"
```

---

## Notes for the implementer

- The repo is a multi-package Flutter workspace. Tests live under each package's `test/` mirroring `lib/`.
- Whenever a code step shows a full file, replace the whole file; when it shows a method, replace only that method.
- If any import path or constructor in a test step does not match reality, fix the test to match the actual code (the production code shapes in this plan are authoritative); do not change production signatures to satisfy a guessed test import.
- Commit after every task. Do not push or open a PR unless the user asks.
