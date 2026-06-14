import 'package:flutter/widgets.dart';

/// The transform that brings [cell] into a comfortable band of the [viewport],
/// or null when the cell is already comfortably visible. Only the translation
/// changes; the current scale (and any pan on the axis that is already fine)
/// is preserved.
///
/// Pure geometry. The grid is centred inside an `InteractiveViewer` child whose
/// size equals the viewport, so a cell's centre in child-space depends only on
/// the viewport size, [cellSize] and the cell's row/col (the symmetric border
/// and padding cancel out). The viewer only scales and translates — no rotation
/// — so the current matrix is read as scale `storage[0]` and translation
/// `storage[12]`/`storage[13]`.
Matrix4? transformToRevealCell({
  required Matrix4 current,
  required Size viewport,
  required double cellSize,
  required int rows,
  required int cols,
  required (int, int) cell,
  required double margin,
}) {
  final scale = current.storage[0];
  final tx = current.storage[12];
  final ty = current.storage[13];

  final (row, col) = cell;
  final cx =
      (viewport.width - cols * cellSize) / 2 + col * cellSize + cellSize / 2;
  final cy =
      (viewport.height - rows * cellSize) / 2 + row * cellSize + cellSize / 2;

  final newTx = _revealAxis(
    center: cx,
    scale: scale,
    translation: tx,
    extent: viewport.width,
    margin: margin,
  );
  final newTy = _revealAxis(
    center: cy,
    scale: scale,
    translation: ty,
    extent: viewport.height,
    margin: margin,
  );

  const epsilon = 0.5;
  if ((newTx - tx).abs() < epsilon && (newTy - ty).abs() < epsilon) return null;

  return Matrix4.copy(current)..setTranslationRaw(newTx, newTy, 0);
}

/// The translation along one axis that keeps the cell centre inside the band
/// `[m, extent - m]`, clamped so the scaled child still covers the viewport.
double _revealAxis({
  required double center,
  required double scale,
  required double translation,
  required double extent,
  required double margin,
}) {
  final m = margin < extent / 3 ? margin : extent / 3;
  final viewportPos = scale * center + translation;

  var target = translation;
  if (viewportPos < m) {
    target = m - scale * center;
  } else if (viewportPos > extent - m) {
    target = (extent - m) - scale * center;
  }

  // The child extent equals the viewport extent, so the scaled child spans
  // `scale * extent`; to keep it covering the viewport the translation must
  // stay within [extent * (1 - scale), 0].
  final min = extent * (1 - scale);
  if (target < min) target = min;
  if (target > 0) target = 0;
  return target;
}
