import 'cell.dart';

class CrosswordPuzzle {
  final int rows;
  final int cols;
  final Map<(int, int), Cell> cells;

  const CrosswordPuzzle({
    required this.rows,
    required this.cols,
    required this.cells,
  });
}
