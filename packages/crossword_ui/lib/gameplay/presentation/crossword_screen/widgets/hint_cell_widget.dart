import 'package:flutter/material.dart';

import 'package:crossword_core/crossword_core.dart';

import '../../../../common/data/constants/app_colors.dart';
import 'clue_arrow_painter.dart';
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
      return _compartment(arrows.first, isSplit: false);
    }
    // Two clues share this box: split it into top and bottom compartments.
    // arrows are ordered top-first by the mapper/resolver.
    return Column(
      children: [
        Expanded(child: _compartment(arrows[0], isSplit: true)),
        Container(height: 0.5, color: AppColors.gridLine),
        Expanded(child: _compartment(arrows[1], isSplit: true)),
      ],
    );
  }

  /// One clue: mock prose filling the box. A small arrow is snapped onto the
  /// cell border toward the word's start ONLY when the flow is non-obvious;
  /// words that continue in the logical direction draw no arrow (korsord rule).
  Widget _compartment(ClueArrow arrow, {required bool isSplit}) {
    final implied = clueArrowIsImplied(arrow.shape);
    final entry = clueArrowVectors(arrow.shape).entry;
    final fontSize = size * (isSplit ? 0.13 : 0.155);

    final text = Padding(
      padding: implied
          ? EdgeInsets.all(size * 0.05)
          : _textPadding(entry, isSplit: isSplit),
      child: Center(
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
    );

    if (implied) {
      return text;
    }

    final arrowExtent = size * (isSplit ? 0.22 : 0.28);
    return Stack(
      children: [
        text,
        Align(
          alignment: clueArrowAlignment(arrow.shape),
          child: SizedBox(
            width: arrowExtent,
            height: arrowExtent,
            child: CustomPaint(
              painter: ClueArrowPainter(shape: arrow.shape, color: AppColors.ink),
            ),
          ),
        ),
      ],
    );
  }

  /// Extra inset on the side the arrow sits, so prose doesn't crowd the glyph.
  EdgeInsets _textPadding(Offset entry, {required bool isSplit}) {
    final base = size * 0.05;
    final extra = size * (isSplit ? 0.16 : 0.2);
    return EdgeInsets.only(
      left: base + (entry.dx < 0 ? extra : 0),
      right: base + (entry.dx > 0 ? extra : 0),
      top: base + (entry.dy < 0 ? extra : 0),
      bottom: base + (entry.dy > 0 ? extra : 0),
    );
  }
}
