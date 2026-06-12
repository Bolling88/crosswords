import 'package:crossword_core/crossword_core.dart';

import 'cubit/crossword_state.dart';

/// Pure crossword-solving logic, extracted from `CrosswordCubit`. Stateless and
/// Flutter-free: every method takes the current [CrosswordState] plus an action
/// and returns the next state with the logic fields updated (selection, active
/// word, direction, inputs, and the active word's highlighted cells). It never
/// touches the keyboard, fonts, controllers, or `emit`; the Cubit owns those.
/// `font` is carried through untouched via [CrosswordState.copyWith].
class CrosswordEngine {
  const CrosswordEngine();

  /// Select the cell at [row],[col]: activate a clue's word, (re)select an
  /// answer cell, or toggle direction when re-selecting the current cell.
  CrosswordState selectCell(CrosswordState state, int row, int col) {
    final cell = state.puzzle.cells[(row, col)];
    if (cell == null) return state;

    switch (cell) {
      case BlockCell():
      case ImageCell():
        return state;
      case ClueCell():
        if (cell.arrows.isEmpty) return state;
        final word = state.puzzle.wordById(cell.arrows.first.wordId);
        if (word == null || word.cells.isEmpty) return state;
        return _activateWord(state, word, word.cells.first);
      case AnswerCell():
        if (state.selectedCell == (row, col)) {
          return _toggleDirection(state, row, col);
        }
        return _selectAnswerCell(state, row, col);
    }
  }

  /// Record [letter] at the selected cell and advance: to the next cell of the
  /// active word, back to a skipped gap, or on to the next unfinished word.
  /// Seeds and revealed cells are locked — typing on them advances without
  /// writing. With [autocheck], a wrong letter is marked immediately and a
  /// word completed correctly is confirmed (driving the grid flash).
  CrosswordState inputLetter(
    CrosswordState state,
    String letter, {
    bool autocheck = false,
  }) {
    final sel = state.selectedCell;
    if (sel == null) return state;

    var inputs = state.userInputs;
    var incorrect = state.incorrectCells;
    if (!_isLocked(state, sel)) {
      inputs = Map<(int, int), String>.from(inputs)..[sel] = letter;
      incorrect = Set<(int, int)>.from(incorrect)..remove(sel);
      final cell = state.puzzle.cells[sel];
      if (autocheck && cell is AnswerCell && cell.value != letter) {
        incorrect.add(sel);
      }
    }

    var next = _advanceAfterInput(state, sel, inputs).copyWith(
      incorrectCells: incorrect,
      isSolved: computeSolved(state, inputs),
    );

    if (autocheck) {
      final word = state.puzzle.wordById(state.activeWordId ?? '');
      if (word != null && _isWordCorrect(state, word, inputs)) {
        next = next.withConfirmedWord(word.id);
      }
    }
    return next;
  }

  /// Advance after [sel] was acted on with [inputs] now in effect: step within
  /// the active word, jump back to a skipped gap, or move on to the next
  /// unfinished word — folding [inputs] into every branch.
  CrosswordState _advanceAfterInput(
    CrosswordState state,
    (int, int) sel,
    Map<(int, int), String> inputs,
  ) {
    // Still room to advance within the active word: step to the next cell.
    final next = _step(state, sel, 1);
    if (next != null) {
      return state.copyWith(
        userInputs: inputs,
        selectedCell: next,
        currentDirection: _axisAt(state, next),
      );
    }

    // Reached the last cell of the active word. If the word still has a gap
    // (the player skipped a cell), jump back to it; otherwise the word is done,
    // so advance to the next unfinished word. With neither, just keep the input.
    final activeWord = state.puzzle.wordById(state.activeWordId ?? '');
    if (activeWord == null) {
      return state.copyWith(userInputs: inputs);
    }

    final gap = _firstEmptyCell(state, activeWord, inputs);
    if (gap != null) {
      return state.copyWith(
        userInputs: inputs,
        selectedCell: gap,
        currentDirection: _axisAt(state, gap),
      );
    }

    final nextWord = _nextUnfinishedWord(state, inputs);
    if (nextWord == null) {
      return state.copyWith(userInputs: inputs);
    }

    final target =
        _firstEmptyCell(state, nextWord, inputs) ?? nextWord.cells.first;
    return _activateWord(state, nextWord, target, userInputs: inputs);
  }

