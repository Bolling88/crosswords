import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../gameplay/data/entities/cell.dart';
import '../cubit/crossword_cubit.dart';
import '../cubit/crossword_state.dart';
import 'answer_cell_widget.dart';
import 'blocked_cell_widget.dart';
import 'hint_cell_widget.dart';

class CrosswordGrid extends StatelessWidget {
  final CrosswordState state;

  const CrosswordGrid({required this.state, super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellSize = constraints.maxWidth / state.puzzle.cols;
        return Stack(
          children: [
            _buildTable(context, cellSize),
            ..._buildImageOverlays(cellSize),
          ],
        );
      },
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

    return switch (cell) {
      HintCell() => HintCellWidget(
          cell: cell,
          size: cellSize,
          onTap: () => cubit.selectCell(row, col),
        ),
      AnswerCell() => AnswerCellWidget(
          userInput: state.userInputs[(row, col)],
          isSelected: state.selectedCell == (row, col),
          isHighlighted: state.highlightedCells.contains((row, col)),
          size: cellSize,
          onTap: () => cubit.selectCell(row, col),
        ),
      BlockedCell() => BlockedCellWidget(size: cellSize),
      ImageCell() => SizedBox(width: cellSize, height: cellSize),
    };
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
                color: const Color(0xFFE8EAF6),
                border: Border.all(width: 0.5),
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.image,
                    size: cellSize * 1.2,
                    color: const Color(0xFF7986CB),
                  ),
                  Text(
                    'BILD',
                    style: TextStyle(
                      color: const Color(0xFF3F51B5),
                      fontSize: cellSize * 0.3,
                      fontWeight: FontWeight.bold,
                    ),
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
