# Font Picker Setting Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the player pick a handwritten font (from 9 options, previewed live) on a new Settings screen; the choice applies to the entered answer letters and clue text and is remembered between launches.

**Architecture:** The font choice is cross-feature shared state held in a `FontService` (a `ValueNotifier<AppFont>`), persisted via `shared_preferences` and loaded before the first frame. The Settings screen's cubit writes to the service; the gameplay cubit listens and feeds the font into `CrosswordState`, so the grid re-renders. Only cubits touch the service.

**Tech Stack:** Flutter, flutter_bloc (Cubit), google_fonts (`GoogleFonts.getFont`), shared_preferences, equatable.

---

## File Structure

**Created:**
- `lib/settings/domain/entities/app_font.dart` — `AppFont` enum (9 fonts + default + name lookup)
- `lib/settings/domain/services/font_service.dart` — `FontService` (ValueNotifier + persistence)
- `lib/settings/presentation/settings_screen/settings_screen.dart` — Settings screen (3-widget)
- `lib/settings/presentation/settings_screen/cubit/settings_cubit.dart`
- `lib/settings/presentation/settings_screen/cubit/settings_state.dart`
- `lib/settings/presentation/settings_screen/widgets/font_option_tile.dart` — one previewed font row
- Tests mirroring the above under `test/`

**Modified:**
- `pubspec.yaml` — add `shared_preferences`
- `lib/main.dart` — async `main`, load prefs, build `FontService`, `RepositoryProvider`
- `lib/common/data/constants/app_text_styles.dart` — optional `family` param on `answerLetter`/`clue`
- `lib/common/data/constants/strings.dart` — settings strings
- `lib/gameplay/presentation/crossword_screen/cubit/crossword_state.dart` — add `font`
- `lib/gameplay/presentation/crossword_screen/cubit/crossword_cubit.dart` — require `FontService`, listen
- `lib/gameplay/presentation/crossword_screen/crossword_screen.dart` — pass service to cubit, add settings icon
- `lib/gameplay/presentation/crossword_screen/widgets/crossword_grid.dart` — thread font family to cells
- `lib/gameplay/presentation/crossword_screen/widgets/answer_cell_widget.dart` — use font family
- `lib/gameplay/presentation/crossword_screen/widgets/hint_cell_widget.dart` — use font family
- `test/gameplay/presentation/crossword_screen/cubit/crossword_cubit_test.dart`
- `test/gameplay/presentation/crossword_screen/crossword_screen_test.dart`

---

## Task 1: Add shared_preferences dependency

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Add the dependency**

In `pubspec.yaml`, under `dependencies:` (after `google_fonts: ^6.2.1`), add:

```yaml
  shared_preferences: ^2.5.3
```

- [ ] **Step 2: Fetch packages**

Run: `flutter pub get`
Expected: completes with "Got dependencies!" (or "Changed N dependencies!").

- [ ] **Step 3: Verify analyze is clean**

Run: `flutter analyze`
Expected: "No issues found!"

