import 'package:crossword_core/crossword_core.dart';
import 'package:flutter/material.dart';

import '../../../../common/data/constants/app_colors.dart';
import 'clue_arrow_painter.dart';

class HintCellWidget extends StatelessWidget {
  final ClueCell cell;
  final double size;
  final VoidCallback onTap;
  final String fontFamily;

  /// Whether this clue starts the currently active word.
  final bool isActive;

  const HintCellWidget({
    required this.cell,
    required this.size,
    required this.onTap,
    required this.fontFamily,
    this.isActive = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isActive ? AppColors.clueCellActive : AppColors.clueCell,
          border: Border.all(color: AppColors.gridLine, width: 0.5),
        ),
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    final arrows = cell.arrows;
    if (arrows.isEmpty) {
      return const SizedBox.expand();
    }
    if (arrows.length == 1) {
      return _arrowPaint(arrows.first);
    }
    // Two clues share this box: split it into top and bottom compartments.
    // arrows are ordered top-first by the mapper/resolver.
    return Column(
      children: [
        Expanded(child: _arrowPaint(arrows[0])),
        Container(height: 0.5, color: AppColors.gridLine),
        Expanded(child: _arrowPaint(arrows[1])),
      ],
    );
  }

  Widget _arrowPaint(ClueArrow arrow) {
    return CustomPaint(
      painter: ClueArrowPainter(shape: arrow.shape, color: AppColors.ink),
      child: const SizedBox.expand(),
    );
  }
}
