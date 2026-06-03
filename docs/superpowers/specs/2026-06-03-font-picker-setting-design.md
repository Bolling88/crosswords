# Font Picker Setting — Design

**Date:** 2026-06-03
**Status:** Approved (pending spec review)

## Goal

Let the player choose the handwritten font used for the crossword. A new
Settings screen presents a list of handwritten fonts, each rendered **in its own
font** so the player sees the look before choosing. The selection applies to the
**entered answer letters and the clue text**, and is **remembered between app
launches**.

## Decisions (from brainstorming)

- **Scope:** the chosen font changes both the typed answer letters and the clue
  text inside hint cells. App-bar title and image-clue labels are unaffected.
- **Access:** a gear icon in the crossword app bar opens a dedicated Settings
  screen; the font picker is its first (currently only) item.
- **Fonts offered:** 9 handwritten Google Fonts (below). Default: Patrick Hand
  (the current look).
- **Persistence:** stored locally via `shared_preferences`; survives restarts.

### Font list

| `AppFont` value      | Google family         | Notes            |
|----------------------|-----------------------|------------------|
| `patrickHand`        | Patrick Hand          | Default, current |
| `caveat`             | Caveat                |                  |
| `indieFlower`        | Indie Flower          |                  |
| `shadowsIntoLight`   | Shadows Into Light    |                  |
| `kalam`              | Kalam                 |                  |
| `architectsDaughter` | Architects Daughter   |                  |
| `comingSoon`         | Coming Soon           |                  |
| `gloriaHallelujah`   | Gloria Hallelujah     |                  |
| `justAnotherHand`    | Just Another Hand     |                  |

## Architecture

Font choice is cross-feature shared state (set in Settings, consumed in
gameplay), so it lives in a **service with a `ValueNotifier`**, per project
convention. Only cubits touch the service.

```
SettingsScreen ─(SettingsCubit)─┐
                                ├─▶ FontService (ValueNotifier<AppFont>) ──▶ shared_preferences
CrosswordScreen ─(CrosswordCubit)┘            │
                                              └─ CrosswordCubit listens, puts font into CrosswordState
                                                 → AnswerCellWidget / HintCellWidget render with it
```

### Components

**`AppFont` (enum)** — `lib/settings/domain/entities/app_font.dart`
- 9 values, each exposing `displayName` and `googleFamily` (String).
- `static const AppFont defaultFont = AppFont.patrickHand;`
- Serialization by enum `name` for storage.

**`FontService`** — `lib/settings/domain/services/font_service.dart`
- `final ValueNotifier<AppFont> selectedFont;`
- Constructed with an initial value (loaded before `runApp`).
- `Future<void> selectFont(AppFont font)` — updates the notifier and persists.
- A small static loader reads `shared_preferences` and resolves the stored
  enum name (falling back to `defaultFont` when missing/invalid).

**DI** — `lib/main.dart`
- `main()` becomes async: `WidgetsFlutterBinding.ensureInitialized()`, load the
  stored font, construct `FontService`, wrap `MaterialApp` in
  `RepositoryProvider<FontService>`. This is the app's first DI wiring.

**Settings feature** — `lib/settings/presentation/settings_screen/`
- `settings_screen.dart`: `SettingsScreen` (BlocProvider) → `SettingsScreenBuilder`
  (BlocConsumer) → `SettingsScreenContent` (UI), following the required
  three-widget structure.
- `cubit/settings_cubit.dart` + `cubit/settings_state.dart`:
  - State holds `List<AppFont> fonts` and `AppFont selectedFont`.
  - `selectFont(AppFont)` calls `FontService.selectFont` and emits new state.
- Font picker UI: a scrollable list; each row renders the font's name + a grid
  sample (`ABCÅÄÖ`) + a clue sample, all in that font, with a trailing checkmark
  on the selected one. Rows are `InkWell` in `Material` (per convention).

**Gameplay wiring**
- `CrosswordCubit` takes `FontService` via constructor, reads its current value,
  subscribes to the notifier, and removes the listener in `close()`.
- `CrosswordState` gains `AppFont font` (default `AppFont.defaultFont`); the
  cubit emits an updated state whenever the service changes.
- `AnswerCellWidget` and `HintCellWidget` receive the font (threaded through
  `CrosswordGrid` from state) and render via `AppTextStyles`.
- `AppTextStyles.answerLetter` and `AppTextStyles.clue` gain an optional
  `String? family` parameter; when provided they use
  `GoogleFonts.getFont(family, …)`, otherwise they keep current defaults so no
  other call site changes behavior.

## Strings

User-facing strings added to `Strings` (Swedish):
- Settings screen title (e.g. `Inställningar`).
- Font setting label/section (e.g. `Typsnitt`).
- App-bar settings tooltip/semantics label.

## Data flow

`Settings tap → SettingsCubit.selectFont → FontService.selectFont (notify +
persist) → CrosswordCubit listener → emit CrosswordState(font) → grid + clue
cells rebuild.`

The font is loaded before the first frame, so the initial render already uses the
stored choice.

## Error handling

- Loading: missing/corrupt/unknown stored value → fall back to `defaultFont`.
- Saving: wrapped in try-catch; a failed write is non-fatal (the in-memory
  selection still applies for the session).

## Testing

- `FontService`: returns `defaultFont` when nothing stored; loads a stored value;
  `selectFont` updates the notifier and persists (using
  `SharedPreferences.setMockInitialValues`).
- `AppFont`: round-trips through its `name` serialization; unknown name resolves
  to default.
- `SettingsCubit`: `selectFont` updates state and calls the service.
- `CrosswordCubit`: a service font change is reflected in emitted
  `CrosswordState`.
- Widget smoke test: `SettingsScreen` renders all 9 font rows without throwing.

## Out of scope (YAGNI)

- Cloud-syncing the preference (local only for now).
- Changing the app-bar title or image-clue label fonts.
- Per-text-type font choices (one choice covers both letters and clues).

Known accepted trade-off: looser handwritten fonts reduce legibility of small
clue text; this is the player's choice.