  /// Mark the active word's wrong letters. Correct and empty cells are left
  /// (or become) unmarked; a fully correct word is confirmed for the flash.
  CrosswordState checkWord(CrosswordState state) {
    final word = state.puzzle.wordById(state.activeWordId ?? '');
    if (word == null) return state;
    return _checkCells(state, word.cells);
  }

  /// Mark wrong letters across the whole grid.
  CrosswordState checkPuzzle(CrosswordState state) {
    return _checkCells(state, state.puzzle.cells.keys);
  }

  /// Re-mark [cells]: filled wrong letters join `incorrectCells`, everything
  /// else leaves it. Confirms the active word when it stands fully correct.
  CrosswordState _checkCells(CrosswordState state, Iterable<(int, int)> cells) {
    final incorrect = Set<(int, int)>.from(state.incorrectCells);
    for (final pos in cells) {
      final cell = state.puzzle.cells[pos];
      if (cell is! AnswerCell || cell.isSeed) continue;
      final input = state.userInputs[pos];
      if (input != null && input != cell.value) {
        incorrect.add(pos);
      } else {
        incorrect.remove(pos);
      }
    }

    var next = state.copyWith(incorrectCells: incorrect);
    final word = state.puzzle.wordById(state.activeWordId ?? '');
    if (word != null && _isWordCorrect(state, word, state.userInputs)) {
      next = next.withConfirmedWord(word.id);
    }
    return next;
  }

  /// Fill the selected cell with its solution letter and lock it, advancing
  /// as if the letter had been typed.
  CrosswordState revealCell(CrosswordState state) {
    final sel = state.selectedCell;
    if (sel == null) return state;
    final cell = state.puzzle.cells[sel];
    if (cell is! AnswerCell || _isLocked(state, sel)) return state;

    final inputs = Map<(int, int), String>.from(state.userInputs)
      ..[sel] = cell.value;
    final revealed = Set<(int, int)>.from(state.revealedCells)..add(sel);
    final incorrect = Set<(int, int)>.from(state.incorrectCells)..remove(sel);
    return _advanceAfterInput(state, sel, inputs).copyWith(
      revealedCells: revealed,
      incorrectCells: incorrect,
      isSolved: computeSolved(state, inputs),
    );
  }

  /// Fill and lock the whole active word, confirm it for the flash, and move
  /// on to the next unfinished word.
  CrosswordState revealWord(CrosswordState state) {
    final word = state.puzzle.wordById(state.activeWordId ?? '');
    if (word == null) return state;

    final inputs = Map<(int, int), String>.from(state.userInputs);
    final revealed = Set<(int, int)>.from(state.revealedCells);
    final incorrect = Set<(int, int)>.from(state.incorrectCells);
    for (final pos in word.cells) {
      final cell = state.puzzle.cells[pos];
      if (cell is! AnswerCell || cell.isSeed) continue;
      inputs[pos] = cell.value;
      revealed.add(pos);
      incorrect.remove(pos);
    }

    var next = state
        .copyWith(
          userInputs: inputs,
          revealedCells: revealed,
          incorrectCells: incorrect,
          isSolved: computeSolved(state, inputs),
        )
        .withConfirmedWord(word.id);

    final nextWord = _nextUnfinishedWord(next, inputs);
    if (nextWord == null) return next;
    final target =
        _firstEmptyCell(next, nextWord, inputs) ?? nextWord.cells.first;
    return _activateWord(next, nextWord, target);
  }

