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

  group('clueArrowIsImplied', () {
    test('straight shapes are implied (no glyph drawn)', () {
      expect(clueArrowIsImplied(ArrowShape.straightRight), isTrue);
      expect(clueArrowIsImplied(ArrowShape.straightDown), isTrue);
    });

    test('only the two straight shapes are implied', () {
      final drawn =
          ArrowShape.values.where((s) => !clueArrowIsImplied(s)).toSet();
      expect(drawn, contains(ArrowShape.bentDownThenRight));
      expect(drawn, contains(ArrowShape.diagonalNwThenDown));
      expect(drawn.length, ArrowShape.values.length - 2);
    });
  });

  group('startArrowSpine', () {
    test('has three points: tail (clue side), elbow, tip (travel)', () {
      expect(startArrowSpine(ArrowShape.bentDownThenRight).length, 3);
      expect(startArrowSpine(ArrowShape.diagonalNwThenDown).length, 3);
    });

    test('the tail sits on the clue side (opposite the entry vector)', () {
      // bentDownThenRight: entry is (0,1), so the clue is above → tail near top.
      final spine = startArrowSpine(ArrowShape.bentDownThenRight);
      expect(spine.first.dy < 0.5, isTrue);
    });

    test('the final segment runs in the travel direction (right)', () {
      final spine = startArrowSpine(ArrowShape.bentDownThenRight);
      final tip = spine.last;
      final prev = spine[spine.length - 2];
      expect(tip.dx > prev.dx, isTrue);
      expect((tip.dy - prev.dy).abs() < 1e-9, isTrue);
    });

    test('the final segment runs in the travel direction (down)', () {
      final spine = startArrowSpine(ArrowShape.bentRightThenDown);
      final tip = spine.last;
      final prev = spine[spine.length - 2];
      expect(tip.dy > prev.dy, isTrue);
      expect((tip.dx - prev.dx).abs() < 1e-9, isTrue);
    });

    test('all points stay within the unit square', () {
      for (final shape in ArrowShape.values) {
        for (final p in startArrowSpine(shape)) {
          expect(p.dx, inInclusiveRange(0.0, 1.0));
          expect(p.dy, inInclusiveRange(0.0, 1.0));
        }
      }
    });
  });
}
