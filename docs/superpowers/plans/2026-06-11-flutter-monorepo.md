# Flutter Web + Mobile Monorepo Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restructure the single Flutter app into a pub-workspace monorepo with two apps (`apps/mobile`, `apps/web`) that reuse a shared crossword play engine through two packages (`packages/crossword_core`, `packages/crossword_ui`).

**Architecture:** Native Dart pub workspace, dependencies flowing `apps → crossword_ui → crossword_core`. `crossword_core` holds the puzzle model + JSON pipeline (no widgets). `crossword_ui` holds the grid widgets, `CrosswordCubit`, theme, and the `CrosswordPlayer` body widget (no Scaffold). Each app owns its own Scaffold/navigation and embeds `CrosswordPlayer`.

**Tech Stack:** Flutter 3.41.9, flutter_bloc (Cubit), Equatable, google_fonts, shared_preferences, pub workspaces (`resolution: workspace`).

**Spec:** `docs/superpowers/specs/2026-06-11-flutter-monorepo-design.md`

---

## Strategy Notes

This is a **migration of already-tested code**, not greenfield. The existing test suite is the safety net: most steps move files + fix imports, then run the moved tests to prove behavior is preserved. New tests are written only for genuinely new code (the `CrosswordPlayer` extraction harness and a web smoke test).

Build packages standalone first (each `flutter test` passes in isolation with path dependencies), create the two apps, then flip everything to `resolution: workspace` in the final task. Each task ends in a compiling, tested state.

**Reuse seam (`CrosswordPlayer`):** the current `crossword_screen.dart` is split. The `Scaffold`/`AppBar` chrome becomes each app's responsibility. `crossword_ui` exposes `CrosswordCubit` + `CrosswordState` + a `CrosswordPlayer` body widget that consumes the cubit from context. Apps own the `BlocProvider` so their app bars can call `cubit.resetView`.

### Import-rewrite cheat sheet (applies throughout)

- Tests/app code currently import the app via `package:crosswords/...`. After the move, symbols resolve from their new package:
  - entities, DTOs, resolver, data source → `package:crossword_core/crossword_core.dart`
  - widgets, cubit, state, `AppColors`, `AppTextStyles`, `Strings`, `AppFont`, `FontService`, `CrosswordPlayer` → `package:crossword_ui/crossword_ui.dart`
- **Inside** a package, files in the same package keep their existing relative imports (the folder structure is preserved on move). Only **cross-package** references (`crossword_ui` → `crossword_core` entities) switch to `package:crossword_core/crossword_core.dart`.

---

## File Structure (end state)

```
crosswords/
├── pubspec.yaml                        # workspace root (members + dev deps)
├── analysis_options.yaml               # unchanged lint rules
├── firebase.json / .firebaserc         # hosting public dir → apps/web/build/web
├── apps/
│   ├── mobile/
│   │   ├── pubspec.yaml
│   │   ├── analysis_options.yaml        # include: ../../analysis_options.yaml
│   │   ├── android/  ios/  web?(no)
│   │   ├── lib/
│   │   │   ├── main.dart
│   │   │   ├── crossword/mobile_crossword_screen.dart
│   │   │   └── settings/...             # settings screen, cubit, state, tile
│   │   └── test/...
│   └── web/
│       ├── pubspec.yaml
│       ├── analysis_options.yaml
│       ├── web/                         # index.html, icons, manifest, favicon
│       ├── lib/
│       │   ├── main.dart
│       │   └── crossword/web_crossword_screen.dart
│       └── test/web_smoke_test.dart
└── packages/
    ├── crossword_core/
    │   ├── pubspec.yaml
    │   ├── analysis_options.yaml
    │   ├── assets/puzzles/generated_crossword.json
    │   ├── lib/
    │   │   ├── crossword_core.dart      # barrel
    │   │   ├── load_bundled_puzzle.dart
    │   │   └── gameplay/domain/... , gameplay/data/...
    │   └── test/...
    └── crossword_ui/
        ├── pubspec.yaml
        ├── analysis_options.yaml
        ├── lib/
        │   ├── crossword_ui.dart        # barrel
        │   ├── common/data/constants/...
        │   ├── settings/domain/...      # AppFont, FontService
        │   └── gameplay/presentation/crossword_screen/...
        │       ├── crossword_player.dart
        │       ├── cubit/...
        │       └── widgets/...
        └── test/...
```

---

## Task 1: Create `crossword_core` package