  /// Whether [word] is fully filled with correct letters under [inputs].
  /// (A missing letter never equals the solution, so this implies filled.)
  bool _isWordCorrect(
    CrosswordState state,
    Word word,
    Map<(int, int), String> inputs,
  ) {
    for (final pos in word.cells) {
      final cell = state.puzzle.cells[pos];
      if (cell is AnswerCell && !cell.isSeed && inputs[pos] != cell.value) {
        return false;
      }
    }
    return true;
  }

  /// Whether [cell] can no longer be edited: seeds are given by the puzzle,
  /// revealed cells are given by the player asking for them.
  bool _isLocked(CrosswordState state, (int, int) cell) {
    final c = state.puzzle.cells[cell];
    return (c is AnswerCell && c.isSeed) || state.revealedCells.contains(cell);
  }

  /// Delete the selected cell's letter (and its incorrect mark), or step back
  /// and delete the previous cell's letter when the selected cell is already
  /// empty. Seeds and revealed cells are never cleared — stepping back onto
  /// one just moves the selection.
  CrosswordState backspace(CrosswordState state) {
    final sel = state.selectedCell;
    if (sel == null) return state;

    if (!_isLocked(state, sel) && state.userInputs.containsKey(sel)) {
      return _clearCell(state, sel);
    }

    final prev = _step(state, sel, -1);
    if (prev == null) return state;
    if (_isLocked(state, prev)) {
      return state.copyWith(
        selectedCell: prev,
        currentDirection: _axisAt(state, prev),
      );
    }
    return _clearCell(state, prev).copyWith(
      selectedCell: prev,
      currentDirection: _axisAt(state, prev),
    );
  }

  /// Remove [cell]'s input and incorrect mark, recomputing solved state.
  CrosswordState _clearCell(CrosswordState state, (int, int) cell) {
    final inputs = Map<(int, int), String>.from(state.userInputs)..remove(cell);
    final incorrect = Set<(int, int)>.from(state.incorrectCells)..remove(cell);
    return state.copyWith(
      userInputs: inputs,
      incorrectCells: incorrect,
      isSolved: computeSolved(state, inputs),
    );
  }

  /// Move the selection one cell in the given direction (e.g. (0, 1) for the
  /// right arrow), skipping over non-answer cells until the next answer cell.
  /// The pressed axis becomes the preferred word direction at the landing cell.
  CrosswordState moveSelection(CrosswordState state, int rowDelta, int colDelta) {
    final sel = state.selectedCell;
    if (sel == null) return state;

    final axis = colDelta != 0 ? Direction.right : Direction.down;
    var (row, col) = sel;
    while (true) {
      row += rowDelta;
      col += colDelta;
      final cell = state.puzzle.cells[(row, col)];
      if (cell == null) return state; // ran off the grid; keep the selection
      if (cell is AnswerCell) {
        return _selectAnswerCell(state, row, col, axis);
      }
    }
  }

  /// Select the answer cell at [row],[col], activating the word that runs along
  /// [preferAxis] (or the current direction), falling back to the crossing word,
  /// or a lone-cell selection when the cell belongs to no word.
  CrosswordState _selectAnswerCell(
    CrosswordState state,
    int row,
    int col, [
    Direction? preferAxis,
  ]) {
    final axis = preferAxis ?? state.currentDirection;
    final word = state.puzzle.wordAt((row, col), axis) ??
        state.puzzle.wordAt(
          (row, col),
          axis == Direction.right ? Direction.down : Direction.right,
        );

    if (word == null) {
      return state.withLoneCell((row, col));
    }
    return _activateWord(state, word, (row, col));
  }

  /// Re-select the current cell along its other axis, switching to the crossing
  /// word there. No change when no word runs the other way.
  CrosswordState _toggleDirection(CrosswordState state, int row, int col) {
    final other = state.currentDirection == Direction.right
        ? Direction.down
        : Direction.right;
    final word = state.puzzle.wordAt((row, col), other);
    if (word == null) return state;
    return _activateWord(state, word, (row, col));
  }

