import '../entities/arrow_shape.dart';
import '../entities/direction.dart';

/// Picks the clue's arrow glyph from where its word starts relative to the
/// clue cell and which way the word travels. The start cell is adjacent (or
/// diagonally adjacent) to the clue; the word then runs in [base]. A start on
/// the same axis as travel is a straight arrow; a start on the perpendicular
/// side is a bent (L-shaped) arrow; a diagonally adjacent start yields one of
/// the eight diagonal shapes. Any other geometry throws [ArgumentError].
class ArrowShapeResolver {
  const ArrowShapeResolver._();

  static ArrowShape resolve({
    required int clueRow,
    required int clueCol,
    required int startRow,
    required int startCol,
    required Direction base,
  }) {
    final dr = startRow - clueRow;
    final dc = startCol - clueCol;

    // Diagonal start: the clue sits at a corner of the word's start cell.
    if (dr.abs() == 1 && dc.abs() == 1) {
      return _diagonal(dr, dc, base);
    }

    if (base == Direction.right) {
      if (dr == 0 && dc == 1) return ArrowShape.straightRight;
      if (dr == -1 && dc == 0) return ArrowShape.bentUpThenRight;
      if (dr == 1 && dc == 0) return ArrowShape.bentDownThenRight;
      throw ArgumentError(
        'Rightward word start ($dr,$dc) is not adjacent to its clue',
      );
    }
    if (dr == 1 && dc == 0) return ArrowShape.straightDown;
    if (dr == 0 && dc == -1) return ArrowShape.bentLeftThenDown;
    if (dr == 0 && dc == 1) return ArrowShape.bentRightThenDown;
    throw ArgumentError(
      'Downward word start ($dr,$dc) is not adjacent to its clue',
    );
  }

  /// Maps a diagonal start offset (start − clue) and travel direction to the
  /// matching diagonal shape. Corner names describe where the start cell sits:
  /// dr=+1 below (S), dr=-1 above (N); dc=+1 right (E), dc=-1 left (W).
  static ArrowShape _diagonal(int dr, int dc, Direction base) {
    if (base == Direction.right) {
      if (dr == 1 && dc == -1) return ArrowShape.diagonalSwThenRight;
      if (dr == -1 && dc == -1) return ArrowShape.diagonalNwThenRight;
      if (dr == 1 && dc == 1) return ArrowShape.diagonalSeThenRight;
      return ArrowShape.diagonalNeThenRight; // dr == -1 && dc == 1
    }
    if (dr == 1 && dc == -1) return ArrowShape.diagonalSwThenDown;
    if (dr == -1 && dc == -1) return ArrowShape.diagonalNwThenDown;
    if (dr == 1 && dc == 1) return ArrowShape.diagonalSeThenDown;
    return ArrowShape.diagonalNeThenDown; // dr == -1 && dc == 1
  }
}