**Files:**
- Create: `packages/crossword_core/pubspec.yaml`
- Create: `packages/crossword_core/analysis_options.yaml`
- Create: `packages/crossword_core/lib/crossword_core.dart`
- Create: `packages/crossword_core/lib/load_bundled_puzzle.dart`
- Move: `lib/gameplay/domain/entities/*.dart` → `packages/crossword_core/lib/gameplay/domain/entities/`
- Move: `lib/gameplay/data/entities/dto/*.dart` → `packages/crossword_core/lib/gameplay/data/entities/dto/`
- Move: `lib/gameplay/data/local_puzzle_data_source.dart`, `lib/gameplay/data/puzzle_resolver.dart` → `packages/crossword_core/lib/gameplay/data/`
- Move: `assets/puzzles/generated_crossword.json` → `packages/crossword_core/assets/puzzles/`
- Move tests → `packages/crossword_core/test/`: `puzzle_dto_test.dart`, `local_puzzle_data_source_test.dart`, `puzzle_resolver_test.dart`, `crossword_puzzle_test.dart`

- [ ] **Step 1: Create the package pubspec**

`packages/crossword_core/pubspec.yaml`:

```yaml
name: crossword_core
description: Crossword puzzle domain model and JSON pipeline (shared core).
publish_to: 'none'
version: 0.0.1

environment:
  sdk: ^3.11.5

dependencies:
  flutter:
    sdk: flutter
  equatable: ^2.0.7

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0

flutter:
  uses-material-design: true
  assets:
    - assets/puzzles/generated_crossword.json
```

- [ ] **Step 2: Inherit the shared lint rules**

`packages/crossword_core/analysis_options.yaml`:

```yaml
include: ../../analysis_options.yaml
```

- [ ] **Step 3: Move the domain + data files and the asset**

```bash
mkdir -p packages/crossword_core/lib/gameplay/domain/entities
mkdir -p packages/crossword_core/lib/gameplay/data/entities/dto
mkdir -p packages/crossword_core/assets/puzzles
git mv lib/gameplay/domain/entities/*.dart packages/crossword_core/lib/gameplay/domain/entities/
git mv lib/gameplay/data/entities/dto/*.dart packages/crossword_core/lib/gameplay/data/entities/dto/
git mv lib/gameplay/data/local_puzzle_data_source.dart packages/crossword_core/lib/gameplay/data/
git mv lib/gameplay/data/puzzle_resolver.dart packages/crossword_core/lib/gameplay/data/
git mv assets/puzzles/generated_crossword.json packages/crossword_core/assets/puzzles/
```

Intra-package relative imports (`../domain/entities/...`, `entities/dto/...`) are unchanged because the folder structure is preserved.

- [ ] **Step 4: Fix the bundled-asset key**

In `packages/crossword_core/lib/gameplay/data/local_puzzle_data_source.dart`, change the asset path constant to the package-prefixed form (assets shipped in a package are addressed via `packages/<name>/...` even from inside the package):

```dart
  static const String _assetPath =
      'packages/crossword_core/assets/puzzles/generated_crossword.json';
```

- [ ] **Step 5: Add the public barrel**

`packages/crossword_core/lib/crossword_core.dart`:

```dart
export 'gameplay/domain/entities/arrow_shape.dart';
export 'gameplay/domain/entities/cell.dart';
export 'gameplay/domain/entities/clue_arrow.dart';
export 'gameplay/domain/entities/crossword_puzzle.dart';
export 'gameplay/domain/entities/direction.dart';
export 'gameplay/domain/entities/word.dart';
export 'gameplay/data/entities/dto/puzzle_dto.dart';
export 'gameplay/data/local_puzzle_data_source.dart';
export 'gameplay/data/puzzle_resolver.dart';
export 'load_bundled_puzzle.dart';
```

- [ ] **Step 6: Add the ergonomic loader entry**

`packages/crossword_core/lib/load_bundled_puzzle.dart`:

```dart
import 'gameplay/data/local_puzzle_data_source.dart';
import 'gameplay/domain/entities/crossword_puzzle.dart';

/// Loads the bundled crossword shipped inside this package.
Future<CrosswordPuzzle> loadBundledPuzzle() =>
    LocalPuzzleDataSource().loadGeneratedPuzzle();
```

- [ ] **Step 7: Move the core tests**

```bash
mkdir -p packages/crossword_core/test/gameplay/data/entities/dto
mkdir -p packages/crossword_core/test/gameplay/domain/entities
git mv test/gameplay/data/entities/dto/puzzle_dto_test.dart packages/crossword_core/test/gameplay/data/entities/dto/
git mv test/gameplay/data/local_puzzle_data_source_test.dart packages/crossword_core/test/gameplay/data/
git mv test/gameplay/data/puzzle_resolver_test.dart packages/crossword_core/test/gameplay/data/
git mv test/gameplay/domain/entities/crossword_puzzle_test.dart packages/crossword_core/test/gameplay/domain/entities/
```

