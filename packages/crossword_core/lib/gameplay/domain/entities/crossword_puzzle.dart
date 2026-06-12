import 'cell.dart';
import 'direction.dart';
import 'word.dart';

class CrosswordPuzzle {
  final int rows;
  final int cols;
  final Map<(int, int), Cell> cells;
  final List<Word> words;
  final Set<(int, int)> seedPositions;

  /// Which cell edges carry an intra-answer break: a [Direction.right] entry
  /// means a divider on that cell's right edge; [Direction.down] its bottom.
  final Map<(int, int), Set<Direction>> separatorEdges;

  final String title;
  final String languageCode;

  const CrosswordPuzzle({
    required this.rows,
    required this.cols,
    required this.cells,
    required this.words,
    required this.title,
    required this.languageCode,
    this.seedPositions = const {},
    this.separatorEdges = const {},
  });

  /// The word with [id], or null if none.
  Word? wordById(String id) {
    for (final w in words) {
      if (w.id == id) return w;
    }
    return null;
  }

  /// The word whose path runs along [direction] *through* [cell], or null.
  ///
  /// Uses each word's local axis at the cell rather than its base direction, so
  /// a redirected word's perpendicular tail and a genuine crossing word that
  /// share a cell (and a base direction) are still told apart.
  Word? wordAt((int, int) cell, Direction direction) {
    for (final w in words) {
      final index = w.cells.indexOf(cell);
      if (index >= 0 && w.axisAt(index) == direction) return w;
    }
    return null;
  }

  /// The grid position of the clue cell whose arrow starts the word with
  /// [wordId], or null if no clue points at it. Grids are small, so a linear
  /// scan at word-activation time is fine.
  (int, int)? cluePositionOf(String wordId) {
    for (final entry in cells.entries) {
      final cell = entry.value;
      if (cell is ClueCell && cell.arrows.any((a) => a.wordId == wordId)) {
        return entry.key;
      }
    }
    return null;
  }
}
