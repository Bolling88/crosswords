# Flutter Monorepo: Web + Mobile with Shared Core

**Date:** 2026-06-11
**Status:** Approved design, pending implementation plan

## Goal

Restructure the single-app Crosswords repository into a monorepo where a **mobile app** (full game: home, accounts, subscriptions) and a **web app** (lean in-browser puzzle player, mouse/keyboard tuned) live side by side and **reuse the same gameplay engine** while keeping their own navigation, chrome, and platform features.

The two apps are genuinely separate (own entry points, own dependencies, own navigation) but share a common core and a common play engine. The web app must never compile mobile-only plugins, and vice versa.

## Approach

Native Dart **pub workspace** (`resolution: workspace`) — no Melos. One lockfile, shared dependency resolution, true per-package isolation. Apps and shared packages are workspace members.

Dependency direction is strictly one-way, no cycles, no app-to-app dependency:

```
apps/mobile ─┐
             ├─→ crossword_ui ─→ crossword_core
apps/web ────┘
```

## Repository Layout

```
crosswords/
├── pubspec.yaml                  # workspace root: members list + shared dev deps
├── analysis_options.yaml         # single lint config (existing rules preserved)
├── apps/
│   ├── mobile/
│   │   ├── lib/main.dart         # full game shell + navigation
│   │   ├── android/  ios/        # moved from repo root
│   │   ├── test/
│   │   └── pubspec.yaml          # resolution: workspace
│   └── web/
│       ├── lib/main.dart         # lean player shell
│       ├── web/                  # moved from repo root (index.html, icons, manifest)
│       ├── test/
│       └── pubspec.yaml          # resolution: workspace
└── packages/
    ├── crossword_core/
    │   ├── lib/                  # entities, DTOs, PuzzleResolver, LocalPuzzleDataSource
    │   ├── assets/puzzles/generated_crossword.json
    │   └── pubspec.yaml
    └── crossword_ui/
        ├── lib/                  # grid/cell/hint widgets, CrosswordCubit + state,
        │                         # CrosswordPlayer, AppColors, Strings, FontService
        └── pubspec.yaml
```

## Package Responsibilities

### `crossword_core` — puzzle model + JSON pipeline

A Flutter package (depends on `flutter` because it loads a bundled asset via `rootBundle`). Contains **no widgets**.

- Domain entities (current `lib/gameplay/domain/entities/`): `Cell` hierarchy, `Word`, `CrosswordPuzzle`, `Direction`, arrow shapes/clue arrows.
- Data-layer DTOs (current `lib/gameplay/data/entities/dto/`): position, grid-cell, grid, puzzle.
- `PuzzleResolver` (DTO → domain, resolves word cell paths).
- `LocalPuzzleDataSource` — loads the bundled JSON.
- The bundled puzzle asset `assets/puzzles/generated_crossword.json`, declared in this package's pubspec.
- Public entry: `loadBundledPuzzle()` returning the resolved `CrosswordPuzzle`.

**Dependencies:** `flutter`, `equatable`.

**Asset key:** because the asset ships inside a package, the data source loads it via the package-prefixed key `packages/crossword_core/assets/puzzles/generated_crossword.json`. This is the single change required to the existing data-source loading code.

### `crossword_ui` — the playable engine as reusable widgets

Depends on `crossword_core`. Holds everything needed to render and play a puzzle, exposed through one reuse seam.

- Grid + cell + hint widgets (current `lib/gameplay/presentation/crossword_screen/widgets/`).
- `CrosswordCubit` + `CrosswordState` (current cubit), shared verbatim by both apps.
- **`CrosswordPlayer`** — the reuse seam: a composable widget (**not** a full `Scaffold`) that, given a `CrosswordPuzzle`, provides the `CrosswordCubit` and renders the interactive grid. Apps embed it inside their own Scaffold/navigation.
- Shared presentation constants/services: `AppColors`, `Strings`, `FontService` (font-size preference affecting grid rendering).

**Dependencies:** `crossword_core`, `flutter`, `flutter_bloc`, `google_fonts`, `equatable`.

**Note on `FontService`:** it uses `shared_preferences`, which works on web. It lives here because the grid depends on it. App-specific *settings screens* live in each app and mutate this shared service.

### `apps/mobile` — full game

Owns the existing platform projects (`android/`, `ios/`), app navigation, the home/settings screens, and (later) accounts + subscriptions. Bootstraps by calling `loadBundledPuzzle()` and embedding `CrosswordPlayer` in its own Scaffold.

**Dependencies:** `crossword_core`, `crossword_ui`, `shared_preferences`, plus future mobile-only plugins (RevenueCat, Firebase). These never reach web.

### `apps/web` — lean player

Owns the `web/` platform folder. A minimal browser-friendly shell: load a puzzle, drop `CrosswordPlayer` into a lean Scaffold tuned for mouse + physical keyboard. No accounts/subscriptions.

**Dependencies:** `crossword_core`, `crossword_ui`, plus any web-only deps.

## Reuse Model

The entire grid-rendering and interaction engine (widgets + `CrosswordCubit`) is shared through `CrosswordPlayer`. Each app differs only in:

- its **shell** (Scaffold, app bar, navigation),
- its **bootstrap** (what it loads and when),
- its **platform features** (mobile: soft keyboard, accounts, subs; web: mouse/keyboard tuning),

while playing identical puzzles through identical engine code. This is how the apps "work differently but reuse the same components."

## Assets, Theme, Strings

- Puzzle JSON lives once in `crossword_core/assets/`; both apps consume it via the package asset key. No per-app duplication.
- `AppColors`, `Strings`, `FontService` live once in `crossword_ui`; shared widgets and both apps reference one source.

## Tooling

- Root `analysis_options.yaml` carries the existing lint rules; each member has a one-line `analysis_options.yaml` with `include: ../../analysis_options.yaml`.
- Tests live per package/app under their own `test/`. Existing gameplay tests follow their code into `crossword_core` / `crossword_ui`.
- `dart pub get` at the workspace root resolves all members together. `flutter run` is executed inside `apps/mobile` or `apps/web`.

## Migration Order (each step compiles)

1. Create the workspace root pubspec + four empty package/app skeletons.
2. Move `gameplay` domain + data (DTOs, resolver, data source, JSON asset) into `crossword_core`; fix imports and switch the asset key to the package-prefixed form.
3. Move grid widgets + `CrosswordCubit` + `AppColors`/`Strings`/`FontService` into `crossword_ui`; extract `CrosswordPlayer`.
4. Move the existing app (`android/`, `ios/`, remaining `lib/`, `settings`) into `apps/mobile`; rewire `main.dart` to embed `CrosswordPlayer`.
5. Scaffold `apps/web` with a lean shell embedding `CrosswordPlayer`; move `web/` into it.
6. Delete the now-empty root `lib/`, `android/`, `ios/`, `web/`. Verify `analyze` + `test` + run both apps.

## Out of Scope

- Accounts, subscriptions, and Firebase wiring for either app (mobile feature work, tracked separately).
- Web-specific puzzle selection / routing beyond a single loaded puzzle.
- CI pipeline changes (can follow once the structure lands).

## Open Risks

- **Firebase hosting config** (`firebase.json`, `.firebaserc`) currently assumes web build output at repo root; it will need to point at `apps/web/build/web` after the move. Noted for the plan, not blocking the structure.
- **iOS/Android tooling paths** (`.metadata`, `*.iml`, `Podfile`) reference the root project; moving `android/`/`ios/` under `apps/mobile/` requires updating these. The plan must verify a clean mobile build after the move.
