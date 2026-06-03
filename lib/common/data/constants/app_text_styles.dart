import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Centralized text styles.
///
/// Uses condensed grotesque faces that mimic printed crossword type:
/// [GoogleFonts.oswald] for the tall, narrow answer letters and
/// [GoogleFonts.robotoCondensed] for the small clue print.
class AppTextStyles {
  const AppTextStyles._();

  /// Entered answer letters — neat block-capital handwriting, as if the solver
  /// filled the grid in by hand. Size is supplied per-cell since it scales with
  /// the cell dimensions. [family] overrides the handwritten font family.
  static TextStyle answerLetter(
    double fontSize, {
    Color color = AppColors.ink,
    String? family,
  }) {
    return GoogleFonts.getFont(
      family ?? 'Patrick Hand',
      fontSize: fontSize,
      fontWeight: FontWeight.w400,
      color: color,
      height: 1.0,
    );
  }

  /// Clue text inside hint cells. Size scales with the cell. [family] overrides
  /// the font family (used when the player picks a handwritten font).
  static TextStyle clue(double fontSize, {String? family}) {
    return GoogleFonts.getFont(
      family ?? 'Roboto Condensed',
      fontSize: fontSize,
      fontWeight: FontWeight.w500,
      color: AppColors.ink,
      height: 1.05,
    );
  }

  /// Label shown on image clue cells (e.g. "BILD").
  static TextStyle imageLabel(double fontSize) {
    return GoogleFonts.oswald(
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      color: AppColors.inkMuted,
      letterSpacing: 2,
    );
  }

  /// App bar title.
  static TextStyle appBarTitle() {
    return GoogleFonts.oswald(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      color: AppColors.onBrand,
      letterSpacing: 3,
    );
  }
}