  /// Whether every fillable cell has input — right or wrong.
  bool isFilled(CrosswordState state) {
    for (final entry in state.puzzle.cells.entries) {
      final cell = entry.value;
      if (cell is AnswerCell &&
          !cell.isSeed &&
          !state.userInputs.containsKey(entry.key)) {
        return false;
      }
    }
    return true;
  }

  /// Whether [inputs] solve the puzzle: every fillable cell holds its
  /// solution letter. Seeds are given-correct; separators never affect
  /// validation (per the JSON format spec).
  bool computeSolved(CrosswordState state, Map<(int, int), String> inputs) {
    for (final entry in state.puzzle.cells.entries) {
      final cell = entry.value;
      if (cell is AnswerCell && !cell.isSeed && inputs[entry.key] != cell.value) {
        return false;
      }
    }
    return true;
  }

  /// Make [word] the active word and select [cell] within it, highlighting the
  /// whole word (including its clue cell) and pinning the direction to the
  /// word's local axis there. Pass [userInputs] to fold a just-typed letter
  /// into the same result.
  CrosswordState _activateWord(
    CrosswordState state,
    Word word,
    (int, int) cell, {
    Map<(int, int), String>? userInputs,
  }) {
    final index = word.cells.indexOf(cell);
    return state.withActiveWord(
      wordId: word.id,
      selectedCell: cell,
      direction: word.axisAt(index < 0 ? 0 : index),
      highlightedCells: word.cells.toSet(),
      clueCell: state.puzzle.cluePositionOf(word.id),
      userInputs: userInputs,
    );
  }

  /// The first fillable (non-seed) cell of [word] still missing input, or null
  /// when the word is fully filled.
  (int, int)? _firstEmptyCell(
    CrosswordState state,
    Word word,
    Map<(int, int), String> inputs,
  ) {
    for (final cell in word.cells) {
      if (_isEmptyFillable(state, cell, inputs)) return cell;
    }
    return null;
  }

  /// The next word after the active one (wrapping) that still has an empty
  /// fillable cell, or null when every other word is complete.
  Word? _nextUnfinishedWord(
    CrosswordState state,
    Map<(int, int), String> inputs,
  ) {
    final words = state.puzzle.words;
    if (words.isEmpty) return null;
    final start = words.indexWhere((w) => w.id == state.activeWordId);
    for (var offset = 1; offset <= words.length; offset++) {
      final word = words[(start + offset) % words.length];
      if (_firstEmptyCell(state, word, inputs) != null) return word;
    }
    return null;
  }

  /// Whether [cell] is an answer cell the player still needs to fill. Seed cells
  /// carry a given letter, so they never count as empty.
  bool _isEmptyFillable(
    CrosswordState state,
    (int, int) cell,
    Map<(int, int), String> inputs,
  ) {
    final c = state.puzzle.cells[cell];
    return c is AnswerCell && !c.isSeed && !inputs.containsKey(cell);
  }

  /// The active word's local axis at [cell], or the current direction if the
  /// cell is not on the active word.
  Direction _axisAt(CrosswordState state, (int, int) cell) {
    final word = state.puzzle.wordById(state.activeWordId ?? '');
    if (word == null) return state.currentDirection;
    final i = word.cells.indexOf(cell);
    return i < 0 ? state.currentDirection : word.axisAt(i);
  }

  /// Step [delta] cells along the active word's ordered path from [cell],
  /// following the word through any bend; null if it would leave the word.
  (int, int)? _step(CrosswordState state, (int, int) cell, int delta) {
    final word = state.puzzle.wordById(state.activeWordId ?? '');
    if (word == null) return null;
    final i = word.cells.indexOf(cell);
    if (i < 0) return null;
    final j = i + delta;
    if (j < 0 || j >= word.cells.length) return null;
    return word.cells[j];
  }
}
