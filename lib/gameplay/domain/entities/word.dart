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

  @override
  List<Object?> get props => [id, clueId, clueText, direction, cells, separators];
}
