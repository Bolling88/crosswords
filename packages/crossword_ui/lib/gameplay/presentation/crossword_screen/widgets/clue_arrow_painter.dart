import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'package:crossword_core/crossword_core.dart';

typedef GridClueArrow = ({int row, int col, ClueArrow arrow});

/// Direction from the clue cell toward the word's start (entry) and the
/// direction the word then reads (travel), in screen coords (+x right, +y down).
({Offset entry, Offset travel}) clueArrowVectors(ArrowShape shape) {
  switch (shape) {
    case ArrowShape.straightRight:
      return (entry: const Offset(1, 0), travel: const Offset(1, 0));
    case ArrowShape.straightDown:
      return (entry: const Offset(0, 1), travel: const Offset(0, 1));
    case ArrowShape.bentDownThenRight:
      return (entry: const Offset(0, 1), travel: const Offset(1, 0));
    case ArrowShape.bentUpThenRight:
      return (entry: const Offset(0, -1), travel: const Offset(1, 0));
    case ArrowShape.bentRightThenDown:
      return (entry: const Offset(1, 0), travel: const Offset(0, 1));
    case ArrowShape.bentLeftThenDown:
      return (entry: const Offset(-1, 0), travel: const Offset(0, 1));
    case ArrowShape.diagonalSwThenRight:
      return (entry: const Offset(-1, 1), travel: const Offset(1, 0));
    case ArrowShape.diagonalNwThenRight:
      return (entry: const Offset(-1, -1), travel: const Offset(1, 0));
    case ArrowShape.diagonalSeThenRight:
      return (entry: const Offset(1, 1), travel: const Offset(1, 0));
    case ArrowShape.diagonalNeThenRight:
      return (entry: const Offset(1, -1), travel: const Offset(1, 0));
    case ArrowShape.diagonalSwThenDown:
      return (entry: const Offset(-1, 1), travel: const Offset(0, 1));
    case ArrowShape.diagonalNwThenDown:
      return (entry: const Offset(-1, -1), travel: const Offset(0, 1));
    case ArrowShape.diagonalSeThenDown:
      return (entry: const Offset(1, 1), travel: const Offset(0, 1));
    case ArrowShape.diagonalNeThenDown:
      return (entry: const Offset(1, -1), travel: const Offset(0, 1));
  }
}

/// Arrow drawn from a clue cell boundary into the answer area, Swedish magazine
/// korsord style. Points are in canvas pixels, ordered exit edge/corner →
/// optional bend → tip. The first point is always where the arrow exits the
/// clue cell.
List<Offset> clueBoundaryArrowSpine({
  required ArrowShape shape,
  required Offset clueCellOrigin,
  required double cellSize,
}) {
  final v = clueArrowVectors(shape);
  final center = clueCellOrigin + Offset(cellSize * 0.5, cellSize * 0.5);
  final exit = center + v.entry * (cellSize * 0.5);
  final insideStart = exit + v.entry * (cellSize * 0.18);

  if (v.entry == v.travel) {
    return [exit, exit + v.travel * (cellSize * 0.28)];
  }

  return [exit, insideStart, insideStart + v.travel * (cellSize * 0.24)];
}

/// Draws clue arrows above the grid from hint boxes into their input boxes.
class ClueArrowLayerPainter extends CustomPainter {
  final List<GridClueArrow> arrows;
  final double cellSize;
  final Color color;

  const ClueArrowLayerPainter({
    required this.arrows,
    required this.cellSize,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final clueArrow in arrows) {
      final origin = Offset(clueArrow.col * cellSize, clueArrow.row * cellSize);
      _paintSpine(
        canvas,
        clueBoundaryArrowSpine(
          shape: clueArrow.arrow.shape,
          clueCellOrigin: origin,
          cellSize: cellSize,
        ),
      );
    }
  }

  void _paintSpine(Canvas canvas, List<Offset> spine) {
    final tip = spine.last;
    final prev = spine[spine.length - 2];
    final angle = math.atan2(tip.dy - prev.dy, tip.dx - prev.dx);
    final headLen = cellSize * 0.13;
    const spread = 0.36;

    final stroke = Paint()
      ..color = color
      ..strokeWidth = math.max(0.85, cellSize * 0.038)
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    final shaftEnd = Offset(
      tip.dx - math.cos(angle) * headLen * 0.8,
      tip.dy - math.sin(angle) * headLen * 0.8,
    );
    final path = Path()..moveTo(spine.first.dx, spine.first.dy);
    for (final point in spine.sublist(1, spine.length - 1)) {
      path.lineTo(point.dx, point.dy);
    }
    path.lineTo(shaftEnd.dx, shaftEnd.dy);
    canvas.drawPath(path, stroke);

    final left = Offset(
      tip.dx - headLen * math.cos(angle - spread),
      tip.dy - headLen * math.sin(angle - spread),
    );
    final right = Offset(
      tip.dx - headLen * math.cos(angle + spread),
      tip.dy - headLen * math.sin(angle + spread),
    );
    final head = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawPath(
      Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(left.dx, left.dy)
        ..lineTo(right.dx, right.dy)
        ..close(),
      head,
    );
  }

  @override
  bool shouldRepaint(ClueArrowLayerPainter oldDelegate) =>
      oldDelegate.arrows != arrows ||
      oldDelegate.cellSize != cellSize ||
      oldDelegate.color != color;
}
