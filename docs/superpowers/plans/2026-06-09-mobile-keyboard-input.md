# Mobile Keyboard Input Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tapping a fillable cell raises the device's native soft keyboard so the grid can be typed (incl. Å Ä Ö and backspace) on native iOS/Android and on the web app opened from a phone browser, without disturbing the existing hardware-keyboard path on desktop/web-desktop.

**Architecture:** Add a second, mobile-only input path *alongside* the existing `Focus.onKeyEvent` path. A zero-area, transparent `TextField` lives at the screen level and is built only on touch platforms; focusing it raises the OS soft keyboard. Its IME edits are translated by the Cubit (via a seeded "sentinel" character) into the existing `onLetterInput`/`onBackspace` methods. A single `defaultTargetPlatform` gate (never `kIsWeb`, never `dart:io`) makes web-mobile fall on the mobile side and keeps desktop on the hardware path.

**Tech Stack:** Flutter, flutter_bloc (Cubit), `package:flutter/foundation.dart` (`defaultTargetPlatform`, `debugDefaultTargetPlatformOverride`), flutter_test.

**Spec:** `docs/superpowers/specs/2026-06-09-mobile-keyboard-input-design.md`

---

## File Structure

- **Modify** `lib/gameplay/presentation/crossword_screen/cubit/crossword_cubit.dart`
  — add the hidden field's `TextEditingController` + `FocusNode`, the `inputSentinel` constant, `onInputChanged`, a touch-platform gate, "raise keyboard on select", and disposal.
- **Modify** `lib/gameplay/presentation/crossword_screen/crossword_screen.dart`
  — wrap the `Scaffold` body in a `Stack` and add the platform-gated hidden `TextField`. The hardware `Focus.onKeyEvent` path is unchanged. `CrosswordGrid` is untouched.
- **Modify** `test/gameplay/presentation/crossword_screen/cubit/crossword_cubit_test.dart`
  — unit tests for `onInputChanged`.
- **Create** `test/gameplay/presentation/crossword_screen/mobile_input_present_test.dart`
  — widget test: hidden field present under an iOS platform override.
- **Create** `test/gameplay/presentation/crossword_screen/mobile_input_absent_test.dart`
  — widget test: hidden field absent under a desktop platform override.

> **Why two new widget-test files:** `crossword_screen_test.dart` documents that a *second* full screen render in the same file hangs (google_fonts leaks font-loading state across renders in one isolate). `flutter test` runs each file in its own isolate, so each new file performs exactly one render and stays clear of that hang.

---

## Task 1: Cubit — IME translation + keyboard raising

**Files:**
- Modify: `lib/gameplay/presentation/crossword_screen/cubit/crossword_cubit.dart`
- Test: `test/gameplay/presentation/crossword_screen/cubit/crossword_cubit_test.dart`

- [ ] **Step 1: Write the failing tests**

Add this group to `crossword_cubit_test.dart`, immediately before the existing
`test('resetView resets transformationController to identity', ...)` line:

```dart
  group('mobile soft-keyboard input', () {
    test('typing a letter via the hidden field fills the cell and advances', () {
      cubit.selectCell(0, 1); // active across word, selected at (0,1)
      cubit.onInputChanged('${CrosswordCubit.inputSentinel}a');
      expect(cubit.state.userInputs[(0, 1)], 'A');
      expect(cubit.state.selectedCell, (0, 2));
      // Controller is reset to the sentinel so the next keystroke is detectable.
      expect(cubit.inputController.text, CrosswordCubit.inputSentinel);
    });

    test('deleting the sentinel triggers a backspace', () {
      cubit.selectCell(0, 1);
      cubit.onInputChanged('${CrosswordCubit.inputSentinel}A'); // (0,1)=A -> (0,2)
      cubit.onInputChanged(''); // sentinel deleted on the now-empty (0,2)
      // Matches the existing backspace rule: empty cell steps back and clears.
      expect(cubit.state.selectedCell, (0, 1));
      expect(cubit.state.userInputs.containsKey((0, 1)), isFalse);
      expect(cubit.inputController.text, CrosswordCubit.inputSentinel);
    });

    test('non-letter input is ignored', () {
      cubit.selectCell(0, 1);
      cubit.onInputChanged('${CrosswordCubit.inputSentinel}5');
      expect(cubit.state.userInputs.containsKey((0, 1)), isFalse);
      expect(cubit.state.selectedCell, (0, 1));
      expect(cubit.inputController.text, CrosswordCubit.inputSentinel);
    });
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/gameplay/presentation/crossword_screen/cubit/crossword_cubit_test.dart`
Expected: FAIL — compile error, `inputSentinel`/`inputController`/`onInputChanged` are not defined on `CrosswordCubit`.

