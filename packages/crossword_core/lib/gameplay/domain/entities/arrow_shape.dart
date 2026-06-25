/// Visual glyph for a clue's arrow, derived from where the word starts
/// relative to the clue cell and which way the word travels.
enum ArrowShape {
  /// Word starts in the cell to the right and runs right.
  straightRight,

  /// Word starts in the cell below and runs down.
  straightDown,

  /// Word starts in the cell below, then runs right (L-shaped, down→right).
  bentDownThenRight,

  /// Word starts in the cell above, then runs right (L-shaped, up→right).
  bentUpThenRight,

  /// Word starts in the cell to the right, then runs down (L-shaped, right→down).
  bentRightThenDown,

  /// Word starts in the cell to the left, then runs down (L-shaped, left→down).
  bentLeftThenDown,

  /// Word starts in the diagonally below-left cell, then runs right.
  diagonalSwThenRight,

  /// Word starts in the diagonally above-left cell, then runs right.
  diagonalNwThenRight,

  /// Word starts in the diagonally below-right cell, then runs right.
  diagonalSeThenRight,

  /// Word starts in the diagonally above-right cell, then runs right.
  diagonalNeThenRight,

  /// Word starts in the diagonally below-left cell, then runs down.
  diagonalSwThenDown,

  /// Word starts in the diagonally above-left cell, then runs down.
  diagonalNwThenDown,

  /// Word starts in the diagonally below-right cell, then runs down.
  diagonalSeThenDown,

  /// Word starts in the diagonally above-right cell, then runs down.
  diagonalNeThenDown,
}
