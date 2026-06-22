import '../domain/entities/cell.dart';
import '../domain/entities/clue_arrow.dart';
import '../domain/entities/crossword_puzzle.dart';
import '../domain/entities/direction.dart';
import '../domain/entities/word.dart';
import '../domain/services/arrow_shape_resolver.dart';
import 'entities/dto/grid_cell_dto.dart';
import 'entities/dto/position_dto.dart';
import 'entities/dto/puzzle_dto.dart';

/// Converts a parsed [PuzzleDto] into a playable domain [CrosswordPuzzle],
/// resolving each word's ordered cell path from its start position and any
/// mid-word redirect turns.
class PuzzleResolver {
  const PuzzleResolver._();

  static CrosswordPuzzle resolve(PuzzleDto dto) {
    final grid = dto.grid;
    final rows = grid.height;
    final cols = grid.width;

    AnswerCellDto? answerAt(int r, int c) {
      if (r < 0 || r >= rows || c < 0 || c >= cols) return null;
      final cell = grid.rows[r][c];
      return cell is AnswerCellDto ? cell : null;
    }

    final seeds = dto.seedPositions.map((p) => (p.row, p.col)).toSet();
    final domainCells = <(int, int), Cell>{};
    final words = <Word>[];
    final separatorEdges = <(int, int), Set<Direction>>{};

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final cell = grid.rows[r][c];
        switch (cell) {
          case BlockCellDto():
            domainCells[(r, c)] = const BlockCell();
          case AnswerCellDto():
            domainCells[(r, c)] =
                AnswerCell(value: cell.value, isSeed: seeds.contains((r, c)));
          case ClueCellDto():
            final arrows = <ClueArrow>[];

            if (cell.rightWordId != null && cell.rightStart != null) {
              words.add(_resolveWord(
                id: cell.rightWordId!,
                clueId: cell.rightClueId,
                clueText: cell.right,
                start: cell.rightStart!,
                base: Direction.right,
                answerAt: answerAt,
                separatorEdges: separatorEdges,
              ));
              arrows.add(ClueArrow(
                direction: Direction.right,
                shape: ArrowShapeResolver.resolve(
                  clueRow: r,
                  clueCol: c,
                  startRow: cell.rightStart!.row,
                  startCol: cell.rightStart!.col,
                  base: Direction.right,
                ),
                wordId: cell.rightWordId!,
              ));
            }

            if (cell.downWordId != null && cell.downStart != null) {
              words.add(_resolveWord(
                id: cell.downWordId!,
                clueId: cell.downClueId,
                clueText: cell.down,
                start: cell.downStart!,
                base: Direction.down,
                answerAt: answerAt,
                separatorEdges: separatorEdges,
              ));
              arrows.add(ClueArrow(
                direction: Direction.down,
                shape: ArrowShapeResolver.resolve(
                  clueRow: r,
                  clueCol: c,
                  startRow: cell.downStart!.row,
                  startCol: cell.downStart!.col,
                  base: Direction.down,
                ),
                wordId: cell.downWordId!,
              ));
            }

            domainCells[(r, c)] = ClueCell(arrows: arrows);
        }
      }
    }

    return CrosswordPuzzle(
      rows: rows,
      cols: cols,
      cells: domainCells,
      words: words,
      seedPositions: seeds,
      separatorEdges: separatorEdges,
      title: dto.title,
      languageCode: dto.languageCode,
    );
  }

  /// Walks from [start] in [base] direction, appending answer cells and
  /// turning right→down / down→right at any cell flagged redirect for the
  /// current travel direction, until the next cell is not an answer.
  static Word _resolveWord({
    required String id,
    required String? clueId,
    required String? clueText,
    required PositionDto start,
    required Direction base,
    required AnswerCellDto? Function(int, int) answerAt,
    required Map<(int, int), Set<Direction>> separatorEdges,
  }) {
    final cells = <(int, int)>[];
    final visited = <(int, int)>{};
    final separators = <int>{};
    var r = start.row;
    var c = start.col;
    var dir = base;

    while (true) {
      final cell = answerAt(r, c);
      if (cell == null) break;
      cells.add((r, c));
      visited.add((r, c));
      final index = cells.length - 1;

      final separator =
          dir == Direction.right ? cell.rightSeparator : cell.downSeparator;
      if (separator != null) {
        separators.add(index);
        separatorEdges.putIfAbsent((r, c), () => <Direction>{}).add(dir);
      }

      final redirect =
          dir == Direction.right ? cell.rightRedirect : cell.downRedirect;
      if (redirect) {
        dir = dir == Direction.right ? Direction.down : Direction.right;
      }

      final (nr, nc) =
          dir == Direction.right ? (r, c + 1) : (r + 1, c);
      if (answerAt(nr, nc) == null || visited.contains((nr, nc))) break;
      r = nr;
      c = nc;
    }

    return Word(
      id: id,
      clueId: clueId,
      clueText: clueText,
      direction: base,
      cells: cells,
      separators: separators,
    );
  }
}
