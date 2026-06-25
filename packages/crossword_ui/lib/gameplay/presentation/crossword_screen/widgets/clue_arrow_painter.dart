import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'package:crossword_core/crossword_core.dart';

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

/// Cell edge/corner the small arrow hugs, derived from where the word starts
/// relative to the clue cell. Lets the widget snap the arrow onto the cell
/// border ("on the line"), the way printed korsord arrows sit. The entry unit
/// vector (-1/0/1 per axis) maps directly onto [Alignment]'s (-1..1) space.
Alignment clueArrowAlignment(ArrowShape shape) {
  final entry = clueArrowVectors(shape).entry;
  return Alignment(entry.dx, entry.dy);
}

// 8% inner margin keeps the arrowhead tip off the cell edge.
Offset _clampUnit(Offset o) =>
    Offset(o.dx.clamp(0.08, 0.92), o.dy.clamp(0.08, 0.92));

/// Arrow spine in the unit square (0..1), ordered tail→tip. Straight arrows are
/// a 2-point line; bent and diagonal arrows add an elbow toward the start cell.
List<Offset> clueArrowSpine(ArrowShape shape) {
  final v = clueArrowVectors(shape);
  const center = Offset(0.5, 0.5);
  if (v.entry == v.travel) {
    return [
      _clampUnit(center - v.travel * 0.4),
      _clampUnit(center + v.travel * 0.4),
    ];
  }
  final elbow = _clampUnit(center + v.entry * 0.3);
  final tip = _clampUnit(elbow + v.travel * 0.45);
  return [_clampUnit(center - v.travel * 0.15), elbow, tip];
}

/// Draws a single clue arrow (line spine + filled arrowhead) filling its canvas.
/// Scoped CustomPainter exception: only the arrow glyph is painted; the grid
/// itself remains widget-based.
class ClueArrowPainter extends CustomPainter {
  final ArrowShape shape;
  final Color color;

  const ClueArrowPainter({required this.shape, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final spine = clueArrowSpine(shape)
        .map((p) => Offset(p.dx * size.width, p.dy * size.height))
        .toList();

    final stroke = Paint()
      ..color = color
      ..strokeWidth = math.max(1.0, size.shortestSide * 0.07)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path()..moveTo(spine.first.dx, spine.first.dy);
    for (final point in spine.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, stroke);

    final tip = spine.last;
    final prev = spine[spine.length - 2];
    final angle = math.atan2(tip.dy - prev.dy, tip.dx - prev.dx);
    final headLen = size.shortestSide * 0.24;
    const spread = 0.5; // radians off the shaft axis
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
      ..style = PaintingStyle.fill;
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
  bool shouldRepaint(ClueArrowPainter oldDelegate) =>
      oldDelegate.shape != shape || oldDelegate.color != color;
}
