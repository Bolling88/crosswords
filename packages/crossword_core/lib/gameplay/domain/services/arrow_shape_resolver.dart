import '../entities/arrow_shape.dart';
import '../entities/direction.dart';

/// Picks the clue's arrow glyph from where its word starts relative to the
/// clue cell and which way the word travels. The start cell is adjacent to the
/// clue on one side; the word then runs in [base]. A start on the same axis as
/// travel is a straight arrow; a start on the perpendicular side is a bent
/// (L-shaped) arrow that leaves the clue toward the start and then turns.
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
    if (base == Direction.right) {
      if (dr == 0 && dc == 1) return ArrowShape.straightRight;
      if (dr == -1 && dc == 0) return ArrowShape.bentUpThenRight;
      return ArrowShape.bentDownThenRight; // start below (or fallback)
    }
    if (dr == 1 && dc == 0) return ArrowShape.straightDown;
    if (dr == 0 && dc == -1) return ArrowShape.bentLeftThenDown;
    return ArrowShape.bentRightThenDown; // start to the right (or fallback)
  }
}
