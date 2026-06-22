import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:crossword_core/crossword_core.dart';

import '../../../../settings/domain/services/font_service.dart';
import '../../../../settings/domain/services/gameplay_settings_service.dart';
import '../../../domain/services/progress_service.dart';
import '../crossword_engine.dart';
import '../keyboard_follow.dart';
import 'crossword_state.dart';

class CrosswordCubit extends Cubit<CrosswordState> {
  /// Invisible seed character kept in [inputController] so the hidden mobile
  /// field always has content: a longer value means a letter was typed, an
  /// empty value means the user pressed backspace on the sentinel. Public only
  /// so tests can reference it.
  @visibleForTesting
  static const inputSentinel = '​'; // zero-width space

  static final _letterPattern = RegExp(r'[a-zA-ZåäöÅÄÖ]');

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
  final GameplaySettingsService _settingsService;
  final ProgressService _progressService;
  final CrosswordEngine _engine;

  /// Latest grid layout from the player's LayoutBuilder, used to keep the
  /// selected cell visible. Plain fields — view geometry, never emitted.
  Size? _viewportSize;
  double? _cellSize;

  CrosswordCubit({
    required CrosswordPuzzle puzzle,
    required FontService fontService,
    required GameplaySettingsService settingsService,
    required ProgressService progressService,
    CrosswordEngine engine = const CrosswordEngine(),
  })  : _fontService = fontService,
        _settingsService = settingsService,
        _progressService = progressService,
        _engine = engine,
        super(_restoredState(puzzle, fontService, progressService, engine)) {
    _fontService.selectedFont.addListener(_onFontChanged);
  }

  /// Returns the progress storage key for [puzzle]. Generated puzzles carry a
  /// stable [CrosswordPuzzle.id] derived from their grid content; the bundled
  /// puzzle has no id and falls back to [CrosswordPuzzle.title].
  static String _keyFor(CrosswordPuzzle puzzle) => puzzle.id ?? puzzle.title;

  /// The key progress is stored under: the puzzle's unique id when available,
  /// or its title for the bundled puzzle.
  String get _progressKey => _keyFor(state.puzzle);

  /// Initial state with any locally saved progress folded back in. A puzzle
  /// restored already-solved sets [CrosswordState.isSolved] without firing
  /// [PuzzleSolved] — events are transition-edged in [_apply].
  static CrosswordState _restoredState(
    CrosswordPuzzle puzzle,
    FontService fontService,
    ProgressService progressService,
    CrosswordEngine engine,
  ) {
    final base = CrosswordState(
      puzzle: puzzle,
      font: fontService.selectedFont.value,
    );
    final snapshot = progressService.read(_keyFor(puzzle));
    if (snapshot == null) return base;
    final restored = base.copyWith(
      userInputs: snapshot.userInputs,
      revealedCells: snapshot.revealedCells,
    );
    return restored.copyWith(
      isSolved: engine.computeSolved(restored, restored.userInputs),
    );
  }

  void _onFontChanged() {
    emit(state.copyWith(font: _fontService.selectedFont.value));
  }

  void selectCell(int row, int col) =>
      _apply(_engine.selectCell(state, row, col), raiseKeyboard: true);

  void onLetterInput(String letter) => _apply(
        _engine.inputLetter(
          state,
          letter,
          autocheck: _settingsService.autocheck.value,
        ),
        raiseKeyboard: false,
        letterHaptic: true,
      );

  void onBackspace() =>
      _apply(_engine.backspace(state), raiseKeyboard: false);

  void moveSelection(int rowDelta, int colDelta) =>
      _apply(_engine.moveSelection(state, rowDelta, colDelta),
          raiseKeyboard: true);

  void checkWord() => _apply(_engine.checkWord(state), raiseKeyboard: false);

  void checkPuzzle() => _apply(_engine.checkPuzzle(state), raiseKeyboard: false);

  void revealCell() => _apply(_engine.revealCell(state), raiseKeyboard: false);

  void revealWord() => _apply(_engine.revealWord(state), raiseKeyboard: false);

  /// Reveal the entire solution. This fills and locks the grid (making it
  /// solved) but is a "give up" action, so the celebration is suppressed —
  /// only genuinely solving the puzzle shows it.
  void revealSolution() => _apply(
        _engine.revealSolution(state),
        raiseKeyboard: false,
        suppressSolvedEvent: true,
      );

  void clearWord() => _apply(_engine.clearWord(state), raiseKeyboard: false);

  void restartPuzzle() => _apply(_engine.restart(state), raiseKeyboard: false);

