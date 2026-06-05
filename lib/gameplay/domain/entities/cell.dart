import 'clue_arrow.dart';

sealed class Cell {
  const Cell();
}

/// A hint cell carrying 0–2 arrows (one across, one down).
class ClueCell extends Cell {
  final List<ClueArrow> arrows;

  const ClueCell({this.arrows = const []});
}

/// A fillable letter cell.
class AnswerCell extends Cell {
  final String value;
  final bool isSeed;

  const AnswerCell({required this.value, this.isSeed = false});
}

/// An inert dark cell.
class BlockCell extends Cell {
  const BlockCell();
}

/// Retained for future image clues; not produced by the current generator.
class ImageCell extends Cell {
  final int spanRows;
  final int spanCols;
  final bool isOrigin;

  const ImageCell({
    required this.spanRows,
    required this.spanCols,
    required this.isOrigin,
  });
}
