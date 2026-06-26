# Design: Support all crossword-generation fields

**Date:** 2026-06-26
**Status:** Approved (pending spec review)

## Goal

Expose all 9 fields of the `POST /crossword-puzzles/generate` request and make
them user-editable in the shared Generate screen. Because both the web
(`apps/web`) and mobile (`apps/mobile`) apps render generation through the same
`crossword_ui` package and `crossword_api` package, a single set of changes
covers both apps.

## Background / current state

The backend request schema is:

```json
{
  "width": 17,
  "height": 17,
  "language_code": "string",
  "seed_words": ["string"],
  "random_seed": 0,
  "max_seconds": 30,
  "max_word_len": 6,
  "picture_cols": 8,
  "picture_rows": 6
}
```

Today only 4 of these are user-controlled; the rest are hardcoded or missing:

| Field | Current handling |
|---|---|
| `width`, `height` | user-controlled (square preset chips) |
| `max_word_len` | user-controlled (preset chips) |
| `seed_words` | user-controlled (text field) |
| `language_code` | hardcoded `'sv'` |
| `max_seconds` | hardcoded `30` |
| `picture_cols` / `picture_rows` | hardcoded `0` |
| `random_seed` | **not sent at all** |

Relevant files:

- `packages/crossword_api/lib/src/dto/crossword_generation_request.dart`
- `packages/crossword_api/lib/src/crossword_generation_repository.dart`
- `packages/crossword_api/lib/src/puzzle_generation_service.dart`
- `packages/crossword_ui/lib/gameplay/presentation/generate_screen/generate_screen.dart`
- `packages/crossword_ui/lib/gameplay/presentation/generate_screen/cubit/generate_cubit.dart`
- `packages/crossword_ui/lib/gameplay/presentation/generate_screen/cubit/generate_state.dart`
- `packages/crossword_ui/lib/common/data/constants/strings.dart`

## Decisions (from brainstorming)

- **UI scope:** all 9 fields editable in the UI.
- **Pictures:** expose `picture_cols` / `picture_rows` as editable controls.
- **Language:** Swedish only — selector present (single `'sv'` option) but
  structured to grow.
- **Numeric input style:** chips/steppers, no free text — keep existing preset
  chips for size & max word length; use `+/-` steppers for the new numeric
  fields. `random_seed` is the single exception (optional arbitrary integer →
  numeric text field).
- **`random_seed`:** optional; blank ⇒ omit the field so the backend randomizes.
  Setting it allows reproducible puzzles.
- **Size:** keep existing square preset chips (`width == height`). Independent
  non-square width/height is explicitly out of scope for this change.

## Design

### 1. Request DTO

`CrosswordGenerationRequest` carries all fields:

| Field | Type | Default |
|---|---|---|
| `width`, `height` | `int` | 15 |
| `maxWordLen` | `int` | 6 |
| `seedWords` | `List<String>` | `const []` |
| `languageCode` | `String` | `'sv'` |
| `randomSeed` | `int?` | `null` |
| `maxSeconds` | `int` | 30 |
| `pictureCols` | `int` | 0 |
| `pictureRows` | `int` | 0 |

`toJson()` includes every field; `random_seed` is included only when
`randomSeed != null` (blank ⇒ backend randomizes).

### 2. Plumbing (repository + service)

`CrosswordGenerationRepository.generate(...)` and
`PuzzleGenerationService.generate(...)` gain matching named params with the same
defaults as the DTO, forwarding into the DTO. Existing callers are unaffected
because every new param has a default.

### 3. State + Cubit

- `GenerateState` gains `languageCode`, `maxSeconds`, `pictureCols`,
  `pictureRows`, plus bounds/preset constants. Update `copyWith`, `props`, and
  the `.copy` constructor.
- `random_seed` is held in a `randomSeedController` (`TextEditingController`) in
  the cubit, mirroring the existing `seedWordsController`. Parsed to `int?` at
  generate time via `int.tryParse` (blank/invalid ⇒ `null`). Disposed in
  `close()`.
- New cubit mutators: clamped increment/decrement for `maxSeconds`,
  `pictureCols`, `pictureRows`; `selectLanguage(String)` (single `'sv'` option
  today).
- `generate()` forwards all fields (state values + parsed seed words + parsed
  random seed) into `service.generate(...)`.

### 4. UI (`generate_screen.dart`)

Controls, top to bottom:

- **Språk** (`languageCode`): single-choice chip group (`sv` selected).
- **Storlek** (`width×height`): existing square preset chips.
- **Längsta ord** (`maxWordLen`): existing preset chips.
- **Max tid (s)** (`maxSeconds`): stepper, range 5–120, step 5, default 30.
- **Bildrutor** (`pictureCols` × `pictureRows`): two steppers, range
  `0..width` / `0..height`, default 0 (0 = no image-clue area).
- **Slumpfrö** (`randomSeed`): optional numeric `TextField`, blank = random.
- **Egna ord** (`seedWords`): existing text field.

A new private `_LabeledStepper` `StatelessWidget` renders label + `−`/`+`
`IconButton`s + current value. All controls are disabled while
`state.isGenerating`.

Picture stepper upper bounds are clamped to the current grid dimension; when
the user lowers the size below the current picture dimension, the cubit clamps
the picture values down.

### 5. Strings

Add Swedish labels to `Strings`: language, max seconds, picture cols/rows,
random seed (label + hint). No hardcoded user-facing strings.

### 6. Testing

- DTO `toJson` test: all fields present with expected keys; `random_seed`
  omitted when `null`, present when set.
- Cubit tests: stepper clamping at bounds; picture clamping when size shrinks;
  `generate()` forwards all params (including parsed seed words and parsed
  random seed) to the service.

## Out of scope

- Independent non-square width/height.
- Additional languages beyond `'sv'`.
- Actual rendering/use of image-clue areas in gameplay (this change only sends
  the picture dimensions to the backend).

## Affected apps

Both `apps/web` and `apps/mobile` inherit the change through the shared
`crossword_ui` / `crossword_api` packages; no app-specific code changes.
