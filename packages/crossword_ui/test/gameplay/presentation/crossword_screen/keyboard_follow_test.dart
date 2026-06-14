import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crossword_ui/gameplay/presentation/crossword_screen/keyboard_follow.dart';

void main() {
  // A 10x10 grid that exactly fills a 300x300 viewport: cellSize 30, so cell
  // (r,c) centre in child-space is (c*30+15, r*30+15).
  const viewport = Size(300, 300);
  const cellSize = 30.0;
  const rows = 10;
  const cols = 10;
  const margin = cellSize; // 30; band is [30, 270] on each axis

  Matrix4 scaled(double s, [double tx = 0, double ty = 0]) =>
      Matrix4.identity()
        ..scale(s)
        ..setTranslationRaw(tx, ty, 0);

  test('returns null at fit scale (cannot pan)', () {
    final result = transformToRevealCell(
      current: Matrix4.identity(),
      viewport: viewport,
      cellSize: cellSize,
      rows: rows,
      cols: cols,
      cell: (9, 9),
      margin: margin,
    );

    expect(result, isNull);
  });

  test('returns null when the cell is already comfortably visible', () {
    // scale 2, panned so cell (2,2) centre (75,75) maps to (100,100) — inside
    // the [30,270] band on both axes.
    final result = transformToRevealCell(
      current: scaled(2, -50, -50),
      viewport: viewport,
      cellSize: cellSize,
      rows: rows,
      cols: cols,
      cell: (2, 2),
      margin: margin,
    );

    expect(result, isNull);
  });

  test('pans up to the bottom margin when the cell is below the band', () {
    // scale 2, no pan: cell (6,*) centre y = 195 -> viewport y = 390 (> 270).
    final result = transformToRevealCell(
      current: scaled(2),
      viewport: viewport,
      cellSize: cellSize,
      rows: rows,
      cols: cols,
      cell: (6, 2),
      margin: margin,
    );

    // ty' = (extent - m) - s*cy = 270 - 390 = -120; cell lands at y = 270.
    expect(result, isNotNull);
    expect(result!.storage[13], closeTo(-120, 0.5));
    expect(2 * 195 + result.storage[13], closeTo(270, 0.5));
  });

  test('pans down to the top margin when the cell is above the band', () {
    // scale 2, panned up by 80: cell (1,3) centre y = 45 -> viewport y = 10,
    // above the band; x (centre 105 -> 210) stays inside.
    final result = transformToRevealCell(
      current: scaled(2, 0, -80),
      viewport: viewport,
      cellSize: cellSize,
      rows: rows,
      cols: cols,
      cell: (1, 3),
      margin: margin,
    );

    // ty' = m - s*cy = 30 - 90 = -60; cell lands at y = 30; x unchanged.
    expect(result, isNotNull);
    expect(result!.storage[13], closeTo(-60, 0.5));
    expect(result.storage[12], closeTo(0, 0.5));
  });

  test('pans left to the right margin when the cell is right of the band', () {
    final result = transformToRevealCell(
      current: scaled(2),
      viewport: viewport,
      cellSize: cellSize,
      rows: rows,
      cols: cols,
      cell: (2, 6),
      margin: margin,
    );

    expect(result, isNotNull);
    expect(result!.storage[12], closeTo(-120, 0.5));
  });

  test('clamps so the scaled child still covers the viewport', () {
    // scale 2, last row: pulling it to the band would expose the child's
    // bottom edge, so translation is clamped to extent*(1-scale) = -300.
    final result = transformToRevealCell(
      current: scaled(2),
      viewport: viewport,
      cellSize: cellSize,
      rows: rows,
      cols: cols,
      cell: (9, 0),
      margin: margin,
    );

    expect(result, isNotNull);
    expect(result!.storage[13], closeTo(-300, 0.5));
    // Child bottom (scale*childHeight + ty) stays at the viewport bottom.
    expect(2 * 300 + result.storage[13], closeTo(300, 0.5));
  });

  test('preserves scale and the unaffected axis', () {
    final result = transformToRevealCell(
      current: scaled(2, 0, 0),
      viewport: viewport,
      cellSize: cellSize,
      rows: rows,
      cols: cols,
      cell: (6, 2), // only y is out of band; x (centre 75 -> 150) is inside
      margin: margin,
    );

    expect(result!.storage[0], closeTo(2, 0.0001)); // scale preserved
    expect(result.storage[12], closeTo(0, 0.5)); // x translation unchanged
  });
}
