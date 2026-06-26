import 'package:flutter/material.dart';

import 'package:crossword_core/crossword_core.dart';

import '../../../../common/data/constants/app_colors.dart';
import 'mock_clue_text.dart';

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
      return _clueText(arrows.first, isSplit: false);
    }
    // Two clues share this box: split it into top and bottom compartments.
    // Arrows are ordered top-first by the mapper/resolver.
    return Column(
      children: [
        Expanded(child: _clueText(arrows[0], isSplit: true)),
        Container(height: 0.5, color: AppColors.gridLine),
        Expanded(child: _clueText(arrows[1], isSplit: true)),
      ],
    );
  }

  Widget _clueText(ClueArrow arrow, {required bool isSplit}) {
    final fontSize = size * (isSplit ? 0.13 : 0.155);
    return Padding(
      padding: EdgeInsets.all(size * 0.055),
      child: Align(
        alignment: Alignment.center,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: arrow.direction == Direction.right ? size * 0.06 : 0,
            right: arrow.direction == Direction.down ? size * 0.06 : 0,
          ),
          child: Text(
            mockClueText(arrow.wordId),
            textAlign: TextAlign.center,
            maxLines: isSplit ? 2 : 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: fontFamily,
              color: AppColors.ink,
              fontSize: fontSize,
              height: 1.05,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
