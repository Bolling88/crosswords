import 'package:equatable/equatable.dart';

import 'arrow_shape.dart';
import 'direction.dart';

/// One arrow drawn in a clue cell, pointing at the word it introduces.
class ClueArrow extends Equatable {
  final Direction direction;
  final ArrowShape shape;
  final String wordId;

  const ClueArrow({
    required this.direction,
    required this.shape,
    required this.wordId,
  });

  @override
  List<Object?> get props => [direction, shape, wordId];
}