- [ ] **Step 3: Add the import**

In `crossword_cubit.dart`, add this import after the existing
`import 'package:flutter/widgets.dart';` line:

```dart
import 'package:flutter/foundation.dart';
```

- [ ] **Step 4: Add the fields and sentinel constant**

In `crossword_cubit.dart`, replace this existing block:

```dart
class CrosswordCubit extends Cubit<CrosswordState> {
  final FocusNode focusNode = FocusNode();
  final TransformationController transformationController =
      TransformationController();
  final FontService _fontService;
```

with:

```dart
class CrosswordCubit extends Cubit<CrosswordState> {
  /// Invisible seed character kept in [inputController] so the hidden mobile
  /// field always has content: a longer value means a letter was typed, an
  /// empty value means the user pressed backspace on the sentinel.
  static const inputSentinel = '\u200b'; // zero-width space

  final FocusNode focusNode = FocusNode();
  final TransformationController transformationController =
      TransformationController();

  /// Controller + focus node for the hidden, mobile-only text field that summons
  /// the OS soft keyboard. Owned here per the project rule that controllers live
  /// in the Cubit. Seeded with [inputSentinel].
  final TextEditingController inputController =
      TextEditingController(text: inputSentinel);
  final FocusNode keyboardFocusNode = FocusNode();

  final FontService _fontService;
```

- [ ] **Step 5: Add `onInputChanged`, the platform gate, and the keyboard-raise helper**

In `crossword_cubit.dart`, insert these methods immediately after the closing
brace of `onBackspace()` (i.e. right before the `/// Make [word] the active word`
doc comment on `_activateWord`):

```dart
  /// Translate an edit from the hidden mobile text field into a letter or
  /// backspace action. The field is seeded with [inputSentinel]; a value longer
  /// than the sentinel means a character was typed (we take the last one), an
  /// empty value means the sentinel itself was deleted. The controller is then
  /// reset to the sentinel so the next keystroke is detectable.
  void onInputChanged(String value) {
    if (value.length > inputSentinel.length) {
      // åäöÅÄÖ are single UTF-16 code units, so the last unit is a full char.
      final typed = value.substring(value.length - 1);
      if (RegExp(r'[a-zA-ZåäöÅÄÖ]').hasMatch(typed)) {
        onLetterInput(typed.toUpperCase());
      }
    } else if (value.isEmpty) {
      onBackspace();
    }
    inputController.value = const TextEditingValue(
      text: inputSentinel,
      selection: TextSelection.collapsed(offset: inputSentinel.length),
    );
  }

  /// True on platforms that use a soft keyboard. Reported by
  /// [defaultTargetPlatform], which on the web returns the *device's* platform —
  /// so a phone browser counts as mobile and a desktop browser does not. Never
  /// keyed off `kIsWeb` or `dart:io`'s `Platform` (the latter throws on web).
  bool get _isTouchPlatform =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.android;

  /// Focus the hidden field to raise the soft keyboard, but only on touch
  /// platforms and only once the field is mounted (its node has a context). On
  /// desktop the field is never built, so the existing hardware [Focus] keeps
  /// sole ownership of input and arrow navigation.
  void _raiseKeyboard() {
    if (_isTouchPlatform && keyboardFocusNode.context != null) {
      keyboardFocusNode.requestFocus();
    }
  }
```

