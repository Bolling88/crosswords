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

/// Whether the arrow is implied by the natural reading flow and should NOT be
/// drawn. Like printed korsord, a clue directly left of a word that reads right
/// (`straightRight`) or directly above a word that reads down (`straightDown`)
/// needs no glyph — the answer simply continues in the logical direction. Every
/// other shape marks a deviation (a bend or an offset start) and is drawn.
bool clueArrowIsImplied(ArrowShape shape) =>
    shape == ArrowShape.straightRight || shape == ArrowShape.straightDown;

// 6% inner margin keeps the glyph off the cell edge.
Offset _clampUnit(Offset o) =>
    Offset(o.dx.clamp(0.06, 0.94), o.dy.clamp(0.06, 0.94));

/// Arrow drawn INSIDE a word's first input box, korsord style: it enters from
/// the edge facing the clue and bends to point the way the answer is written.
/// Points are unit coords (0..1) over the cell, ordered tail (clue side) →
/// elbow → tip (travel side). Implied shapes are never drawn (see
/// [clueArrowIsImplied]); their spine is still well-formed.
List<Offset> startArrowSpine(ArrowShape shape) {
  final v = clueArrowVectors(shape);
  // entry points clue → start, so the clue lies in the opposite direction.
  final clueDir = Offset(-v.entry.dx, -v.entry.dy);
  const center = Offset(0.5, 0.5);
  final tail = _clampUnit(center + clueDir * 0.4);
  final elbow = _clampUnit(center + clueDir * 0.14);
  final tip = _clampUnit(elbow + v.travel * 0.4);
  return [tail, elbow, tip];
}

/// Draws a small clue arrow inside a word's first input box. Scoped
/// CustomPainter exception: only the arrow glyph is painted; the grid itself
/// remains widget-based.
class ClueArrowPainter extends CustomPainter {
  final ArrowShape shape;
  final Color color;

  const ClueArrowPainter({required this.shape, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final spine = startArrowSpine(shape)
        .map((p) => Offset(p.dx * size.width, p.dy * size.height))
        .toList();

    final stroke = Paint()
      ..color = color
      ..strokeWidth = math.max(1.0, size.shortestSide * 0.06)
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
    final headLen = size.shortestSide * 0.18;
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
