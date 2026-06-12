import 'package:flutter/material.dart';

/// Centralized color palette for the app.
///
/// Tuned for an authentic Swedish magazine korsord ("classic print") look:
/// warm cream answer cells, grey-beige clue cells with black ink, thin grey
/// grid lines, and a soft amber highlight reminiscent of a pencil marker.
class AppColors {
  const AppColors._();

  // Surfaces
  /// Page background behind the grid (slightly darker than the paper cells).
  static const Color background = Color(0xFFEDE7D9);

  /// Answer cell fill — warm newsprint cream.
  static const Color paper = Color(0xFFF8F4EA);

  /// Clue cell fill — grey-beige so clues read as distinct from answers.
  static const Color clueCell = Color(0xFFCFC9B8);

  /// Solid blocked / filler cell.
  static const Color blockedCell = Color(0xFF2E2A24);

  /// Image clue cell fill.
  static const Color imageCell = Color(0xFFEDE7D9);

  // Lines & frame
  /// Thin interior grid lines.
  static const Color gridLine = Color(0xFFA8A296);

  /// Heavier outer frame around the whole puzzle.
  static const Color frame = Color(0xFF3A352C);

  // Ink (text & arrows)
  /// Primary text colour for entered letters and clue text.
  static const Color ink = Color(0xFF1F1B16);

  /// Muted ink for secondary marks (e.g. image label, revealed letters).
  static const Color inkMuted = Color(0xFF6B6557);

  /// Ink for letters marked wrong by a check — brick red, like a teacher's pen.
  static const Color errorInk = Color(0xFFB3402F);

  // Interaction states
  /// Currently selected cell — warm amber, like a highlighter.
  static const Color selection = Color(0xFFF4C95D);

  /// Cells in the currently active word — pale amber wash.
  static const Color highlight = Color(0xFFFBEFC8);

  /// Clue cell of the currently active word — amber-tinted to make the
  /// active direction visible.
  static const Color clueCellActive = Color(0xFFE6D9A8);

  // App chrome
  /// App bar / brand surface.
  static const Color brand = Color(0xFF2E2A24);

  /// Text/icons on the brand surface.
  static const Color onBrand = Color(0xFFF8F4EA);

  // Theme / structure marks
  /// Seed (theme word) answer cell — subtle pale sage wash.
  static const Color seedCell = Color(0xFFE3EAD2);

  /// Divider drawn on a cell edge where a multi-word answer breaks.
  static const Color separator = Color(0xFF3A352C);
}
