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

    test('diagonalNwThenDown enters toward NW and reads down', () {
      final v = clueArrowVectors(ArrowShape.diagonalNwThenDown);
      expect(v.entry, const Offset(-1, -1));
      expect(v.travel, const Offset(0, 1));
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

  group('clueArrowSpine', () {
    test('straight has 2 points, bent/diagonal have 3', () {
      expect(clueArrowSpine(ArrowShape.straightRight).length, 2);
      expect(clueArrowSpine(ArrowShape.bentDownThenRight).length, 3);
      expect(clueArrowSpine(ArrowShape.diagonalNwThenDown).length, 3);
    });

    test('final segment runs in the travel direction (right)', () {
      final spine = clueArrowSpine(ArrowShape.diagonalSwThenRight);
      final tip = spine.last;
      final prev = spine[spine.length - 2];
      expect(tip.dx > prev.dx, isTrue);
      expect((tip.dy - prev.dy).abs() < 1e-9, isTrue);
    });

    test('final segment runs in the travel direction (down)', () {
      final spine = clueArrowSpine(ArrowShape.diagonalNeThenDown);
      final tip = spine.last;
      final prev = spine[spine.length - 2];
      expect(tip.dy > prev.dy, isTrue);
      expect((tip.dx - prev.dx).abs() < 1e-9, isTrue);
    });

    test('all points stay within the unit square', () {
      for (final shape in ArrowShape.values) {
        for (final p in clueArrowSpine(shape)) {
          expect(p.dx, inInclusiveRange(0.0, 1.0));
          expect(p.dy, inInclusiveRange(0.0, 1.0));
        }
      }
    });
  });
}
