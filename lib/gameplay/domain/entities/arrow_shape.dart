/// Visual glyph for a clue's arrow, derived from where the word starts
/// relative to the clue cell and which way the word travels.
enum ArrowShape {
  /// Word starts in the cell to the right and runs right.
  straightRight,

  /// Word starts in the cell below and runs down.
  straightDown,

  /// Word starts in the cell below, then runs right (L-shaped, down→right).
  bentDownThenRight,

  /// Word starts in the cell to the right, then runs down (L-shaped, right→down).
  bentRightThenDown,
}
