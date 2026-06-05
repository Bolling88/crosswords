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

  /// The word running [direction] that contains [cell], or null.
  Word? wordAt((int, int) cell, Direction direction) {
    for (final w in words) {
      if (w.direction == direction && w.cells.contains(cell)) return w;
    }
    return null;
  }
}