- [ ] **Step 4: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "build: add shared_preferences dependency"
```

---

## Task 2: AppFont enum

**Files:**
- Create: `lib/settings/domain/entities/app_font.dart`
- Test: `test/settings/domain/entities/app_font_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/settings/domain/entities/app_font_test.dart`:

```dart
import 'package:crosswords/settings/domain/entities/app_font.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('there are 9 fonts and Patrick Hand is the default', () {
    expect(AppFont.values.length, 9);
    expect(AppFont.defaultFont, AppFont.patrickHand);
  });

  test('each font exposes a non-empty Google family and display name', () {
    for (final font in AppFont.values) {
      expect(font.googleFamily, isNotEmpty);
      expect(font.displayName, isNotEmpty);
    }
  });

  test('fromName round-trips a valid enum name', () {
    expect(AppFont.fromName(AppFont.caveat.name), AppFont.caveat);
  });

  test('fromName falls back to the default for null or unknown names', () {
    expect(AppFont.fromName(null), AppFont.defaultFont);
    expect(AppFont.fromName('not-a-font'), AppFont.defaultFont);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/settings/domain/entities/app_font_test.dart`
Expected: FAIL — `app_font.dart` does not exist / `AppFont` undefined.

- [ ] **Step 3: Write minimal implementation**

Create `lib/settings/domain/entities/app_font.dart`:

```dart
/// The handwritten fonts the player can choose for the crossword.
///
/// [googleFamily] is the family name passed to `GoogleFonts.getFont`.
enum AppFont {
  patrickHand('Patrick Hand'),
  caveat('Caveat'),
  indieFlower('Indie Flower'),
  shadowsIntoLight('Shadows Into Light'),
  kalam('Kalam'),
  architectsDaughter('Architects Daughter'),
  comingSoon('Coming Soon'),
  gloriaHallelujah('Gloria Hallelujah'),
  justAnotherHand('Just Another Hand');

  const AppFont(this.googleFamily);

  /// Google Fonts family name, e.g. 'Patrick Hand'.
  final String googleFamily;

  /// Human-readable name shown in the picker.
  String get displayName => googleFamily;

  /// The font used when nothing has been chosen yet.
  static const AppFont defaultFont = AppFont.patrickHand;

  /// Resolves a stored [name] back to a font, falling back to [defaultFont]
  /// when the value is missing or unrecognised.
  static AppFont fromName(String? name) {
    return AppFont.values.firstWhere(
      (font) => font.name == name,
      orElse: () => defaultFont,
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/settings/domain/entities/app_font_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/settings/domain/entities/app_font.dart test/settings/domain/entities/app_font_test.dart
git commit -m "feat: add AppFont enum of selectable handwritten fonts"
```

---

## Task 3: FontService

**Files:**
- Create: `lib/settings/domain/services/font_service.dart`
- Test: `test/settings/domain/services/font_service_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/settings/domain/services/font_service_test.dart`:

```dart
import 'package:crosswords/settings/domain/entities/app_font.dart';
import 'package:crosswords/settings/domain/services/font_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('readStored returns the default when nothing is stored', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    expect(FontService.readStored(prefs), AppFont.defaultFont);
  });

  test('readStored returns the stored font', () async {
    SharedPreferences.setMockInitialValues({
      'selected_font': AppFont.kalam.name,
    });
    final prefs = await SharedPreferences.getInstance();

    expect(FontService.readStored(prefs), AppFont.kalam);
  });

  test('selectFont updates the notifier and persists the value', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final service = FontService(prefs: prefs);

    expect(service.selectedFont.value, AppFont.defaultFont);

    await service.selectFont(AppFont.caveat);

    expect(service.selectedFont.value, AppFont.caveat);
    expect(prefs.getString('selected_font'), AppFont.caveat.name);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/settings/domain/services/font_service_test.dart`
Expected: FAIL — `font_service.dart` does not exist.

- [ ] **Step 3: Write minimal implementation**

Create `lib/settings/domain/services/font_service.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../entities/app_font.dart';

/// Holds the currently selected [AppFont] as cross-feature shared state and
/// persists it locally. Only cubits should touch this service.
class FontService {
  static const String _key = 'selected_font';

  final SharedPreferences _prefs;

  /// The active font. Listeners (cubits) react to changes.
  final ValueNotifier<AppFont> selectedFont;

  FontService({
    required SharedPreferences prefs,
    AppFont? initial,
  })  : _prefs = prefs,
        selectedFont = ValueNotifier(initial ?? readStored(prefs));

  /// Reads the persisted font, falling back to [AppFont.defaultFont].
  static AppFont readStored(SharedPreferences prefs) {
    return AppFont.fromName(prefs.getString(_key));
  }

  /// Selects [font], notifies listeners, and persists the choice. A failed
  /// write is non-fatal — the in-memory selection still applies this session.
  Future<void> selectFont(AppFont font) async {
    selectedFont.value = font;
    try {
      await _prefs.setString(_key, font.name);
    } catch (_) {
      // Persistence failure is non-fatal.
    }
  }

  void dispose() => selectedFont.dispose();
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/settings/domain/services/font_service_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/settings/domain/services/font_service.dart test/settings/domain/services/font_service_test.dart
git commit -m "feat: add FontService for selected-font state and persistence"
```

---

## Task 4: AppTextStyles family parameter

**Files:**
- Modify: `lib/common/data/constants/app_text_styles.dart`
- Test: `test/common/data/constants/app_text_styles_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/common/data/constants/app_text_styles_test.dart`:

```dart
import 'package:crosswords/common/data/constants/app_text_styles.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('answerLetter applies the given size and weight', () {
    final style = AppTextStyles.answerLetter(20, family: 'Caveat');

    expect(style.fontSize, 20);
    expect(style.fontWeight?.index, isNotNull);
  });

  test('answerLetter works with no family (default font)', () {
    final style = AppTextStyles.answerLetter(18);

    expect(style.fontSize, 18);
  });

  test('clue applies the given size with and without a family', () {
    expect(AppTextStyles.clue(12, family: 'Kalam').fontSize, 12);
    expect(AppTextStyles.clue(12).fontSize, 12);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/common/data/constants/app_text_styles_test.dart`
Expected: FAIL — `answerLetter`/`clue` do not accept a `family` argument.

- [ ] **Step 3: Write minimal implementation**

In `lib/common/data/constants/app_text_styles.dart`, replace the `answerLetter` and `clue` methods with versions that accept an optional `family` and use `GoogleFonts.getFont`. The default family strings reproduce the current fonts so existing call sites are unchanged.

```dart
  /// Entered answer letters — neat block-capital handwriting, as if the solver
  /// filled the grid in by hand. Size is supplied per-cell since it scales with
  /// the cell dimensions. [family] overrides the handwritten font family.
  static TextStyle answerLetter(
    double fontSize, {
    Color color = AppColors.ink,
    String? family,
  }) {
    return GoogleFonts.getFont(
      family ?? 'Patrick Hand',
      fontSize: fontSize,
      fontWeight: FontWeight.w400,
      color: color,
      height: 1.0,
    );
  }

  /// Clue text inside hint cells. Size scales with the cell. [family] overrides
  /// the font family (used when the player picks a handwritten font).
  static TextStyle clue(double fontSize, {String? family}) {
    return GoogleFonts.getFont(
      family ?? 'Roboto Condensed',
      fontSize: fontSize,
      fontWeight: FontWeight.w500,
      color: AppColors.ink,
      height: 1.05,
    );
  }
```

Leave `imageLabel` and `appBarTitle` unchanged.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/common/data/constants/app_text_styles_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Verify nothing else broke**

Run: `flutter analyze`
Expected: "No issues found!"

- [ ] **Step 6: Commit**

```bash
git add lib/common/data/constants/app_text_styles.dart test/common/data/constants/app_text_styles_test.dart
git commit -m "feat: allow answerLetter and clue styles to take a font family"
```

---

## Task 5: Settings strings

**Files:**
- Modify: `lib/common/data/constants/strings.dart`

- [ ] **Step 1: Add the strings**

In `lib/common/data/constants/strings.dart`, add inside the `Strings` class (after `resetViewTooltip`):

```dart
  /// Tooltip/semantics label for the app-bar button that opens settings.
  static const String settingsTooltip = 'Inställningar';

  /// Title of the settings screen.
  static const String settingsTitle = 'Inställningar';

  /// Section header for the font picker on the settings screen.
  static const String fontSettingLabel = 'Typsnitt';
```

- [ ] **Step 2: Verify analyze is clean**

Run: `flutter analyze`
Expected: "No issues found!"

- [ ] **Step 3: Commit**

```bash
git add lib/common/data/constants/strings.dart
git commit -m "feat: add settings and font picker strings"
```

---

## Task 6: Wire FontService into main.dart (DI)

**Files:**
- Modify: `lib/main.dart`

This adds the service provider without yet changing any cubit, so the app keeps compiling and all tests stay green.

- [ ] **Step 1: Rewrite main.dart**

Replace the entire contents of `lib/main.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'common/data/constants/app_colors.dart';
import 'common/data/constants/strings.dart';
import 'gameplay/presentation/crossword_screen/crossword_screen.dart';
import 'settings/domain/services/font_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final fontService = FontService(prefs: prefs);
  runApp(CrosswordsApp(fontService: fontService));
}

class CrosswordsApp extends StatelessWidget {
  final FontService fontService;

  const CrosswordsApp({required this.fontService, super.key});

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
        home: const CrosswordScreen(),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify analyze is clean and tests still pass**

Run: `flutter analyze`
Expected: "No issues found!"

Run: `flutter test`
Expected: all existing tests PASS (the screen test pumps `CrosswordScreen` directly, unaffected).

- [ ] **Step 3: Commit**

```bash
git add lib/main.dart
git commit -m "feat: provide FontService via RepositoryProvider and load prefs at startup"
```

---

## Task 7: Add font to CrosswordState and wire CrosswordCubit to FontService

**Files:**
- Modify: `lib/gameplay/presentation/crossword_screen/cubit/crossword_state.dart`
- Modify: `lib/gameplay/presentation/crossword_screen/cubit/crossword_cubit.dart`
- Modify: `lib/gameplay/presentation/crossword_screen/crossword_screen.dart` (cubit creation only)
- Modify: `test/gameplay/presentation/crossword_screen/cubit/crossword_cubit_test.dart`
- Modify: `test/gameplay/presentation/crossword_screen/crossword_screen_test.dart`

- [ ] **Step 1: Update the cubit test (failing test first)**

Replace the imports and `main()` setup region of `test/gameplay/presentation/crossword_screen/cubit/crossword_cubit_test.dart`.

Change the import block at the top to add:

```dart
import 'package:crosswords/settings/domain/entities/app_font.dart';
import 'package:crosswords/settings/domain/services/font_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
```

Replace the `void main() { ... setUp/tearDown ... }` opening (lines from `void main() {` through the `tearDown` block) with:

```dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CrosswordCubit cubit;
  late FontService fontService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    fontService = FontService(prefs: prefs);
    cubit = CrosswordCubit(
      puzzle: _buildTestPuzzle(),
      fontService: fontService,
    );
  });

  tearDown(() {
    cubit.close();
    fontService.dispose();
  });
```

Update the disposal test (the last test) so its locally-created cubit also gets a service. Replace its first line:

```dart
    final cubit = CrosswordCubit(puzzle: _buildTestPuzzle());
```

with:

```dart
    final localPrefs = await SharedPreferences.getInstance();
    final cubit = CrosswordCubit(
      puzzle: _buildTestPuzzle(),
      fontService: FontService(prefs: localPrefs),
    );
```

Add this new test just before the closing `}` of `main`:

```dart
  test('font changes in the service are reflected in state', () async {
    expect(cubit.state.font, AppFont.defaultFont);

    await fontService.selectFont(AppFont.caveat);

    expect(cubit.state.font, AppFont.caveat);
  });
```

- [ ] **Step 2: Run the cubit test to verify it fails**

Run: `flutter test test/gameplay/presentation/crossword_screen/cubit/crossword_cubit_test.dart`
Expected: FAIL — `CrosswordCubit` has no `fontService` parameter / `state.font` undefined.

- [ ] **Step 3: Add `font` to CrosswordState**

In `lib/gameplay/presentation/crossword_screen/cubit/crossword_state.dart`:

Add the import:

```dart
import '../../../../settings/domain/entities/app_font.dart';
```

Add the field (after `highlightedCells`):

```dart
  final AppFont font;
```

Add the constructor parameter (after `highlightedCells` default):

```dart
    this.font = AppFont.defaultFont,
```

Add `font` to `props`:

```dart
  @override
  List<Object?> get props => [
        userInputs,
        selectedCell,
        currentDirection,
        highlightedCells,
        font,
      ];
```

Add `font` to `copyWith` (parameter and usage):

```dart
  CrosswordState copyWith({
    Map<(int, int), String>? userInputs,
    (int, int)? selectedCell,
    Direction? currentDirection,
    Set<(int, int)>? highlightedCells,
    AppFont? font,
  }) {
    return CrosswordState(
      puzzle: puzzle,
      userInputs: userInputs ?? this.userInputs,
      selectedCell: selectedCell ?? this.selectedCell,
      currentDirection: currentDirection ?? this.currentDirection,
      highlightedCells: highlightedCells ?? this.highlightedCells,
      font: font ?? this.font,
    );
  }
```

- [ ] **Step 4: Wire FontService into CrosswordCubit**

In `lib/gameplay/presentation/crossword_screen/cubit/crossword_cubit.dart`:

Add the import:

```dart
import '../../../../settings/domain/services/font_service.dart';
```

Replace the field declarations and constructor (lines 10–15) with:

```dart
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
```

Replace the `close()` method with:

```dart
  @override
  Future<void> close() {
    _fontService.selectedFont.removeListener(_onFontChanged);
    focusNode.dispose();
    transformationController.dispose();
    return super.close();
  }
```

- [ ] **Step 5: Pass the service when creating the cubit in CrosswordScreen**

In `lib/gameplay/presentation/crossword_screen/crossword_screen.dart`:

Add the import:

```dart
import '../../../settings/domain/services/font_service.dart';
```

Replace the `BlocProvider` create line:

```dart
      create: (context) => CrosswordCubit(puzzle: buildSamplePuzzle()),
```

with:

```dart
      create: (context) => CrosswordCubit(
        puzzle: buildSamplePuzzle(),
        fontService: context.read<FontService>(),
      ),
```

- [ ] **Step 6: Update the screen widget test to provide FontService**

In `test/gameplay/presentation/crossword_screen/crossword_screen_test.dart`:

Replace the import block at the top with:

```dart
import 'package:crosswords/gameplay/presentation/crossword_screen/crossword_screen.dart';
import 'package:crosswords/settings/domain/services/font_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
```

Add this helper above `void main()`:

```dart
Future<Widget> _appUnderTest() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return RepositoryProvider<FontService>.value(
    value: FontService(prefs: prefs),
    child: const MaterialApp(home: CrosswordScreen()),
  );
}
```

In BOTH `testWidgets` bodies, replace:

```dart
      await tester.pumpWidget(const MaterialApp(home: CrosswordScreen()));
```

with:

```dart
      await tester.pumpWidget(await _appUnderTest());
```

(Note: the second test's callback signature is `(tester) async`, which already allows `await`.)

- [ ] **Step 7: Run the full suite**

Run: `flutter test`
Expected: all tests PASS (including the new font-change test).

Run: `flutter analyze`
Expected: "No issues found!"

- [ ] **Step 8: Commit**

```bash
git add lib/gameplay/presentation/crossword_screen/cubit/crossword_state.dart \
        lib/gameplay/presentation/crossword_screen/cubit/crossword_cubit.dart \
        lib/gameplay/presentation/crossword_screen/crossword_screen.dart \
        test/gameplay/presentation/crossword_screen/cubit/crossword_cubit_test.dart \
        test/gameplay/presentation/crossword_screen/crossword_screen_test.dart
git commit -m "feat: drive crossword font from FontService via CrosswordState"
```

---

## Task 8: Render the selected font in the grid cells

**Files:**
- Modify: `lib/gameplay/presentation/crossword_screen/widgets/crossword_grid.dart`
- Modify: `lib/gameplay/presentation/crossword_screen/widgets/answer_cell_widget.dart`
- Modify: `lib/gameplay/presentation/crossword_screen/widgets/hint_cell_widget.dart`

No new unit test — this is rendering wiring covered by the existing screen smoke test (which already asserts the screen builds without throwing). Verify via analyze + full suite.

- [ ] **Step 1: Add a `fontFamily` field to AnswerCellWidget**

In `lib/gameplay/presentation/crossword_screen/widgets/answer_cell_widget.dart`:

Add the field (after `onTap`):

```dart
  final String fontFamily;
```

Add it to the constructor (as a required named param, after `onTap`):

```dart
    required this.fontFamily,
```

Update the `Text` style line:

```dart
          style: AppTextStyles.answerLetter(size * 0.66, family: fontFamily),
```

- [ ] **Step 2: Add a `fontFamily` field to HintCellWidget**

In `lib/gameplay/presentation/crossword_screen/widgets/hint_cell_widget.dart`:

Add the field (after `onTap`):

```dart
  final String fontFamily;
```

Add to the constructor (after `onTap`):

```dart
    required this.fontFamily,
```

Update the clue `Text` style line:

```dart
                    style: AppTextStyles.clue(size * 0.2, family: fontFamily),
```

- [ ] **Step 3: Pass the font family from CrosswordGrid**

In `lib/gameplay/presentation/crossword_screen/widgets/crossword_grid.dart`, add the import:

```dart
import '../../../../settings/domain/entities/app_font.dart';
```

In `_buildCell`, compute the family once at the top of the method (after the `cell == null` guard):

```dart
    final fontFamily = state.font.googleFamily;
```

Update the `HintCell()` case to pass it:

```dart
      HintCell() => HintCellWidget(
          cell: cell,
          size: cellSize,
          onTap: () => cubit.selectCell(row, col),
          fontFamily: fontFamily,
        ),
```

Update the `AnswerCell()` case to pass it:

```dart
      AnswerCell() => AnswerCellWidget(
          userInput: state.userInputs[(row, col)],
          isSelected: state.selectedCell == (row, col),
          isHighlighted: state.highlightedCells.contains((row, col)),
          size: cellSize,
          onTap: () => cubit.selectCell(row, col),
          fontFamily: fontFamily,
        ),
```

> Note: `state.font.googleFamily` requires `AppFont` to be imported (added above). `state` is already a field on `CrosswordGrid`.

- [ ] **Step 4: Run the full suite and analyze**

Run: `flutter test`
Expected: all tests PASS.

Run: `flutter analyze`
Expected: "No issues found!"

- [ ] **Step 5: Commit**

```bash
git add lib/gameplay/presentation/crossword_screen/widgets/crossword_grid.dart \
        lib/gameplay/presentation/crossword_screen/widgets/answer_cell_widget.dart \
        lib/gameplay/presentation/crossword_screen/widgets/hint_cell_widget.dart
git commit -m "feat: render entered letters and clues in the selected font"
```

---

## Task 9: SettingsState and SettingsCubit

**Files:**
- Create: `lib/settings/presentation/settings_screen/cubit/settings_state.dart`
- Create: `lib/settings/presentation/settings_screen/cubit/settings_cubit.dart`
- Test: `test/settings/presentation/settings_screen/cubit/settings_cubit_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/settings/presentation/settings_screen/cubit/settings_cubit_test.dart`:

```dart
import 'package:crosswords/settings/domain/entities/app_font.dart';
import 'package:crosswords/settings/domain/services/font_service.dart';
import 'package:crosswords/settings/presentation/settings_screen/cubit/settings_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FontService fontService;
  late SettingsCubit cubit;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    fontService = FontService(prefs: prefs);
    cubit = SettingsCubit(fontService: fontService);
  });

  tearDown(() {
    cubit.close();
    fontService.dispose();
  });

  test('initial state lists all fonts and the current selection', () {
    expect(cubit.state.fonts, AppFont.values);
    expect(cubit.state.selectedFont, AppFont.defaultFont);
  });

  test('selectFont updates state and the service', () async {
    await cubit.selectFont(AppFont.gloriaHallelujah);

    expect(cubit.state.selectedFont, AppFont.gloriaHallelujah);
    expect(fontService.selectedFont.value, AppFont.gloriaHallelujah);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/settings/presentation/settings_screen/cubit/settings_cubit_test.dart`
Expected: FAIL — `settings_cubit.dart` does not exist.

- [ ] **Step 3: Implement the state**

Create `lib/settings/presentation/settings_screen/cubit/settings_state.dart`:

```dart
import 'package:equatable/equatable.dart';

import '../../../domain/entities/app_font.dart';

class SettingsState extends Equatable {
  final List<AppFont> fonts;
  final AppFont selectedFont;

  const SettingsState({
    required this.fonts,
    required this.selectedFont,
  });

  @override
  List<Object?> get props => [fonts, selectedFont];

  SettingsState copyWith({
    List<AppFont>? fonts,
    AppFont? selectedFont,
  }) {
    return SettingsState(
      fonts: fonts ?? this.fonts,
      selectedFont: selectedFont ?? this.selectedFont,
    );
  }
}
```

- [ ] **Step 4: Implement the cubit**

Create `lib/settings/presentation/settings_screen/cubit/settings_cubit.dart`:

```dart
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/app_font.dart';
import '../../../domain/services/font_service.dart';
import 'settings_state.dart';

class SettingsCubit extends Cubit<SettingsState> {
  final FontService _fontService;

  SettingsCubit({required FontService fontService})
      : _fontService = fontService,
        super(SettingsState(
          fonts: AppFont.values,
          selectedFont: fontService.selectedFont.value,
        ));

  Future<void> selectFont(AppFont font) async {
    await _fontService.selectFont(font);
    emit(state.copyWith(selectedFont: font));
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/settings/presentation/settings_screen/cubit/settings_cubit_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/settings/presentation/settings_screen/cubit/ test/settings/presentation/settings_screen/cubit/
git commit -m "feat: add SettingsCubit and state for the font picker"
```

---

## Task 10: FontOptionTile widget

**Files:**
- Create: `lib/settings/presentation/settings_screen/widgets/font_option_tile.dart`

This is a pure presentation widget; it is exercised by the screen smoke test in Task 11. Verify via analyze.

- [ ] **Step 1: Implement the tile**

Create `lib/settings/presentation/settings_screen/widgets/font_option_tile.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../common/data/constants/app_colors.dart';
import '../../../domain/entities/app_font.dart';

/// A single selectable font row that previews itself in its own font.
class FontOptionTile extends StatelessWidget {
  final AppFont font;
  final bool isSelected;
  final VoidCallback onTap;

  const FontOptionTile({
    required this.font,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? AppColors.highlight : AppColors.paper,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      font.displayName,
                      style: GoogleFonts.getFont(
                        font.googleFamily,
                        fontSize: 22,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ABCÅÄÖ',
                      style: GoogleFonts.getFont(
                        font.googleFamily,
                        fontSize: 18,
                        color: AppColors.inkMuted,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(Icons.check, color: AppColors.brand),
            ],
          ),
        ),
      ),
    );
  }
}
```

> Note: `AppColors.highlight`, `paper`, `ink`, `inkMuted`, and `brand` are all already defined (used elsewhere in the app). If any is missing at implementation time, substitute the nearest existing AppColors constant rather than hardcoding a color.

- [ ] **Step 2: Verify analyze is clean**

Run: `flutter analyze`
Expected: "No issues found!"

- [ ] **Step 3: Commit**

```bash
git add lib/settings/presentation/settings_screen/widgets/font_option_tile.dart
git commit -m "feat: add FontOptionTile that previews each font in its own font"
```

---

## Task 11: SettingsScreen and entry point from the crossword app bar

**Files:**
- Create: `lib/settings/presentation/settings_screen/settings_screen.dart`
- Modify: `lib/gameplay/presentation/crossword_screen/crossword_screen.dart` (app-bar action)
- Test: `test/settings/presentation/settings_screen/settings_screen_test.dart`

- [ ] **Step 1: Write the failing widget test**

Create `test/settings/presentation/settings_screen/settings_screen_test.dart`:

```dart
import 'package:crosswords/settings/domain/entities/app_font.dart';
import 'package:crosswords/settings/domain/services/font_service.dart';
import 'package:crosswords/settings/presentation/settings_screen/settings_screen.dart';
import 'package:crosswords/settings/presentation/settings_screen/widgets/font_option_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Widget> _settingsUnderTest() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return RepositoryProvider<FontService>.value(
    value: FontService(prefs: prefs),
    child: const MaterialApp(home: SettingsScreen()),
  );
}

void main() {
  testWidgets('SettingsScreen lists all fonts without throwing', (tester) async {
    await tester.pumpWidget(await _settingsUnderTest());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(FontOptionTile), findsNWidgets(AppFont.values.length));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/settings/presentation/settings_screen/settings_screen_test.dart`
Expected: FAIL — `settings_screen.dart` does not exist.

- [ ] **Step 3: Implement the settings screen (3-widget structure)**

Create `lib/settings/presentation/settings_screen/settings_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../common/data/constants/app_colors.dart';
import '../../../common/data/constants/app_text_styles.dart';
import '../../../common/data/constants/strings.dart';
import '../../domain/services/font_service.dart';
import 'cubit/settings_cubit.dart';
import 'cubit/settings_state.dart';
import 'widgets/font_option_tile.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          SettingsCubit(fontService: context.read<FontService>()),
      child: const SettingsScreenBuilder(),
    );
  }
}

class SettingsScreenBuilder extends StatelessWidget {
  const SettingsScreenBuilder({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) => SettingsScreenContent(state: state),
    );
  }
}

class SettingsScreenContent extends StatelessWidget {
  final SettingsState state;

  const SettingsScreenContent({required this.state, super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SettingsCubit>();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(Strings.settingsTitle, style: AppTextStyles.appBarTitle()),
        centerTitle: true,
        backgroundColor: AppColors.brand,
        foregroundColor: AppColors.onBrand,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                Strings.fontSettingLabel,
                style: AppTextStyles.clue(16),
              ),
            ),
            for (final font in state.fonts)
              FontOptionTile(
                font: font,
                isSelected: font == state.selectedFont,
                onTap: () => cubit.selectFont(font),
              ),
          ],
        ),
      ),
    );
  }
}
```

> Note: `AppColors.onBrand` and `AppColors.brand` are already used by the crossword app bar, so they exist.

- [ ] **Step 4: Run the widget test to verify it passes**

Run: `flutter test test/settings/presentation/settings_screen/settings_screen_test.dart`
Expected: PASS — 9 `FontOptionTile`s found, no exception.

- [ ] **Step 5: Add the settings icon to the crossword app bar**

In `lib/gameplay/presentation/crossword_screen/crossword_screen.dart`:

Add the import:

```dart
import '../../../settings/presentation/settings_screen/settings_screen.dart';
```

In the `AppBar`'s `actions` list, add a settings button BEFORE the existing reset button so the list becomes:

```dart
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: Strings.settingsTooltip,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.fit_screen),
            tooltip: Strings.resetViewTooltip,
            onPressed: cubit.resetView,
          ),
        ],
```

> The pushed `SettingsScreen` reads `FontService` from the `RepositoryProvider` above `MaterialApp`, so it is available on the new route.

- [ ] **Step 6: Add a test that the icon opens settings**

In `test/gameplay/presentation/crossword_screen/crossword_screen_test.dart`, add this test inside `main()` (the `_appUnderTest()` helper and `SettingsScreen`/`Icons.settings` are reachable; add the import `import 'package:crosswords/settings/presentation/settings_screen/settings_screen.dart';` at the top):

```dart
  testWidgets('tapping the settings icon opens the settings screen', (
    tester,
  ) async {
    await tester.pumpWidget(await _appUnderTest());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsOneWidget);
  });
```

- [ ] **Step 7: Run the full suite and analyze**

Run: `flutter test`
Expected: all tests PASS.

Run: `flutter analyze`
Expected: "No issues found!"

- [ ] **Step 8: Commit**

```bash
git add lib/settings/presentation/settings_screen/settings_screen.dart \
        lib/gameplay/presentation/crossword_screen/crossword_screen.dart \
        test/settings/presentation/settings_screen/settings_screen_test.dart \
        test/gameplay/presentation/crossword_screen/crossword_screen_test.dart
git commit -m "feat: add settings screen with font picker and app-bar entry point"
```

---

## Final verification

- [ ] Run `flutter test` — all tests pass.
- [ ] Run `flutter analyze` — no issues.
- [ ] Manual device check (`flutter run`): open settings via the gear icon, pick several fonts, confirm the grid letters and clue text update live and the choice survives an app restart.

---

## Self-Review Notes

- **Spec coverage:** font model (Task 2), persistence/service (Tasks 1, 3, 6), settings screen + 3-widget structure + previews (Tasks 9–11), applying font to letters + clues (Tasks 4, 7, 8), strings (Task 5), testing (each task), error handling/fallback (Task 3). All spec sections map to tasks.
- **Out of scope confirmed:** no cloud sync, no app-bar/title font change, single font choice for both letters and clues — none are implemented.
- **Type consistency:** `AppFont.googleFamily`/`displayName`/`fromName`/`defaultFont`, `FontService.selectedFont`/`selectFont`/`readStored`/`dispose`, `SettingsState.fonts`/`selectedFont`, `CrosswordState.font`, and the `fontFamily` widget params are used consistently across tasks.