- [ ] **Step 8: Rewrite test imports**

In each moved test file, replace any `import 'package:crosswords/...';` with `import 'package:crossword_core/crossword_core.dart';`. Also replace relative imports that reached into `lib/` (e.g. `import '../../../../lib/...';`) with the same barrel import.

In `local_puzzle_data_source_test.dart`, if it asserts on the asset path string, update the expected path to `packages/crossword_core/assets/puzzles/generated_crossword.json`.

- [ ] **Step 9: Resolve and test the package**

Run: `cd packages/crossword_core && flutter pub get && flutter analyze && flutter test`
Expected: analyze clean; all moved tests PASS (DTO parsing, resolver word-paths, data-source asset load, puzzle model).

- [ ] **Step 10: Commit**

```bash
git add packages/crossword_core
git commit -m "feat: extract crossword_core package (model + JSON pipeline)"
```

---

## Task 2: Create `crossword_ui` package

**Files:**
- Create: `packages/crossword_ui/pubspec.yaml`, `analysis_options.yaml`, `lib/crossword_ui.dart`
- Create: `packages/crossword_ui/lib/gameplay/presentation/crossword_screen/crossword_player.dart`
- Move: `lib/common/data/constants/*.dart` → `packages/crossword_ui/lib/common/data/constants/`
- Move: `lib/settings/domain/entities/app_font.dart`, `lib/settings/domain/services/font_service.dart` → `packages/crossword_ui/lib/settings/domain/...`
- Move: `lib/gameplay/presentation/crossword_screen/cubit/*.dart` and `widgets/*.dart` → mirror path under `crossword_ui`
- Move tests → `packages/crossword_ui/test/`: `app_text_styles_test.dart`, `app_font_test.dart`, `font_service_test.dart`, `crossword_cubit_test.dart`, `mobile_input_present_test.dart`, `mobile_input_absent_test.dart`

- [ ] **Step 1: Create the package pubspec**

`packages/crossword_ui/pubspec.yaml`:

```yaml
name: crossword_ui
description: Shared crossword play engine — grid widgets, cubit, theme, CrosswordPlayer.
publish_to: 'none'
version: 0.0.1

environment:
  sdk: ^3.11.5

dependencies:
  flutter:
    sdk: flutter
  flutter_bloc: ^9.1.1
  equatable: ^2.0.7
  google_fonts: ^6.2.1
  shared_preferences: ^2.5.3
  crossword_core:
    path: ../crossword_core

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0

flutter:
  uses-material-design: true
```

- [ ] **Step 2: Inherit shared lints**

`packages/crossword_ui/analysis_options.yaml`:

```yaml
include: ../../analysis_options.yaml
```

- [ ] **Step 3: Move constants, font service, cubit, and widgets**

```bash
mkdir -p packages/crossword_ui/lib/common/data/constants
mkdir -p packages/crossword_ui/lib/settings/domain/entities
mkdir -p packages/crossword_ui/lib/settings/domain/services
mkdir -p packages/crossword_ui/lib/gameplay/presentation/crossword_screen/cubit
mkdir -p packages/crossword_ui/lib/gameplay/presentation/crossword_screen/widgets
git mv lib/common/data/constants/*.dart packages/crossword_ui/lib/common/data/constants/
git mv lib/settings/domain/entities/app_font.dart packages/crossword_ui/lib/settings/domain/entities/
git mv lib/settings/domain/services/font_service.dart packages/crossword_ui/lib/settings/domain/services/
git mv lib/gameplay/presentation/crossword_screen/cubit/*.dart packages/crossword_ui/lib/gameplay/presentation/crossword_screen/cubit/
git mv lib/gameplay/presentation/crossword_screen/widgets/*.dart packages/crossword_ui/lib/gameplay/presentation/crossword_screen/widgets/
```

- [ ] **Step 4: Fix cross-package imports in moved UI files**

In every moved file under `crossword_ui` (cubit, state, widgets), replace relative imports that reached crossword entities/DTOs/resolver — e.g. `import '../../../domain/entities/crossword_puzzle.dart';`, `import '../../../../gameplay/domain/entities/...';` — with:

```dart
import 'package:crossword_core/crossword_core.dart';
```

Imports that stay **within** `crossword_ui` (e.g. a widget importing `app_colors.dart`, the cubit importing `font_service.dart`) keep working via their preserved relative paths. Verify each file compiles in Step 9 before assuming.

- [ ] **Step 5: Extract `CrosswordPlayer` from the old screen**