- [ ] **Step 6: Raise the keyboard on every real selection**

In `crossword_cubit.dart`, in `_activateWord`, change the closing of the `emit`
call from:

```dart
      highlightedCells: word.cells.toSet(),
    ));
  }
```

to:

```dart
      highlightedCells: word.cells.toSet(),
    ));
    _raiseKeyboard();
  }
```

Then, in `_selectAnswerCell`, change the lone-cell branch from:

```dart
    if (word == null) {
      emit(state.copyWith(
        selectedCell: (row, col),
        highlightedCells: {(row, col)},
      ));
      return;
    }
```

to:

```dart
    if (word == null) {
      emit(state.copyWith(
        selectedCell: (row, col),
        highlightedCells: {(row, col)},
      ));
      _raiseKeyboard();
      return;
    }
```

- [ ] **Step 7: Dispose the new controller and focus node**

In `crossword_cubit.dart`, change `close()` from:

```dart
  @override
  Future<void> close() {
    _fontService.selectedFont.removeListener(_onFontChanged);
    focusNode.dispose();
    transformationController.dispose();
    return super.close();
  }
```

to:

```dart
  @override
  Future<void> close() {
    _fontService.selectedFont.removeListener(_onFontChanged);
    focusNode.dispose();
    transformationController.dispose();
    inputController.dispose();
    keyboardFocusNode.dispose();
    return super.close();
  }
```

- [ ] **Step 8: Run the new tests to verify they pass**

Run: `flutter test test/gameplay/presentation/crossword_screen/cubit/crossword_cubit_test.dart`
Expected: PASS — all tests in the file, including the three new ones.

> Note: in `flutter test` the default platform is android, so `_isTouchPlatform`
> is true, but `keyboardFocusNode.context` is null in a pure cubit test (no
> widget tree), so `_raiseKeyboard()` is a safe no-op. The full file passing
> confirms the existing `selectCell`-based tests are unaffected.

- [ ] **Step 9: Commit**

