import 'package:equatable/equatable.dart';

import '../../../../gameplay/data/entities/crossword_puzzle.dart';
import '../../../../gameplay/data/entities/direction.dart';

class CrosswordState extends Equatable {
  final CrosswordPuzzle puzzle;
  final Map<(int, int), String> userInputs;
  final (int, int)? selectedCell;
  final Direction currentDirection;
  final Set<(int, int)> highlightedCells;

  const CrosswordState({
    required this.puzzle,
    this.userInputs = const <(int, int), String>{},
    this.selectedCell,
    this.currentDirection = Direction.right,
    this.highlightedCells = const <(int, int)>{},
  });

  @override
  List<Object?> get props => [
        userInputs,
        selectedCell,
        currentDirection,
        highlightedCells,
      ];

  CrosswordState copyWith({
    Map<(int, int), String>? userInputs,
    (int, int)? selectedCell,
    Direction? currentDirection,
    Set<(int, int)>? highlightedCells,
  }) {
    return CrosswordState(
      puzzle: puzzle,
      userInputs: userInputs ?? this.userInputs,
      selectedCell: selectedCell ?? this.selectedCell,
      currentDirection: currentDirection ?? this.currentDirection,
      highlightedCells: highlightedCells ?? this.highlightedCells,
    );
  }
}
