import 'package:flutter/material.dart';

import '../../../../common/data/constants/app_colors.dart';
import '../../../../common/data/constants/app_text_styles.dart';

class AnswerCellWidget extends StatelessWidget {
  /// The letter to display: the player's input, or a seed's given letter.
  final String? letter;

  final bool isSelected;
  final bool isHighlighted;
  final bool isSeed;

  /// Marked wrong by a check action or autocheck — renders in error ink.
  final bool isIncorrect;

  /// Filled via reveal — renders in muted ink.
  final bool isRevealed;

  /// Non-null while this cell's word was just confirmed correct; a new token
  /// value replays the brief confirmation flash.
  final int? confirmPulseToken;
  final bool hasRightSeparator;
  final bool hasBottomSeparator;
  final double size;
  final VoidCallback onTap;
  final String fontFamily;

  const AnswerCellWidget({
    required this.size,
    required this.onTap,
    required this.fontFamily,
    this.letter,
    this.isSelected = false,
    this.isHighlighted = false,
    this.isSeed = false,
    this.isIncorrect = false,
    this.isRevealed = false,
    this.confirmPulseToken,
    this.hasRightSeparator = false,
    this.hasBottomSeparator = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final fillColor = isSelected
        ? AppColors.selection
        : isHighlighted
        ? AppColors.highlight
        : isSeed
        ? AppColors.seedCell
        : AppColors.paper;
    final inkColor = isIncorrect
        ? AppColors.errorInk
        : isRevealed
        ? AppColors.inkMuted
        : AppColors.ink;

    Widget cell = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: fillColor,
        border: Border(
          top: const BorderSide(color: AppColors.gridLine, width: 0.5),
          left: const BorderSide(color: AppColors.gridLine, width: 0.5),
          right: BorderSide(
            color: hasRightSeparator ? AppColors.separator : AppColors.gridLine,
            width: hasRightSeparator ? 2.0 : 0.5,
          ),
          bottom: BorderSide(
            color: hasBottomSeparator
                ? AppColors.separator
                : AppColors.gridLine,
            width: hasBottomSeparator ? 2.0 : 0.5,
          ),
        ),
      ),
      alignment: Alignment.center,
      // Keyed by the letter so a newly entered glyph pops in; clearing a cell
      // (letter -> null) swaps without animating.
      child: TweenAnimationBuilder<double>(
        key: ValueKey(letter ?? ''),
        tween: Tween(begin: letter == null ? 1.0 : 0.6, end: 1.0),
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutBack,
        builder: (context, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: Text(
          letter ?? '',
          style: AppTextStyles.answerLetter(
            size * 0.66,
            family: fontFamily,
          ).copyWith(color: inkColor),
        ),
      ),
    );

    final token = confirmPulseToken;
    if (token != null) {
      // A new token re-keys the builder, replaying a sage wash that fades out.
      cell = TweenAnimationBuilder<double>(
        key: ValueKey('pulse-$token'),
        tween: Tween(begin: 1.0, end: 0.0),
        duration: const Duration(milliseconds: 600),
        builder: (context, strength, child) => Stack(
          fit: StackFit.passthrough,
          children: [
            ?child,
            Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(
                  color: AppColors.seedCell.withAlpha((strength * 140).round()),
                ),
              ),
            ),
          ],
        ),
        child: cell,
      );
    }

    return GestureDetector(onTap: onTap, child: cell);
  }
}
