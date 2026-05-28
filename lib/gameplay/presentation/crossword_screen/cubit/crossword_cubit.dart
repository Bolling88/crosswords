import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../gameplay/data/entities/cell.dart';
import '../../../../gameplay/data/entities/crossword_puzzle.dart';
import '../../../../gameplay/data/entities/direction.dart';
import 'crossword_state.dart';

class CrosswordCubit extends Cubit<CrosswordState> {
  final FocusNode focusNode = FocusNode();

  CrosswordCubit({required CrosswordPuzzle puzzle})
      : super(CrosswordState(puzzle: puzzle));

  void selectCell(int row, int col) {
    final cell = state.puzzle.cells[(row, col)];
    if (cell == null) return;

    switch (cell) {
      case BlockedCell():
      case ImageCell():
        return;
      case HintCell():
        final dir = cell.arrows.first;
        final (nr, nc) = _advance(row, col, dir);
        if (state.puzzle.cells[(nr, nc)] is AnswerCell) {
          _selectAnswerCell(nr, nc, dir);
        }
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

    final newInputs = Map<(int, int), String>.from(state.userInputs);
    newInputs[sel] = letter;

    final next = _findNextAnswerCell(sel.$1, sel.$2, state.currentDirection);
    final target = next ?? sel;

    emit(state.copyWith(
      userInputs: newInputs,
      selectedCell: target,
      highlightedCells: _computeWord(target.$1, target.$2, state.currentDirection),
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
      final prev = _findPrevAnswerCell(sel.$1, sel.$2, state.currentDirection);
      if (prev != null) {
        newInputs.remove(prev);
        emit(state.copyWith(
          userInputs: newInputs,
          selectedCell: prev,
          highlightedCells:
              _computeWord(prev.$1, prev.$2, state.currentDirection),
        ));
      }
    }
  }

  void _selectAnswerCell(int row, int col, Direction direction) {
    var highlighted = _computeWord(row, col, direction);
    if (highlighted.length < 2) {
      final otherDir =
          direction == Direction.right ? Direction.down : Direction.right;
      final otherHighlighted = _computeWord(row, col, otherDir);
      if (otherHighlighted.length >= 2) {
        direction = otherDir;
        highlighted = otherHighlighted;
      }
    }

    emit(state.copyWith(
      selectedCell: (row, col),
      currentDirection: direction,
      highlightedCells: highlighted,
    ));
  }

  void _toggleDirection(int row, int col) {
    final otherDir = state.currentDirection == Direction.right
        ? Direction.down
        : Direction.right;
    final otherHighlighted = _computeWord(row, col, otherDir);
    if (otherHighlighted.length >= 2) {
      emit(state.copyWith(
        currentDirection: otherDir,
        highlightedCells: otherHighlighted,
      ));
    }
  }

  Set<(int, int)> _computeWord(int row, int col, Direction direction) {
    final cells = <(int, int)>{(row, col)};
    var (r, c) = (row, col);
    while (true) {
      final (nr, nc) = _advance(r, c, direction);
      if (state.puzzle.cells[(nr, nc)] is! AnswerCell) break;
      cells.add((nr, nc));
      (r, c) = (nr, nc);
    }
    (r, c) = (row, col);
    while (true) {
      final (nr, nc) = _retreat(r, c, direction);
      if (state.puzzle.cells[(nr, nc)] is! AnswerCell) break;
      cells.add((nr, nc));
      (r, c) = (nr, nc);
    }
    return cells;
  }

  (int, int) _advance(int row, int col, Direction direction) {
    return switch (direction) {
      Direction.right => (row, col + 1),
      Direction.down => (row + 1, col),
      Direction.downRight => (row + 1, col + 1),
    };
  }

  (int, int) _retreat(int row, int col, Direction direction) {
    return switch (direction) {
      Direction.right => (row, col - 1),
      Direction.down => (row - 1, col),
      Direction.downRight => (row - 1, col - 1),
    };
  }

  (int, int)? _findNextAnswerCell(int row, int col, Direction direction) {
    final (nr, nc) = _advance(row, col, direction);
    if (state.puzzle.cells[(nr, nc)] is AnswerCell) return (nr, nc);
    return null;
  }

  (int, int)? _findPrevAnswerCell(int row, int col, Direction direction) {
    final (nr, nc) = _retreat(row, col, direction);
    if (state.puzzle.cells[(nr, nc)] is AnswerCell) return (nr, nc);
    return null;
  }

  @override
  Future<void> close() {
    focusNode.dispose();
    return super.close();
  }
}
