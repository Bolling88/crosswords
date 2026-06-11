import 'package:flutter/material.dart';

import 'package:crossword_core/crossword_core.dart';

import '../../../../common/data/constants/app_colors.dart';

class HintCellWidget extends StatelessWidget {
  final ClueCell cell;
  final double size;
  final VoidCallback onTap;
  final String fontFamily;

  const HintCellWidget({
    required this.cell,
    required this.size,
    required this.onTap,
    required this.fontFamily,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.clueCell,
          border: Border.all(color: AppColors.gridLine, width: 0.5),
        ),
        child: Stack(
          children: [
            // Clue prose is null in generator output, so clue cells render
            // arrows only. Texts can be layered here once authored.
            for (final arrow in cell.arrows) _buildArrow(arrow.shape),
          ],
        ),
      ),
    );
  }

  Widget _buildArrow(ArrowShape shape) {
    return switch (shape) {
      ArrowShape.straightRight => Align(
          alignment: Alignment.centerRight,
          child: Icon(Icons.play_arrow,
              color: AppColors.ink, size: size * 0.3),
        ),
      ArrowShape.straightDown => Align(
          alignment: Alignment.bottomCenter,
          child: Transform.rotate(
            angle: 1.5707963267948966, // pi/2
            child: Icon(Icons.play_arrow,
                color: AppColors.ink, size: size * 0.3),
          ),
        ),
      // Bent arrows: an elbow glyph hugging the corner the word turns through.
      // The base glyph (subdirectory_arrow_right) comes DOWN then turns RIGHT;
      // the other three orientations mirror/rotate it.
      ArrowShape.bentDownThenRight => Align(
          alignment: Alignment.bottomRight,
          child: Icon(Icons.subdirectory_arrow_right,
              color: AppColors.ink, size: size * 0.34),
        ),
      ArrowShape.bentUpThenRight => Align(
          alignment: Alignment.topRight,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.diagonal3Values(1, -1, 1), // flip vertically
            child: Icon(Icons.subdirectory_arrow_right,
                color: AppColors.ink, size: size * 0.34),
          ),
        ),
      ArrowShape.bentRightThenDown => Align(
          alignment: Alignment.bottomRight,
          child: Transform.rotate(
            angle: 1.5707963267948966, // pi/2: turns the elbow to right→down
            child: Icon(Icons.subdirectory_arrow_right,
                color: AppColors.ink, size: size * 0.34),
          ),
        ),
      ArrowShape.bentLeftThenDown => Align(
          alignment: Alignment.bottomLeft,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.diagonal3Values(-1, 1, 1), // mirror horizontally
            child: Transform.rotate(
              angle: 1.5707963267948966, // pi/2
              child: Icon(Icons.subdirectory_arrow_right,
                  color: AppColors.ink, size: size * 0.34),
            ),
          ),
        ),
    };
  }
}