  /// Emit [next] when it differs from the current state, and — for selection
  /// actions only — raise the soft keyboard. A no-op (unchanged state: tapping a
  /// block/image cell, a re-tap with no crossing word, or an arrow move off the
  /// grid) neither emits nor raises the keyboard. Typing and backspace pass
  /// [raiseKeyboard] false — the keyboard is already up mid-entry. After
  /// emitting, persist changed progress and fire transition-edged feedback
  /// (haptics and one-shot event states).
  /// Record the current viewport size and cell size from the player's
  /// LayoutBuilder. When the viewport changes while a cell is selected (the
  /// soft keyboard opens and the body resizes), schedule a visibility check
  /// for after this frame — assigning the transform during build would
  /// re-enter the InteractiveViewer's listener.
  void setLayout({required Size viewport, required double cellSize}) {
    final changed = _viewportSize != viewport || _cellSize != cellSize;
    _viewportSize = viewport;
    _cellSize = cellSize;
    if (changed && state.selectedCell != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _ensureSelectedCellVisible(),
      );
    }
  }

  /// Nudge the grid so the selected cell sits in a comfortable band of the
  /// visible viewport, if metrics and a selection are known. No-op otherwise.
  void _ensureSelectedCellVisible() {
    final viewport = _viewportSize;
    final cellSize = _cellSize;
    final sel = state.selectedCell;
    if (viewport == null || cellSize == null || sel == null) return;

    final next = transformToRevealCell(
      current: transformationController.value,
      viewport: viewport,
      cellSize: cellSize,
      rows: state.puzzle.rows,
      cols: state.puzzle.cols,
      cell: sel,
      margin: cellSize,
    );
    if (next != null) transformationController.value = next;
  }

  void _apply(
    CrosswordState next, {
    required bool raiseKeyboard,
    bool letterHaptic = false,
    bool suppressSolvedEvent = false,
  }) {
    final prev = state;
    if (next == prev) return;
    emit(next);
    if (raiseKeyboard) _raiseKeyboard();
    _persistProgress(prev, next);
    _feedback(
      prev,
      next,
      letterHaptic: letterHaptic,
      suppressSolvedEvent: suppressSolvedEvent,
    );
    if (next.selectedCell != prev.selectedCell) _ensureSelectedCellVisible();
  }

  /// Save progress when inputs or revealed letters changed. The engine only
  /// allocates new collections when it mutates them, so identity comparison
  /// is sufficient. An empty snapshot (restart) removes the stored entry.
  void _persistProgress(CrosswordState prev, CrosswordState next) {
    if (identical(next.userInputs, prev.userInputs) &&
        identical(next.revealedCells, prev.revealedCells)) {
      return;
    }
    unawaited(_progressService.save(
      _progressKey,
      ProgressSnapshot(
        userInputs: next.userInputs,
        revealedCells: next.revealedCells,
      ),
    ));
  }

  /// Haptic and one-shot event feedback for state transitions, strongest
  /// signal first. Haptics only fire on touch platforms.
  void _feedback(
    CrosswordState prev,
    CrosswordState next, {
    required bool letterHaptic,
    bool suppressSolvedEvent = false,
  }) {
    if (next.isSolved && !prev.isSolved) {
      // Revealing the full solution still flips isSolved, but it isn't a win:
      // skip the haptic and celebration so they stay reserved for solving.
      if (suppressSolvedEvent) return;
      _haptic(HapticFeedback.heavyImpact);
      emit(PuzzleSolved(state: next));
      return;
    }
    if (!next.isSolved && _engine.isFilled(next) && !_engine.isFilled(prev)) {
      _haptic(HapticFeedback.vibrate);
      emit(PuzzleFilledButIncorrect(state: next));
      return;
    }
    if (next.confirmedWordToken != prev.confirmedWordToken) {
      _haptic(HapticFeedback.mediumImpact);
      return;
    }
    if (next.incorrectCells.length > prev.incorrectCells.length) {
      _haptic(HapticFeedback.vibrate);
      return;
    }
    if (letterHaptic) _haptic(HapticFeedback.lightImpact);
  }

  void _haptic(Future<void> Function() effect) {
    if (isTouchPlatform) unawaited(effect());
  }

  /// Translate an edit from the hidden mobile text field into letter or
  /// backspace actions. The field is seeded with [inputSentinel]; a value longer
  /// than the sentinel means characters were typed, an empty value means the
  /// sentinel itself was deleted. Every typed character is entered in order —
  /// not just the last — so a suggestion-bar word, glide-typed word, or paste
  /// is not silently truncated. The controller is then reset to the sentinel so
  /// the next keystroke is detectable.
  void onInputChanged(String value) {
    if (value.length > inputSentinel.length) {
      for (final char in value.substring(inputSentinel.length).split('')) {
        if (_letterPattern.hasMatch(char)) {
          onLetterInput(char.toUpperCase());
        }
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
  /// Also used by the view to decide whether to build the hidden mobile field,
  /// so the gate lives in one place.
  bool get isTouchPlatform =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.android;

  /// Focus the hidden field to raise the soft keyboard, but only on touch
  /// platforms and only once the field is mounted (its node has a context). On
  /// desktop the field is never built, so the existing hardware [Focus] keeps
  /// sole ownership of input and arrow navigation.
  void _raiseKeyboard() {
    if (isTouchPlatform && keyboardFocusNode.context != null) {
      keyboardFocusNode.requestFocus();
    }
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
    inputController.dispose();
    keyboardFocusNode.dispose();
    return super.close();
  }
}
