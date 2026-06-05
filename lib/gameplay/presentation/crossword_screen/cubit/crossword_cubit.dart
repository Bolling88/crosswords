import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../gameplay/domain/entities/cell.dart';
import '../../../../gameplay/domain/entities/crossword_puzzle.dart';
import '../../../../gameplay/domain/entities/direction.dart';
import '../../../../gameplay/domain/entities/word.dart';
import '../../../../settings/domain/services/font_service.dart';
import 'crossword_state.dart';

class CrosswordCubit extends Cubit<CrosswordState> {
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
    final next = _step(sel, 1) ?? sel;

    emit(state.copyWith(
      userInputs: newInputs,
      selectedCell: next,
      currentDirection: _axisAt(next),
    ));
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

  /// Make [word] the active word and select [cell] within it, highlighting the
  /// whole word and pinning the direction to the word's local axis there.
  void _activateWord(Word word, (int, int) cell) {
    final index = word.cells.indexOf(cell);
    emit(state.copyWith(
      activeWordId: word.id,
      selectedCell: cell,
      currentDirection: word.axisAt(index < 0 ? 0 : index),
      highlightedCells: word.cells.toSet(),
    ));
  }

  void _selectAnswerCell(int row, int col) {
    final word = state.puzzle.wordAt((row, col), state.currentDirection) ??
        state.puzzle.wordAt(
          (row, col),
          state.currentDirection == Direction.right
              ? Direction.down
              : Direction.right,
        );

    if (word == null) {
      emit(state.copyWith(
        selectedCell: (row, col),
        highlightedCells: {(row, col)},
      ));
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
    return super.close();
  }
}
