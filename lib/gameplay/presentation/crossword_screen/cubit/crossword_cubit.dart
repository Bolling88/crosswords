import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../gameplay/domain/entities/cell.dart';
import '../../../../gameplay/domain/entities/crossword_puzzle.dart';
import '../../../../gameplay/domain/entities/direction.dart';
import '../../../../gameplay/domain/entities/word.dart';
import '../../../../settings/domain/services/font_service.dart';
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

  void selectCell(int row, int col) {
    final cell = state.puzzle.cells[(row, col)];
    if (cell == null) return;

    switch (cell) {
      case BlockCell():
      case ImageCell():
        return;
      case ClueCell():
        if (cell.arrows.isEmpty) return;
        final word = state.puzzle.wordById(cell.arrows.first.wordId);
        if (word == null || word.cells.isEmpty) return;
        _activateWord(word, word.cells.first);
      case AnswerCell():
        if (state.selectedCell == (row, col)) {
          _toggleDirection(row, col);
        } else {
          _selectAnswerCell(row, col);
        }
    }
  }

  void onLetterInput(String letter) {
    final sel = state.selectedCell;
    if (sel == null) return;

    final newInputs = Map<(int, int), String>.from(state.userInputs)
      ..[sel] = letter;

    // Still room to advance within the active word: step to the next cell.
    final next = _step(sel, 1);
    if (next != null) {
      emit(state.copyWith(
        userInputs: newInputs,
        selectedCell: next,
        currentDirection: _axisAt(next),
      ));
      return;
    }

    // Reached the last cell of the active word. If the word still has a gap
    // (the player skipped a cell), jump back to it; otherwise the word is done,
    // so advance to the next unfinished word. With neither, just keep the input.
    final activeWord = state.puzzle.wordById(state.activeWordId ?? '');
    if (activeWord == null) {
      emit(state.copyWith(userInputs: newInputs));
      return;
    }

    final gap = _firstEmptyCell(activeWord, newInputs);
    if (gap != null) {
      emit(state.copyWith(
        userInputs: newInputs,
        selectedCell: gap,
        currentDirection: _axisAt(gap),
      ));
      return;
    }

    final nextWord = _nextUnfinishedWord(newInputs);
    if (nextWord == null) {
      emit(state.copyWith(userInputs: newInputs));
      return;
    }

    final target = _firstEmptyCell(nextWord, newInputs) ?? nextWord.cells.first;
    _activateWord(nextWord, target, userInputs: newInputs);
  }

  void onBackspace() {
    final sel = state.selectedCell;
    if (sel == null) return;

    final newInputs = Map<(int, int), String>.from(state.userInputs);
    if (newInputs.containsKey(sel)) {
      newInputs.remove(sel);
      emit(state.copyWith(userInputs: newInputs));
    } else {
      final prev = _step(sel, -1);
      if (prev != null) {
        newInputs.remove(prev);
        emit(state.copyWith(
          userInputs: newInputs,
          selectedCell: prev,
          currentDirection: _axisAt(prev),
        ));
      }
    }
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

  /// Make [word] the active word and select [cell] within it, highlighting the
  /// whole word and pinning the direction to the word's local axis there. Pass
  /// [userInputs] to fold a just-typed letter into the same emit.
  void _activateWord(
    Word word,
    (int, int) cell, {
    Map<(int, int), String>? userInputs,
  }) {
    final index = word.cells.indexOf(cell);
    emit(state.copyWith(
      userInputs: userInputs,
      activeWordId: word.id,
      selectedCell: cell,
      currentDirection: word.axisAt(index < 0 ? 0 : index),
      highlightedCells: word.cells.toSet(),
    ));
    _raiseKeyboard();
  }

  /// The first fillable (non-seed) cell of [word] still missing input, or null
  /// when the word is fully filled.
  (int, int)? _firstEmptyCell(Word word, Map<(int, int), String> inputs) {
    for (final cell in word.cells) {
      if (_isEmptyFillable(cell, inputs)) return cell;
    }
    return null;
  }

  /// The next word after the active one (wrapping) that still has an empty
  /// fillable cell, or null when every other word is complete.
  Word? _nextUnfinishedWord(Map<(int, int), String> inputs) {
    final words = state.puzzle.words;
    if (words.isEmpty) return null;
    final start = words.indexWhere((w) => w.id == state.activeWordId);
    for (var offset = 1; offset <= words.length; offset++) {
      final word = words[(start + offset) % words.length];
      if (_firstEmptyCell(word, inputs) != null) return word;
    }
    return null;
  }

  /// Whether [cell] is an answer cell the player still needs to fill. Seed cells
  /// carry a given letter, so they never count as empty.
  bool _isEmptyFillable((int, int) cell, Map<(int, int), String> inputs) {
    final c = state.puzzle.cells[cell];
    return c is AnswerCell && !c.isSeed && !inputs.containsKey(cell);
  }

  /// Move the selection one cell in the given direction (e.g. (0, 1) for the
  /// right arrow), skipping over non-answer cells until the next answer cell.
  /// The pressed axis becomes the preferred word direction at the landing cell,
  /// so arrowing into a shared cell picks the word running along that axis.
  void moveSelection(int rowDelta, int colDelta) {
    final sel = state.selectedCell;
    if (sel == null) return;

    final axis = colDelta != 0 ? Direction.right : Direction.down;
    var (row, col) = sel;
    while (true) {
      row += rowDelta;
      col += colDelta;
      final cell = state.puzzle.cells[(row, col)];
      if (cell == null) return; // ran off the grid; keep the current selection
      if (cell is AnswerCell) {
        _selectAnswerCell(row, col, axis);
        return;
      }
    }
  }

  void _selectAnswerCell(int row, int col, [Direction? preferAxis]) {
    final axis = preferAxis ?? state.currentDirection;
    final word = state.puzzle.wordAt((row, col), axis) ??
        state.puzzle.wordAt(
          (row, col),
          axis == Direction.right ? Direction.down : Direction.right,
        );

    if (word == null) {
      emit(state.withLoneCell((row, col)));
      _raiseKeyboard();
      return;
    }

    _activateWord(word, (row, col));
  }

  void _toggleDirection(int row, int col) {
    final other = state.currentDirection == Direction.right
        ? Direction.down
        : Direction.right;
    final word = state.puzzle.wordAt((row, col), other);
    if (word != null) _activateWord(word, (row, col));
  }

  /// The active word's local axis at [cell], or the current direction if the
  /// cell is not on the active word.
  Direction _axisAt((int, int) cell) {
    final word = state.puzzle.wordById(state.activeWordId ?? '');
    if (word == null) return state.currentDirection;
    final i = word.cells.indexOf(cell);
    return i < 0 ? state.currentDirection : word.axisAt(i);
  }

  /// Step [delta] cells along the active word's ordered path from [cell],
  /// following the word through any bend; null if it would leave the word.
  (int, int)? _step((int, int) cell, int delta) {
    final word = state.puzzle.wordById(state.activeWordId ?? '');
    if (word == null) return null;
    final i = word.cells.indexOf(cell);
    if (i < 0) return null;
    final j = i + delta;
    if (j < 0 || j >= word.cells.length) return null;
    return word.cells[j];
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