Create `packages/crossword_ui/lib/gameplay/presentation/crossword_screen/crossword_player.dart`. This is the **body** of the old `CrosswordScreenContent` — the `Stack` with the `Focus`/`LayoutBuilder`/`InteractiveViewer`/`CrosswordGrid` and the hidden mobile `TextField` — with the `Scaffold`/`AppBar` removed. It reads the cubit from context (the app provides the `BlocProvider`):

```dart
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../common/data/constants/app_colors.dart';
import 'cubit/crossword_cubit.dart';
import 'cubit/crossword_state.dart';
import 'widgets/crossword_grid.dart';

/// The reusable crossword play surface. Embed inside any [Scaffold]. Expects a
/// [CrosswordCubit] provided above it in the tree so host app bars can drive it
/// (e.g. `cubit.resetView`).
class CrosswordPlayer extends StatelessWidget {
  const CrosswordPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CrosswordCubit, CrosswordState>(
      builder: (context, state) => _CrosswordPlayerBody(state: state),
    );
  }
}

class _CrosswordPlayerBody extends StatelessWidget {
  final CrosswordState state;

  const _CrosswordPlayerBody({required this.state});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CrosswordCubit>();
    return Stack(
      children: [
        Focus(
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
            switch (event.logicalKey) {
              case LogicalKeyboardKey.arrowUp:
                cubit.moveSelection(-1, 0);
                return KeyEventResult.handled;
              case LogicalKeyboardKey.arrowDown:
                cubit.moveSelection(1, 0);
                return KeyEventResult.handled;
              case LogicalKeyboardKey.arrowLeft:
                cubit.moveSelection(0, -1);
                return KeyEventResult.handled;
              case LogicalKeyboardKey.arrowRight:
                cubit.moveSelection(0, 1);
                return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                const gridPadding = 16.0;
                final viewportWidth = constraints.maxWidth - gridPadding * 2;
                final viewportHeight = constraints.maxHeight - gridPadding * 2;
                final cellSizeByWidth =
                    (viewportWidth - CrosswordGrid.borderWidth * 2) /
                        state.puzzle.cols;
                final cellSizeByHeight =
                    (viewportHeight - CrosswordGrid.borderWidth * 2) /
                        state.puzzle.rows;
                final cellSize = min(cellSizeByWidth, cellSizeByHeight);

                return InteractiveViewer(
                  transformationController: cubit.transformationController,
                  minScale: 1.0,
                  maxScale: 4.0,
                  constrained: false,
                  boundaryMargin: EdgeInsets.zero,
                  child: SizedBox(
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    child: Align(
                      child: Padding(
                        padding: const EdgeInsets.all(gridPadding),
                        child: CrosswordGrid(state: state, cellSize: cellSize),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        if (cubit.isTouchPlatform)
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: 0,
                child: TextField(
                  key: const Key('mobileTextInput'),
                  controller: cubit.inputController,
                  focusNode: cubit.keyboardFocusNode,
                  autocorrect: false,
                  enableSuggestions: false,
                  keyboardType: TextInputType.text,
                  textCapitalization: TextCapitalization.characters,
                  showCursor: false,
                  onChanged: cubit.onInputChanged,
                  decoration: const InputDecoration(border: InputBorder.none),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
```

Note: `AppColors` is no longer referenced inside the body (the old `Scaffold(backgroundColor: AppColors.background)` lives in each app now). Leave the `app_colors.dart` import out of this file; the unused-import lint would otherwise fire.

- [ ] **Step 6: Delete the old screen file**

The old `lib/gameplay/presentation/crossword_screen/crossword_screen.dart` is replaced by `CrosswordPlayer` (engine body) + per-app screens. Remove it:

```bash
git rm lib/gameplay/presentation/crossword_screen/crossword_screen.dart
```

- [ ] **Step 7: Add the public barrel**

`packages/crossword_ui/lib/crossword_ui.dart`:

```dart
export 'common/data/constants/app_colors.dart';
export 'common/data/constants/app_text_styles.dart';
export 'common/data/constants/strings.dart';
export 'settings/domain/entities/app_font.dart';
export 'settings/domain/services/font_service.dart';
export 'gameplay/presentation/crossword_screen/crossword_player.dart';
export 'gameplay/presentation/crossword_screen/cubit/crossword_cubit.dart';
export 'gameplay/presentation/crossword_screen/cubit/crossword_state.dart';
export 'gameplay/presentation/crossword_screen/widgets/crossword_grid.dart';
```

- [ ] **Step 8: Move and rewrite the UI tests**

