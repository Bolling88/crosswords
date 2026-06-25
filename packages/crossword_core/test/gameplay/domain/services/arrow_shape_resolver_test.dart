import 'package:crossword_core/crossword_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ArrowShapeResolver', () {
    test('start directly right of clue, running right → straightRight', () {
      expect(
        ArrowShapeResolver.resolve(
          clueRow: 0, clueCol: 0, startRow: 0, startCol: 1,
          base: Direction.right,
        ),
        ArrowShape.straightRight,
      );
    });

    test('start below clue, running right → bentDownThenRight', () {
      expect(
        ArrowShapeResolver.resolve(
          clueRow: 0, clueCol: 0, startRow: 1, startCol: 0,
          base: Direction.right,
        ),
        ArrowShape.bentDownThenRight,
      );
    });

    test('start below clue, running down → straightDown', () {
      expect(
        ArrowShapeResolver.resolve(
          clueRow: 0, clueCol: 0, startRow: 1, startCol: 0,
          base: Direction.down,
        ),
        ArrowShape.straightDown,
      );
    });

    test('start left of clue, running down → bentLeftThenDown', () {
      expect(
        ArrowShapeResolver.resolve(
          clueRow: 0, clueCol: 1, startRow: 0, startCol: 0,
          base: Direction.down,
        ),
        ArrowShape.bentLeftThenDown,
      );
    });

    // Diagonal-entry cases taken from the real 9x9 generation fixture.
    test('start diagonally SW of clue, running right → diagonalSwThenRight', () {
      expect(
        ArrowShapeResolver.resolve(
          clueRow: 0, clueCol: 7, startRow: 1, startCol: 6,
          base: Direction.right,
        ),
        ArrowShape.diagonalSwThenRight,
      );
    });

    test('start diagonally SW of clue, running down → diagonalSwThenDown', () {
      expect(
        ArrowShapeResolver.resolve(
          clueRow: 0, clueCol: 4, startRow: 1, startCol: 3,
          base: Direction.down,
        ),
        ArrowShape.diagonalSwThenDown,
      );
    });

    test('start diagonally NW of clue, running down → diagonalNwThenDown', () {
      expect(
        ArrowShapeResolver.resolve(
          clueRow: 5, clueCol: 7, startRow: 4, startCol: 6,
          base: Direction.down,
        ),
        ArrowShape.diagonalNwThenDown,
      );
    });

    test('non-adjacent, non-diagonal start throws ArgumentError', () {
      expect(
        () => ArrowShapeResolver.resolve(
          clueRow: 0, clueCol: 0, startRow: 2, startCol: 0,
          base: Direction.right,
        ),
        throwsArgumentError,
      );
    });
  });
}
