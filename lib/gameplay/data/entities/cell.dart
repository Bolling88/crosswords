import 'direction.dart';

sealed class Cell {
  const Cell();
}

class HintCell extends Cell {
  final String clueText;
  final List<Direction> arrows;

  const HintCell({required this.clueText, required this.arrows});
}

class AnswerCell extends Cell {
  final String solution;

  const AnswerCell({required this.solution});
}

class BlockedCell extends Cell {
  const BlockedCell();
}

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
