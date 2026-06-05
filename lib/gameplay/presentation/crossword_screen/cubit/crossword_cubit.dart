import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../gameplay/domain/entities/cell.dart';
import '../../../../gameplay/domain/entities/crossword_puzzle.dart';
import '../../../../gameplay/domain/entities/direction.dart';
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
        emit(state.copyWith(
          selectedCell: word.cells.first,
          currentDirection: word.direction,
          highlightedCells: word.cells.toSet(),
        ));
      case AnswerCell():
        if (state.selectedCell == (row, col)) {
          _toggleDirection(row, col);
        } else {
          _selectAnswerCell(row, col, state.currentDirection);
        }
    }
  }

  void onLetterInput(String letter) {
    final sel = state.selectedCell;
    if (sel == null) return;

    final newInputs = Map<(int, int), String>.from(state.userInputs)
      ..[sel] = letter;
    final next = _nextCell(sel, state.currentDirection) ?? sel;

    emit(state.copyWith(userInputs: newInputs, selectedCell: next));
  }

  void onBackspace() {
    final sel = state.selectedCell;
    if (sel == null) return;

    final newInputs = Map<(int, int), String>.from(state.userInputs);
    if (newInputs.containsKey(sel)) {
      newInputs.remove(sel);
      emit(state.copyWith(userInputs: newInputs));
    } else {
      final prev = _prevCell(sel, state.currentDirection);
      if (prev != null) {
        newInputs.remove(prev);
        emit(state.copyWith(userInputs: newInputs, selectedCell: prev));
      }
    }
  }

  void _selectAnswerCell(int row, int col, Direction direction) {
    final word = state.puzzle.wordAt((row, col), direction) ??
        state.puzzle.wordAt(
          (row, col),
          direction == Direction.right ? Direction.down : Direction.right,
        );

    if (word == null) {
      emit(state.copyWith(
        selectedCell: (row, col),
        highlightedCells: {(row, col)},
      ));
      return;
    }

    emit(state.copyWith(
      selectedCell: (row, col),
      currentDirection: word.direction,
      highlightedCells: word.cells.toSet(),
    ));
  }

  void _toggleDirection(int row, int col) {
    final other = state.currentDirection == Direction.right
        ? Direction.down
        : Direction.right;
    final word = state.puzzle.wordAt((row, col), other);
    if (word != null) {
      emit(state.copyWith(
        currentDirection: other,
        highlightedCells: word.cells.toSet(),
      ));
    }
  }

  (int, int)? _nextCell((int, int) cell, Direction direction) {
    final word = state.puzzle.wordAt(cell, direction);
    if (word == null) return null;
    final i = word.cells.indexOf(cell);
    if (i < 0 || i + 1 >= word.cells.length) return null;
    return word.cells[i + 1];
  }

  (int, int)? _prevCell((int, int) cell, Direction direction) {
    final word = state.puzzle.wordAt(cell, direction);
    if (word == null) return null;
    final i = word.cells.indexOf(cell);
    if (i <= 0) return null;
    return word.cells[i - 1];
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
