import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../common/data/constants/app_colors.dart';
import '../../../../common/data/constants/app_text_styles.dart';
import '../../../../gameplay/data/entities/cell.dart';
import '../../../../gameplay/data/entities/direction.dart';

class HintCellWidget extends StatelessWidget {
  final HintCell cell;
  final double size;
  final VoidCallback onTap;

  const HintCellWidget({
    required this.cell,
    required this.size,
    required this.onTap,
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
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.all(size * 0.07),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: Text(
                    cell.clueText,
                    style: AppTextStyles.clue(size * 0.2),
                    textAlign: TextAlign.center,
                    maxLines: 4,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: size * 0.02,
              right: size * 0.02,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children:
                    cell.arrows.map((arrow) => _buildArrow(arrow)).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArrow(Direction direction) {
    final angle = switch (direction) {
      Direction.right => 0.0,
      Direction.down => pi / 2,
      Direction.downRight => pi / 4,
    };
    return Transform.rotate(
      angle: angle,
      child: Icon(
        Icons.play_arrow,
        color: AppColors.ink,
        size: size * 0.28,
      ),
    );
  }
}
