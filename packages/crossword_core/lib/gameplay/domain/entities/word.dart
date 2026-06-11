import 'package:equatable/equatable.dart';

import 'direction.dart';

/// A resolved word: the ordered grid positions a player fills, following the
/// clue's start position and any mid-word redirect turns.
class Word extends Equatable {
  final String id;
  final String? clueId;
  final String? clueText;
  final Direction direction;

  /// Ordered cell positions `(row, col)` from first letter to last.
  final List<(int, int)> cells;

  /// Indices into [cells] after which an intra-answer word break falls.
  final Set<int> separators;

  const Word({
    required this.id,
    required this.direction,
    required this.cells,
    this.clueId,
    this.clueText,
    this.separators = const {},
  });

  /// The local travel axis at the cell at [index] in [cells]. A redirected
  /// word bends, so its tail runs perpendicular to [direction]; this reports
  /// the orientation of the path *at that cell* (the segment entering it, or
  /// leaving it for the first cell), which is what disambiguates the word from
  /// a crossing word sharing the same base [direction].
  Direction axisAt(int index) {
    if (cells.length < 2) return direction;
    final a = index == 0 ? cells[0] : cells[index - 1];
    final b = index == 0 ? cells[1] : cells[index];
    return a.$1 == b.$1 ? Direction.right : Direction.down;
  }

  @override
  List<Object?> get props => [id, clueId, clueText, direction, cells, separators];
}