```bash
mkdir -p packages/crossword_ui/test/common/data/constants
mkdir -p packages/crossword_ui/test/settings/domain/entities
mkdir -p packages/crossword_ui/test/settings/domain/services
mkdir -p packages/crossword_ui/test/gameplay/presentation/crossword_screen/cubit
git mv test/common/data/constants/app_text_styles_test.dart packages/crossword_ui/test/common/data/constants/
git mv test/settings/domain/entities/app_font_test.dart packages/crossword_ui/test/settings/domain/entities/
git mv test/settings/domain/services/font_service_test.dart packages/crossword_ui/test/settings/domain/services/
git mv test/gameplay/presentation/crossword_screen/cubit/crossword_cubit_test.dart packages/crossword_ui/test/gameplay/presentation/crossword_screen/cubit/
git mv test/gameplay/presentation/crossword_screen/mobile_input_present_test.dart packages/crossword_ui/test/gameplay/presentation/crossword_screen/
git mv test/gameplay/presentation/crossword_screen/mobile_input_absent_test.dart packages/crossword_ui/test/gameplay/presentation/crossword_screen/
```

In each, replace `import 'package:crosswords/...';` with the appropriate package barrel (`package:crossword_core/crossword_core.dart` for entities, `package:crossword_ui/crossword_ui.dart` for cubit/state/widgets/constants/font).

- [ ] **Step 9: Re-point the mobile-input tests at `CrosswordPlayer`**

The two `mobile_input_*` tests previously pumped `CrosswordScreen`. Update them to pump `CrosswordPlayer` wrapped in a minimal harness, since the hidden `TextField` now lives there. Replace the widget-under-test with:

```dart
await tester.pumpWidget(
  MaterialApp(
    home: RepositoryProvider<FontService>.value(
      value: fontService,
      child: BlocProvider(
        create: (context) => CrosswordCubit(
          puzzle: puzzle,
          fontService: fontService,
        ),
        child: const Scaffold(body: CrosswordPlayer()),
      ),
    ),
  ),
);
```

Keep each test's existing `debugDefaultTargetPlatformOverride` setup/teardown and its assertion that `find.byKey(const Key('mobileTextInput'))` is present (touch platform) or absent (desktop). Pull `fontService`/`puzzle` from the test's existing fixtures.

- [ ] **Step 10: Resolve, analyze, test**

Run: `cd packages/crossword_ui && flutter pub get && flutter analyze && flutter test`
Expected: analyze clean; PASS for text-styles, app-font, font-service, cubit navigation/input, and both mobile-input presence tests.

- [ ] **Step 11: Commit**

```bash
git add packages/crossword_ui
git commit -m "feat: extract crossword_ui package with reusable CrosswordPlayer"
```

---

## Task 3: Create `apps/mobile`

**Files:**
- Create: `apps/mobile/pubspec.yaml`, `analysis_options.yaml`, `lib/main.dart`, `lib/crossword/mobile_crossword_screen.dart`
- Move: `android/`, `ios/` → `apps/mobile/`
- Move: root `web/` is handled in Task 4 (mobile has no web target)
- Move: `lib/settings/presentation/...` → `apps/mobile/lib/settings/presentation/...`
- Move tests → `apps/mobile/test/`: `settings_cubit_test.dart`, `settings_screen_test.dart`, plus a new `mobile_crossword_screen_test.dart`. The old `crossword_screen_test.dart` is superseded (see Step 8).

- [ ] **Step 1: Create the app pubspec**

`apps/mobile/pubspec.yaml`:

```yaml
name: crosswords
description: Crosswords — Swedish korsord game (mobile).
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: ^3.11.5

dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  flutter_bloc: ^9.1.1
  shared_preferences: ^2.5.3
  crossword_core:
    path: ../../packages/crossword_core
  crossword_ui:
    path: ../../packages/crossword_ui

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0

flutter:
  uses-material-design: true
```

- [ ] **Step 2: Inherit shared lints**

`apps/mobile/analysis_options.yaml`:

```yaml
include: ../../analysis_options.yaml
```

- [ ] **Step 3: Move the native projects and the settings UI**

```bash
mkdir -p apps/mobile/lib/settings
git mv android apps/mobile/android
git mv ios apps/mobile/ios
git mv lib/settings/presentation apps/mobile/lib/settings/presentation
```

- [ ] **Step 4: Rewrite imports in the moved settings screen**

In `apps/mobile/lib/settings/presentation/...` files, replace `package:crosswords/...` and any relative reaches into the old `lib/` with package barrels:
- `AppColors`, `AppTextStyles`, `Strings`, `AppFont`, `FontService` → `package:crossword_ui/crossword_ui.dart`

- [ ] **Step 5: Build the mobile crossword screen (chrome around `CrosswordPlayer`)**

