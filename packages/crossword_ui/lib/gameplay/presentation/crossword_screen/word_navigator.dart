import 'package:crossword_core/crossword_core.dart';

/// Pure word-scanning and navigation queries over a resolved [CrosswordPuzzle].
///
/// Extracted from `CrosswordEngine` so the grid-traversal logic — stepping
/// along a word, finding gaps, picking the next unfinished word, and the
/// fill/solve/lock predicates — can be reasoned about and tested in isolation,
/// independent of `CrosswordState` and the action handlers that mutate it.
/// Every method is stateless and Flutter-free, taking only the puzzle plus the
/// plain inputs/revealed/active values it needs.
class WordNavigator {
  const WordNavigator();

  /// Step [delta] cells along [word]'s ordered path from [cell], following the
  /// word through any bend; null if it would leave the word (or [cell] is not
  /// on it).
  (int, int)? step(Word word, (int, int) cell, int delta) {
    final i = word.cells.indexOf(cell);
    if (i < 0) return null;
    final j = i + delta;
    if (j < 0 || j >= word.cells.length) return null;
    return word.cells[j];
  }

  /// [word]'s local axis at [cell], or [fallback] when [cell] is not on [word]
  /// (or [word] is null).
  Direction axisAt(Word? word, (int, int) cell, Direction fallback) {
    if (word == null) return fallback;
    final i = word.cells.indexOf(cell);
    return i < 0 ? fallback : word.axisAt(i);
  }

  /// The first fillable (non-seed) cell of [word] still missing input, or null
  /// when the word is fully filled.
  (int, int)? firstEmptyCell(
    CrosswordPuzzle puzzle,
    Word word,
    Map<(int, int), String> inputs,
  ) {
    for (final cell in word.cells) {
      if (isEmptyFillable(puzzle, cell, inputs)) return cell;
    }
    return null;
  }

  /// The next word after [activeWordId] (wrapping) that still has an empty
  /// fillable cell, or null when every other word is complete.
  Word? nextUnfinishedWord(
    CrosswordPuzzle puzzle,
    String? activeWordId,
    Map<(int, int), String> inputs,
  ) {
    final words = puzzle.words;
    if (words.isEmpty) return null;
    final start = words.indexWhere((w) => w.id == activeWordId);
    for (var offset = 1; offset <= words.length; offset++) {
      final word = words[(start + offset) % words.length];
      if (firstEmptyCell(puzzle, word, inputs) != null) return word;
    }
    return null;
  }

  /// Whether [cell] is an answer cell the player still needs to fill. Seed cells
  /// carry a given letter, so they never count as empty.
  bool isEmptyFillable(
    CrosswordPuzzle puzzle,
    (int, int) cell,
    Map<(int, int), String> inputs,
  ) {
    final c = puzzle.cells[cell];
    return c is AnswerCell && !c.isSeed && !inputs.containsKey(cell);
  }

  /// Whether [word] is fully filled with correct letters under [inputs].
  /// (A missing letter never equals the solution, so this implies filled.)
  bool isWordCorrect(
    CrosswordPuzzle puzzle,
    Word word,
    Map<(int, int), String> inputs,
  ) {
    for (final pos in word.cells) {
      final cell = puzzle.cells[pos];
      if (cell is AnswerCell && !cell.isSeed && inputs[pos] != cell.value) {
        return false;
      }
    }
    return true;
  }

  /// Whether [cell] can no longer be edited: seeds are given by the puzzle,
  /// revealed cells are given by the player asking for them.
  bool isLocked(
    CrosswordPuzzle puzzle,
    (int, int) cell,
    Set<(int, int)> revealedCells,
  ) {
    final c = puzzle.cells[cell];
    return (c is AnswerCell && c.isSeed) || revealedCells.contains(cell);
  }

  /// Whether every fillable cell has input — right or wrong.
  bool isFilled(CrosswordPuzzle puzzle, Map<(int, int), String> inputs) {
    for (final entry in puzzle.cells.entries) {
      final cell = entry.value;
      if (cell is AnswerCell && !cell.isSeed && !inputs.containsKey(entry.key)) {
        return false;
      }
    }
    return true;
  }

  /// Whether [inputs] solve the puzzle: every fillable cell holds its solution
  /// letter. Seeds are given-correct; separators never affect validation (per
  /// the JSON format spec).
  bool isSolved(CrosswordPuzzle puzzle, Map<(int, int), String> inputs) {
    for (final entry in puzzle.cells.entries) {
      final cell = entry.value;
      if (cell is AnswerCell &&
          !cell.isSeed &&
          inputs[entry.key] != cell.value) {
        return false;
      }
    }
    return true;
  }
}
