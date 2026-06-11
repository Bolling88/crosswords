import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:crossword_core/crossword_core.dart';

import '../../../../settings/domain/services/font_service.dart';
import '../crossword_engine.dart';
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
  final CrosswordEngine _engine;

  CrosswordCubit({
    required CrosswordPuzzle puzzle,
    required FontService fontService,
    CrosswordEngine engine = const CrosswordEngine(),
  })  : _fontService = fontService,
        _engine = engine,
        super(CrosswordState(
          puzzle: puzzle,
          font: fontService.selectedFont.value,
        )) {
    _fontService.selectedFont.addListener(_onFontChanged);
  }

  void _onFontChanged() {
    emit(state.copyWith(font: _fontService.selectedFont.value));
  }

  void selectCell(int row, int col) =>
      _applySelection(_engine.selectCell(state, row, col));

  void onLetterInput(String letter) => emit(_engine.inputLetter(state, letter));

  void onBackspace() => emit(_engine.backspace(state));

  void moveSelection(int rowDelta, int colDelta) =>
      _applySelection(_engine.moveSelection(state, rowDelta, colDelta));

  /// Emit [next] and raise the soft keyboard. Used only for selection actions
  /// (tapping a cell, arrow keys): the player is moving the caret, so summon the
  /// keyboard. Typing and backspace emit directly and never re-raise it — the
  /// keyboard is already up mid-entry.
  void _applySelection(CrosswordState next) {
    emit(next);
    _raiseKeyboard();
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
