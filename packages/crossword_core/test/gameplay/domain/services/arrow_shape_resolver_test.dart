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
  });
}