`apps/mobile/lib/crossword/mobile_crossword_screen.dart` — recreates the old `Scaffold`/`AppBar` (settings nav + reset), owns the `BlocProvider`, embeds `CrosswordPlayer`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:crossword_core/crossword_core.dart';
import 'package:crossword_ui/crossword_ui.dart';

import '../settings/presentation/settings_screen/settings_screen.dart';

class MobileCrosswordScreen extends StatelessWidget {
  final CrosswordPuzzle puzzle;

  const MobileCrosswordScreen({required this.puzzle, super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => CrosswordCubit(
        puzzle: puzzle,
        fontService: context.read<FontService>(),
      ),
      child: const _MobileCrosswordView(),
    );
  }
}

class _MobileCrosswordView extends StatelessWidget {
  const _MobileCrosswordView();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CrosswordCubit>();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(Strings.appTitle, style: AppTextStyles.appBarTitle()),
        centerTitle: true,
        backgroundColor: AppColors.brand,
        foregroundColor: AppColors.onBrand,
        elevation: 0,
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
      ),
      body: const CrosswordPlayer(),
    );
  }
}
```

- [ ] **Step 6: Write the mobile entry point**

`apps/mobile/lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crossword_core/crossword_core.dart';
import 'package:crossword_ui/crossword_ui.dart';

import 'crossword/mobile_crossword_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final fontService = FontService(prefs: prefs);
  final puzzle = await loadBundledPuzzle();
  runApp(CrosswordsApp(fontService: fontService, puzzle: puzzle));
}

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
        home: MobileCrosswordScreen(puzzle: puzzle),
      ),
    );
  }
}
```

- [ ] **Step 7: Move the settings tests**

```bash
mkdir -p apps/mobile/test/settings/presentation/settings_screen/cubit
git mv test/settings/presentation/settings_screen/cubit/settings_cubit_test.dart apps/mobile/test/settings/presentation/settings_screen/cubit/
git mv test/settings/presentation/settings_screen/settings_screen_test.dart apps/mobile/test/settings/presentation/settings_screen/
```

In both, replace `package:crosswords/settings/...` imports with `package:crosswords/settings/presentation/...` (same app package name `crosswords`, new path) and `package:crosswords/...` for shared symbols with `package:crossword_ui/crossword_ui.dart`.

- [ ] **Step 8: Replace the old screen test with a mobile-screen test**

The old `test/gameplay/presentation/crossword_screen/crossword_screen_test.dart` tested `CrosswordScreen` (now split). Its grid/input coverage moved to `crossword_ui` in Task 2. Re-home its **chrome** coverage (settings icon → navigates to `SettingsScreen`, reset icon present) as a new mobile test.

```bash
git rm test/gameplay/presentation/crossword_screen/crossword_screen_test.dart
mkdir -p apps/mobile/test/crossword
```

`apps/mobile/test/crossword/mobile_crossword_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crossword_core/crossword_core.dart';
import 'package:crossword_ui/crossword_ui.dart';
import 'package:crosswords/crossword/mobile_crossword_screen.dart';

void main() {
  late FontService fontService;
  late CrosswordPuzzle puzzle;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    fontService = FontService(prefs: prefs);
    puzzle = await loadBundledPuzzle();
  });

  Widget harness() => RepositoryProvider<FontService>.value(
        value: fontService,
        child: MaterialApp(home: MobileCrosswordScreen(puzzle: puzzle)),
      );

  testWidgets('renders the play surface with app-bar actions', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.byType(CrosswordPlayer), findsOneWidget);
    expect(find.byIcon(Icons.settings), findsOneWidget);
    expect(find.byIcon(Icons.fit_screen), findsOneWidget);
  });

  testWidgets('settings action opens the settings screen', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsOneWidget);
  });
}
```

If `loadBundledPuzzle()` cannot read the package asset under `flutter test` from the app, fall back to constructing a small in-memory `CrosswordPuzzle` fixture (the resolver/data-source already have their own coverage in `crossword_core`); the point of this test is the chrome, not asset loading.

- [ ] **Step 9: Resolve, analyze, test the mobile app**

Run: `cd apps/mobile && flutter pub get && flutter analyze && flutter test`
Expected: analyze clean; settings tests + mobile-screen tests PASS.

- [ ] **Step 10: Verify a real mobile build**

Run: `cd apps/mobile && flutter build apk --debug` (or `flutter build ios --debug --no-codesign`)
Expected: build succeeds, confirming the moved `android/`/`ios/` projects resolve against the new package layout.

- [ ] **Step 11: Commit**

```bash
git add apps/mobile
git commit -m "feat: create apps/mobile embedding shared CrosswordPlayer"
```

---

## Task 4: Create `apps/web`

**Files:**
- Create: `apps/web/pubspec.yaml`, `analysis_options.yaml`, `lib/main.dart`, `lib/crossword/web_crossword_screen.dart`, `test/web_smoke_test.dart`
- Move: root `web/` → `apps/web/web/`

- [ ] **Step 1: Create the app pubspec**

`apps/web/pubspec.yaml`:

```yaml
name: crosswords_web
description: Crosswords — lean in-browser puzzle player.
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: ^3.11.5

