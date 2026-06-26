import 'package:flutter_test/flutter_test.dart';

import 'package:crossword_core/crossword_core.dart';
import 'package:crossword_ui/gameplay/presentation/crossword_screen/widgets/clue_arrow_painter.dart';

void main() {
  group('clueArrowVectors', () {
    test('straightRight enters and reads right', () {
      final v = clueArrowVectors(ArrowShape.straightRight);
      expect(v.entry, const Offset(1, 0));
      expect(v.travel, const Offset(1, 0));
    });

    test('diagonalSwThenRight enters toward SW and reads right', () {
      final v = clueArrowVectors(ArrowShape.diagonalSwThenRight);
      expect(v.entry, const Offset(-1, 1));
      expect(v.travel, const Offset(1, 0));
    });

    test('every shape reads in a cardinal direction', () {
      for (final shape in ArrowShape.values) {
        final travel = clueArrowVectors(shape).travel;
        expect(
          travel == const Offset(1, 0) || travel == const Offset(0, 1),
          isTrue,
          reason: '$shape',
        );
      }
    });
  });

  group('clueBoundaryArrowSpine', () {
    const origin = Offset.zero;
    const cellSize = 10.0;

    List<Offset> spine(ArrowShape shape) => clueBoundaryArrowSpine(
      shape: shape,
      clueCellOrigin: origin,
      cellSize: cellSize,
    );

    test('straight arrows have two points and bent arrows have three', () {
      expect(spine(ArrowShape.straightRight).length, 2);
      expect(spine(ArrowShape.straightDown).length, 2);
      expect(spine(ArrowShape.bentDownThenRight).length, 3);
      expect(spine(ArrowShape.diagonalNwThenDown).length, 3);
    });

    test('straight right exits from the right edge', () {
      final points = spine(ArrowShape.straightRight);
      expect(points.first, const Offset(10, 5));
      expect(points.last.dx > cellSize, isTrue);
      expect((points.last.dy - points.first.dy).abs() < 1e-9, isTrue);
    });

    test('straight down exits from the bottom edge', () {
      final points = spine(ArrowShape.straightDown);
      expect(points.first, const Offset(5, 10));
      expect(points.last.dy > cellSize, isTrue);
      expect((points.last.dx - points.first.dx).abs() < 1e-9, isTrue);
    });

    test('bent arrow exits at the answer edge then turns right', () {
      final points = spine(ArrowShape.bentDownThenRight);
      expect(points.first, const Offset(5, 10));
      final tip = points.last;
      final prev = points[points.length - 2];
      expect(tip.dx > prev.dx, isTrue);
      expect((tip.dy - prev.dy).abs() < 1e-9, isTrue);
    });

    test('bent arrow exits at the answer edge then turns down', () {
      final points = spine(ArrowShape.bentRightThenDown);
      expect(points.first, const Offset(10, 5));
      final tip = points.last;
      final prev = points[points.length - 2];
      expect(tip.dy > prev.dy, isTrue);
      expect((tip.dx - prev.dx).abs() < 1e-9, isTrue);
    });

    test('all arrows exit from an edge or corner of the clue cell', () {
      for (final shape in ArrowShape.values) {
        final exit = spine(shape).first;
        final onVerticalEdge = exit.dx == 0 || exit.dx == cellSize;
        final onHorizontalEdge = exit.dy == 0 || exit.dy == cellSize;
        expect(onVerticalEdge || onHorizontalEdge, isTrue, reason: '$shape');
      }
    });

    test('diagonal clues exit from the matching corner', () {
      expect(spine(ArrowShape.diagonalSwThenRight).first, const Offset(0, 10));
      expect(spine(ArrowShape.diagonalNeThenDown).first, const Offset(10, 0));
    });

    test('orthogonal bent clues include an elbow before the tip', () {
      final points = spine(ArrowShape.bentDownThenRight);
      expect(points[1], isNot(points.first));
      expect(points[1], isNot(points.last));
    });
  });
}
