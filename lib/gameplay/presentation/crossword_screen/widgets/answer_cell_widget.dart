import 'package:flutter/material.dart';

import '../../../../common/data/constants/app_colors.dart';
import '../../../../common/data/constants/app_text_styles.dart';

class AnswerCellWidget extends StatelessWidget {
  final String? userInput;
  final bool isSelected;
  final bool isHighlighted;
  final double size;
  final VoidCallback onTap;
  final String fontFamily;

  const AnswerCellWidget({
    required this.size,
    required this.onTap,
    required this.fontFamily,
    this.userInput,
    this.isSelected = false,
    this.isHighlighted = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final fillColor = isSelected
        ? AppColors.selection
        : isHighlighted
            ? AppColors.highlight
            : AppColors.paper;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: fillColor,
          border: Border.all(color: AppColors.gridLine, width: 0.5),
        ),
        alignment: Alignment.center,
        child: Text(
          userInput ?? '',
          style: AppTextStyles.answerLetter(size * 0.66, family: fontFamily),
        ),
      ),
    );
  }
}