dependencies:
  flutter:
    sdk: flutter
  flutter_bloc: ^9.1.1
  shared_preferences: ^2.5.3
  crossword_core:
    path: ../../packages/crossword_core
  crossword_ui:
    path: ../../packages/crossword_ui

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0

flutter:
  uses-material-design: true
```

- [ ] **Step 2: Inherit shared lints**

`apps/web/analysis_options.yaml`:

```yaml
include: ../../analysis_options.yaml
```

- [ ] **Step 3: Move the web platform folder**

```bash
git mv web apps/web/web
```

- [ ] **Step 4: Build the lean web screen**

`apps/web/lib/crossword/web_crossword_screen.dart` — a minimal browser shell: own `BlocProvider`, slim app bar with just a reset action, `CrosswordPlayer` body. No settings/accounts.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:crossword_core/crossword_core.dart';
import 'package:crossword_ui/crossword_ui.dart';

class WebCrosswordScreen extends StatelessWidget {
  final CrosswordPuzzle puzzle;

  const WebCrosswordScreen({required this.puzzle, super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => CrosswordCubit(
        puzzle: puzzle,
        fontService: context.read<FontService>(),
      ),
      child: const _WebCrosswordView(),
    );
  }
}

class _WebCrosswordView extends StatelessWidget {
  const _WebCrosswordView();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CrosswordCubit>();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(Strings.appTitle, style: AppTextStyles.appBarTitle()),
        centerTitle: true,
        backgroundColor: AppColors.brand,
        foregroundColor: AppColors.onBrand,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.fit_screen),
            tooltip: Strings.resetViewTooltip,
            onPressed: cubit.resetView,
          ),
        ],
      ),
      // Constrain width so the grid stays readable on wide desktop viewports.
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: const CrosswordPlayer(),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Write the web entry point**

`apps/web/lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crossword_core/crossword_core.dart';
import 'package:crossword_ui/crossword_ui.dart';

import 'crossword/web_crossword_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final fontService = FontService(prefs: prefs);
  final puzzle = await loadBundledPuzzle();
  runApp(CrosswordsWebApp(fontService: fontService, puzzle: puzzle));
}

class CrosswordsWebApp extends StatelessWidget {
  final FontService fontService;
  final CrosswordPuzzle puzzle;

  const CrosswordsWebApp({
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
        home: WebCrosswordScreen(puzzle: puzzle),
      ),
    );
  }
}
```

- [ ] **Step 6: Write a web smoke test**

`apps/web/test/web_smoke_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crossword_core/crossword_core.dart';
import 'package:crossword_ui/crossword_ui.dart';
import 'package:crosswords_web/crossword/web_crossword_screen.dart';

void main() {
  testWidgets('web screen renders the shared player', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final fontService = FontService(prefs: prefs);
    final puzzle = await loadBundledPuzzle();

    await tester.pumpWidget(
      RepositoryProvider<FontService>.value(
        value: fontService,
        child: MaterialApp(home: WebCrosswordScreen(puzzle: puzzle)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CrosswordPlayer), findsOneWidget);
    expect(find.byIcon(Icons.fit_screen), findsOneWidget);
  });
}
```

If `loadBundledPuzzle()` does not resolve the cross-package asset under `flutter test`, substitute a small in-memory `CrosswordPuzzle` fixture as in Task 3 Step 8.

- [ ] **Step 7: Resolve, analyze, test**

Run: `cd apps/web && flutter pub get && flutter analyze && flutter test`
Expected: analyze clean; smoke test PASS.

- [ ] **Step 8: Verify a real web build**

Run: `cd apps/web && flutter build web`
Expected: build succeeds; output at `apps/web/build/web`.

- [ ] **Step 9: Commit**

```bash
git add apps/web
git commit -m "feat: create apps/web lean player embedding CrosswordPlayer"
```

---

## Task 5: Convert to a pub workspace and clean up

**Files:**
- Rewrite: root `pubspec.yaml` → workspace declaration
- Modify: each member pubspec — add `resolution: workspace`
- Modify: `firebase.json` (hosting `public` → `apps/web/build/web`)
- Delete: leftover root `lib/`, `test/`, old root `pubspec.lock`, stale root native references
- Modify: `.gitignore` if it referenced root `build/`

- [ ] **Step 1: Replace the root pubspec with a workspace root**

Overwrite `pubspec.yaml`:

```yaml
name: crosswords_workspace
description: Crosswords monorepo — mobile + web apps over shared packages.
publish_to: 'none'

