import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:crossword_core/crossword_core.dart';

import '../../../../common/data/constants/app_colors.dart';
import '../../../../common/data/constants/app_text_styles.dart';
import '../../../../common/data/constants/strings.dart';
import '../cubit/crossword_cubit.dart';
import '../cubit/crossword_state.dart';
import 'answer_cell_widget.dart';
import 'blocked_cell_widget.dart';
import 'clue_arrow_painter.dart';
import 'hint_cell_widget.dart';

class CrosswordGrid extends StatelessWidget {
  /// Width of the outer frame border. Callers computing the grid's cell size
  /// from a width budget must subtract this on each side, so it is the shared
  /// source of truth for both the painted border and that calculation.
  static const double borderWidth = 2.0;

  final CrosswordState state;
  final double cellSize;

  const CrosswordGrid({required this.state, required this.cellSize, super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.frame, width: borderWidth),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          _buildTable(context, cellSize),
          ..._buildImageOverlays(cellSize),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: ClueArrowLayerPainter(
                  arrows: _clueArrows(),
                  cellSize: cellSize,
                  color: AppColors.ink,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTable(BuildContext context, double cellSize) {
    final cubit = context.read<CrosswordCubit>();
    return Table(
      defaultColumnWidth: FixedColumnWidth(cellSize),
      defaultVerticalAlignment: TableCellVerticalAlignment.top,
      children: List.generate(state.puzzle.rows, (row) {
        return TableRow(
          children: List.generate(state.puzzle.cols, (col) {
            return SizedBox(
              height: cellSize,
              child: _buildCell(row, col, cellSize, cubit),
            );
          }),
        );
      }),
    );
  }

  Widget _buildCell(int row, int col, double cellSize, CrosswordCubit cubit) {
    final cell = state.puzzle.cells[(row, col)];
    if (cell == null) {
      return SizedBox(width: cellSize, height: cellSize);
    }

    final fontFamily = state.font.googleFamily;
    final edges = state.puzzle.separatorEdges[(row, col)] ?? const {};

    return switch (cell) {
      ClueCell() => HintCellWidget(
        cell: cell,
        size: cellSize,
        onTap: () => cubit.selectCell(row, col),
        fontFamily: fontFamily,
        isActive: state.activeClueCell == (row, col),
      ),
      AnswerCell() => AnswerCellWidget(
        letter:
            state.userInputs[(row, col)] ?? (cell.isSeed ? cell.value : null),
        isSelected: state.selectedCell == (row, col),
        isHighlighted: state.highlightedCells.contains((row, col)),
        isSeed: cell.isSeed,
        isIncorrect: state.incorrectCells.contains((row, col)),
        isRevealed: state.revealedCells.contains((row, col)),
        confirmPulseToken: _pulseTokenFor(row, col),
        hasRightSeparator: edges.contains(Direction.right),
        hasBottomSeparator: edges.contains(Direction.down),
        size: cellSize,
        onTap: () => cubit.selectCell(row, col),
        fontFamily: fontFamily,
      ),
      BlockCell() => BlockedCellWidget(size: cellSize),
      ImageCell() => SizedBox(width: cellSize, height: cellSize),
    };
  }

  /// The flash token for cells of the most recently confirmed word; null for
  /// all other cells (and before any confirmation has happened).
  int? _pulseTokenFor(int row, int col) {
    if (state.confirmedWordToken == 0) return null;
    final word = state.puzzle.wordById(state.confirmedWordId ?? '');
    if (word == null || !word.cells.contains((row, col))) return null;
    return state.confirmedWordToken;
  }

  List<GridClueArrow> _clueArrows() {
    final arrows = <GridClueArrow>[];
    for (final entry in state.puzzle.cells.entries) {
      final cell = entry.value;
      if (cell is! ClueCell) continue;
      final (row, col) = entry.key;
      for (var i = 0; i < cell.arrows.length; i++) {
        arrows.add((
          row: row,
          col: col,
          slot: i,
          slotCount: cell.arrows.length,
          arrow: cell.arrows[i],
        ));
      }
    }
    return arrows;
  }

  List<Widget> _buildImageOverlays(double cellSize) {
    final overlays = <Widget>[];
    for (final entry in state.puzzle.cells.entries) {
      final cell = entry.value;
      if (cell is ImageCell && cell.isOrigin) {
        final (row, col) = entry.key;
        overlays.add(
          Positioned(
            left: col * cellSize,
            top: row * cellSize,
            width: cell.spanCols * cellSize,
            height: cell.spanRows * cellSize,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.imageCell,
                border: Border.all(color: AppColors.gridLine, width: 0.5),
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.image_outlined,
                    size: cellSize * 1.1,
                    color: AppColors.inkMuted,
                  ),
                  Text(
                    Strings.imageClueLabel,
                    style: AppTextStyles.imageLabel(cellSize * 0.28),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }
    return overlays;
  }
}