```bash
git add lib/gameplay/presentation/crossword_screen/cubit/crossword_cubit.dart test/gameplay/presentation/crossword_screen/cubit/crossword_cubit_test.dart
git commit -m "feat: translate hidden-field IME input to letter/backspace

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 2: Screen — platform-gated hidden text field

**Files:**
- Modify: `lib/gameplay/presentation/crossword_screen/crossword_screen.dart`
- Test (create): `test/gameplay/presentation/crossword_screen/mobile_input_present_test.dart`
- Test (create): `test/gameplay/presentation/crossword_screen/mobile_input_absent_test.dart`

- [ ] **Step 1: Write the failing "present on mobile" widget test**

Create `test/gameplay/presentation/crossword_screen/mobile_input_present_test.dart`:

```dart
import 'package:crosswords/gameplay/data/local_puzzle_data_source.dart';
import 'package:crosswords/gameplay/presentation/crossword_screen/crossword_screen.dart';
import 'package:crosswords/settings/domain/services/font_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Widget> _app() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final puzzle = await LocalPuzzleDataSource().loadGeneratedPuzzle();
  return RepositoryProvider<FontService>.value(
    value: FontService(prefs: prefs),
    child: MaterialApp(home: CrosswordScreen(puzzle: puzzle)),
  );
}

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  testWidgets('hidden mobile text field is present on a touch platform', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await tester.pumpWidget(await _app());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mobileTextInput')), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/gameplay/presentation/crossword_screen/mobile_input_present_test.dart`
Expected: FAIL — `find.byKey(const Key('mobileTextInput'))` finds nothing (no hidden field exists yet).

- [ ] **Step 3: Add the hidden field to the screen**

In `crossword_screen.dart`, in `CrosswordScreenContent.build`, replace the entire
`body:` argument of the `Scaffold`. Change from:

```dart
      body: Focus(
        focusNode: cubit.focusNode,
        autofocus: true,
        onKeyEvent: (node, event) {
```

down through the matching close of that `Focus` widget:

```dart
              );
            },
          ),
        ),
      ),
    );
  }
}
```

so that the `Focus(...)` is wrapped in a `Stack` with the gated hidden field as a
sibling. Concretely, wrap the existing `Focus(...)` like this — keep the entire
existing `Focus(...)` subtree exactly as-is and only add the `Stack`, the
`children:`/`<Widget>[]` scaffolding, the trailing comma, and the
`if (isTouchPlatform) ...` field after it:

```dart
      body: Stack(
        children: [
          Focus(
            focusNode: cubit.focusNode,
            autofocus: true,
            onKeyEvent: (node, event) {
              // ...UNCHANGED: existing letter/backspace/arrow handling...
            },
            child: SafeArea(
              // ...UNCHANGED: existing LayoutBuilder/InteractiveViewer subtree...
            ),
          ),
          // Hidden, mobile-only input that summons the OS soft keyboard. Built
          // only on touch platforms (incl. phone browsers, via
          // defaultTargetPlatform). Behind everything, pointer-ignoring, and
          // fully transparent so it never shows or blocks cell taps; the Cubit
          // focuses it on selection to raise the keyboard.
          if (defaultTargetPlatform == TargetPlatform.iOS ||
              defaultTargetPlatform == TargetPlatform.android)
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
      ),
    );
  }
}
```

> Do NOT alter the body of the existing `onKeyEvent` callback or the
> `SafeArea`/`LayoutBuilder`/`InteractiveViewer` subtree — they keep the desktop
> hardware path working. `defaultTargetPlatform`/`TargetPlatform` are already
> available via the existing `package:flutter/material.dart` import.

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/gameplay/presentation/crossword_screen/mobile_input_present_test.dart`
Expected: PASS — the hidden field is found under the iOS override.

- [ ] **Step 5: Write the "absent on desktop" widget test**

Create `test/gameplay/presentation/crossword_screen/mobile_input_absent_test.dart`:

```dart
import 'package:crosswords/gameplay/data/local_puzzle_data_source.dart';
import 'package:crosswords/gameplay/presentation/crossword_screen/crossword_screen.dart';
import 'package:crosswords/settings/domain/services/font_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Widget> _app() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final puzzle = await LocalPuzzleDataSource().loadGeneratedPuzzle();
  return RepositoryProvider<FontService>.value(
    value: FontService(prefs: prefs),
    child: MaterialApp(home: CrosswordScreen(puzzle: puzzle)),
  );
}

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  testWidgets('hidden mobile text field is absent on a desktop platform', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    await tester.pumpWidget(await _app());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mobileTextInput')), findsNothing);
  });
}
```

- [ ] **Step 6: Run the absent test to verify it passes**

Run: `flutter test test/gameplay/presentation/crossword_screen/mobile_input_absent_test.dart`
Expected: PASS — no hidden field under the macOS override.

- [ ] **Step 7: Analyze, run the full suite, and commit**

Run: `flutter analyze lib/gameplay test/gameplay`
Expected: `No issues found!`

Run: `flutter test`
Expected: All tests pass (the existing `crossword_screen_test.dart` single-render test still passes; its default-android render now also builds the invisible field harmlessly).

```bash
git add lib/gameplay/presentation/crossword_screen/crossword_screen.dart test/gameplay/presentation/crossword_screen/mobile_input_present_test.dart test/gameplay/presentation/crossword_screen/mobile_input_absent_test.dart
git commit -m "feat: raise OS soft keyboard via hidden field on mobile

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Manual verification (after both tasks)

These confirm the real-device behaviour the unit/widget tests can't:

- **Native phone:** `flutter run` on an iOS/Android device or simulator → tap a
  fillable cell → soft keyboard appears → typing fills the grid and auto-advances;
  backspace clears/steps back. Confirm Å Ä Ö are typeable.
- **Web-mobile:** `flutter run -d chrome`, open in a phone browser (or device
  emulation) → tapping a cell raises the on-screen keyboard.
- **Desktop:** `flutter run -d macos` (or chrome on desktop) → hardware typing and
  arrow-key navigation still work; no stray text field interferes.
```
