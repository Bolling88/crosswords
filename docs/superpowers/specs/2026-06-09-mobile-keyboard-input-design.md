# Mobile Keyboard Input — Design

**Date:** 2026-06-09
**Status:** Approved (pending spec review)

## Problem

Letter entry in the crossword is driven entirely by `Focus.onKeyEvent` reading
`event.character` — a **hardware** keyboard path. On a phone there is no
`TextField` in the tree, so the OS never raises a soft keyboard and the grid
cannot be filled by touch. This blocks the app on its primary platforms (iOS,
Android) and on the web app when opened from a phone browser.

## Goal

Tapping a fillable cell raises the device's native soft keyboard, and typing
(including Swedish `Å Ä Ö` and backspace) fills the grid using the existing
word-advance / gap-fill logic — on native iOS/Android **and** on the web app
running in a phone browser. The existing hardware-keyboard behaviour on desktop
and desktop-web is left untouched.

## Approach: additive, platform-gated

A second, mobile-only input path is added **alongside** the existing
`Focus.onKeyEvent` path rather than replacing it. The hardware path already
handles letters, backspace, and arrow navigation correctly on desktop/web-desktop
and is covered by tests; leaving it intact keeps regression risk near zero.

### Hidden text field

A zero-size, transparent `TextField` is placed at the **screen** level — in the
`Scaffold` body, as a sibling of the `InteractiveViewer` inside a thin `Stack`
wrapper — rather than inside the grid. This keeps it outside the zoom/pan
transform, keeps input plumbing next to the existing `Focus` (also a screen-level
input concern), and leaves `CrosswordGrid` a pure renderer. It is built **only on
touch platforms** (see gating). Focusing it is what raises the OS soft keyboard;
its size and transparency keep it invisible and non-interactive so cell taps still
reach the grid.

Per the CLAUDE.md rule that controllers belong in Cubits, its `TextEditingController`
and a dedicated `FocusNode` live in `CrosswordCubit`. This `FocusNode` is separate
from the existing `focusNode` used by the outer hardware `Focus`.

### Sentinel-diff input translation

Soft keyboards deliver text through the IME, not raw key events, so the hidden
field cannot read keystrokes directly. The controller is seeded with an invisible
**sentinel** character (zero-width space, `​`). On each `onChanged(value)`:

- `value.length > sentinel.length` → a letter was typed. Take the last character;
  if it matches `[a-zA-ZåäöÅÄÖ]`, call the existing `onLetterInput(char.toUpperCase())`.
  Non-letters are ignored.
- `value.isEmpty` → the sentinel was deleted → call the existing `onBackspace()`.

After handling, the controller is reset to the sentinel with the cursor collapsed
at the end. Programmatic controller resets do **not** re-fire `onChanged` (Flutter
only calls it for user edits), so there is no feedback loop.

The field sets `autocorrect: false`, `enableSuggestions: false`, and
`textCapitalization: TextCapitalization.characters` so Swedish words are never
mangled by predictive text.

This path is a pure translator: it converts IME events into the two methods that
already exist (`onLetterInput`, `onBackspace`), reusing all current word-advance,
gap-fill, and next-word logic unchanged.

### Platform gating (the safety boundary)

A single touch-platform predicate gates both the hidden-field build and the
Cubit's "raise keyboard on select" call:

```dart
bool get _isTouchPlatform =>
    defaultTargetPlatform == TargetPlatform.iOS ||
    defaultTargetPlatform == TargetPlatform.android;
```

- Uses `defaultTargetPlatform` from `package:flutter/foundation.dart` — **never**
  `dart:io`'s `Platform`, which throws on web.
- `kIsWeb` is **not** used to exclude web. On Flutter web, `defaultTargetPlatform`
  reports the *device's actual* platform: a phone browser returns `iOS`/`android`
  (→ mobile path, soft keyboard), a desktop browser returns
  `macOS`/`windows`/`linux` (→ hardware path). Web-mobile therefore falls on the
  mobile side of the gate automatically.

On desktop (native or web) the hidden field is never built and never focused, so
the existing `Focus.onKeyEvent` retains sole ownership of input — including arrow
navigation. There is no double-input and no focus tug-of-war.

### Raising the keyboard on selection

When a cell is selected on a touch platform, the Cubit focuses the hidden field's
`FocusNode`, which raises the soft keyboard. This happens on every selection path
that lands on a fillable target (tapping a clue, tapping an answer cell, arrow
moves), gated by `_isTouchPlatform` so desktop never moves focus off the outer
`Focus`.

## Components & changes

- **`CrosswordCubit`**
  - New `TextEditingController inputController` (seeded with the sentinel) and
    `FocusNode keyboardFocusNode`.
  - New `onInputChanged(String value)` implementing the sentinel diff.
  - `_isTouchPlatform` predicate; selection paths request `keyboardFocusNode`
    focus when on a touch platform.
  - `close()` disposes the new controller and focus node.
- **`crossword_screen.dart`**
  - On touch platforms, wrap the `Scaffold` body in a `Stack` and add the hidden
    `TextField` (controller + focus node from the Cubit,
    `onChanged: cubit.onInputChanged`) as a sibling of the `InteractiveViewer`,
    sized zero / transparent.
  - No change to the existing hardware `Focus.onKeyEvent` path.
- **`CrosswordGrid`** — unchanged; stays a pure renderer.

## Testing

- **Cubit unit tests** for `onInputChanged`:
  - sentinel → letter value dispatches `onLetterInput` (uppercased) and advances
    selection as the existing letter path does.
  - sentinel → empty dispatches `onBackspace`.
  - non-letter input (e.g. a digit) is ignored.
  - controller resets to the sentinel after handling.
- **Widget test** with `debugDefaultTargetPlatformOverride = TargetPlatform.iOS`
  asserting the hidden `TextField` is present (this also represents the web-mobile
  case, since the gate is platform-based); and asserting it is **absent** on a
  desktop platform override.
- Existing hardware-keyboard cubit/widget tests must continue to pass unchanged.

## Out of scope (YAGNI)

- Custom in-app keypad.
- Arrow-key navigation from an external keyboard attached to an iPad/phone.
- Any web-desktop-specific soft-keyboard handling.