environment:
  sdk: ^3.11.5

workspace:
  - apps/mobile
  - apps/web
  - packages/crossword_core
  - packages/crossword_ui

dev_dependencies:
  flutter_lints: ^6.0.0
```

- [ ] **Step 2: Mark each member as a workspace member**

Add the line `resolution: workspace` to each of the four member pubspecs (`apps/mobile`, `apps/web`, `packages/crossword_core`, `packages/crossword_ui`), directly under their `environment:` block. Example for `packages/crossword_core/pubspec.yaml`:

```yaml
environment:
  sdk: ^3.11.5

resolution: workspace
```

Path dependencies between members stay as written — workspace resolution unifies the third-party lockfile, path deps still wire local packages.

- [ ] **Step 3: Remove the now-empty leftovers from the old root app**

```bash
git rm -r --ignore-unmatch lib test
git rm --ignore-unmatch pubspec.lock crosswords.iml
rm -rf .dart_tool build
```

(`lib/main.dart` and any remaining root `lib/` files were superseded by the per-app entry points; the root `test/` is empty after Tasks 1–3 moved every file out. If `git rm` reports remaining tracked files under `lib/`/`test/`, investigate — something was not migrated.)

- [ ] **Step 4: Point Firebase Hosting at the web build output**

In `firebase.json`, set the hosting `public` directory to the web app's build output:

```json
{
  "hosting": {
    "public": "apps/web/build/web",
    "ignore": ["firebase.json", "**/.*", "**/node_modules/**"]
  }
}
```

(Preserve any other keys already present in `firebase.json`; only the `public` path changes.)

- [ ] **Step 5: Resolve the whole workspace from the root**

Run: `flutter pub get`
Expected: a single resolution covering all four members; one `pubspec.lock` at the root. No version conflicts.

- [ ] **Step 6: Analyze and test every member from the root**

Run: `flutter analyze`
Expected: clean across all members.

Run: `flutter test packages/crossword_core packages/crossword_ui apps/mobile apps/web`
Expected: every moved + new test PASS.

- [ ] **Step 7: Verify both apps still build**

Run: `cd apps/mobile && flutter build apk --debug`
Run: `cd apps/web && flutter build web`
Expected: both succeed.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "feat: convert repo to pub workspace; wire web hosting output"
```

---

## Self-Review

**Spec coverage:**
- Pub workspace, no Melos → Task 5. ✓
- `apps/mobile`, `apps/web`, `packages/crossword_core`, `packages/crossword_ui` layout → Tasks 1–4. ✓
- One-way deps `apps → crossword_ui → crossword_core` → enforced by pubspec deps in Tasks 1–4. ✓
- `crossword_core` = entities + DTOs + resolver + data source + asset + `loadBundledPuzzle()`, no widgets → Task 1. ✓
- Package-prefixed asset key → Task 1 Step 4. ✓
- `crossword_ui` = grid widgets + cubit + `AppColors`/`Strings`/`AppTextStyles`/`AppFont`/`FontService` + `CrosswordPlayer` (no Scaffold) → Task 2. ✓
- Reuse seam: both apps embed `CrosswordPlayer`, own their `BlocProvider`/Scaffold → Tasks 3 & 4. ✓
- Mobile owns native projects + settings screen; web is lean → Tasks 3 & 4. ✓
- One asset, shared theme/strings → Tasks 1 & 2. ✓
- Per-member `analysis_options.yaml` `include` → every task. ✓
- Tests follow code; existing suite as safety net → every task. ✓
- Risk: Firebase hosting path → Task 5 Step 4. ✓
- Risk: native tooling paths after move → Task 3 Step 10 build verification. ✓

**Placeholder scan:** No TBD/TODO; all new files shown in full; all import edits specified.

**Type consistency:** `CrosswordCubit(puzzle:, fontService:)`, `FontService(prefs:)`, `loadBundledPuzzle()`, `CrosswordPlayer()`, `CrosswordGrid(state:, cellSize:)`, `CrosswordGrid.borderWidth`, and the cubit methods (`resetView`, `onLetterInput`, `onBackspace`, `moveSelection`, `onInputChanged`, `focusNode`, `keyboardFocusNode`, `inputController`, `transformationController`, `isTouchPlatform`) match the existing source carried through the move. App package name `crosswords` (mobile) and `crosswords_web` (web) used consistently in test imports.
