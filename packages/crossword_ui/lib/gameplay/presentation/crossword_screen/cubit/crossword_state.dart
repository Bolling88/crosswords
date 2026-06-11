import 'package:equatable/equatable.dart';
import 'package:crossword_core/crossword_core.dart';

import '../../../../settings/domain/entities/app_font.dart';

class CrosswordState extends Equatable {
  final CrosswordPuzzle puzzle;
  final Map<(int, int), String> userInputs;
  final (int, int)? selectedCell;

  /// Id of the word the player is currently filling. Navigation follows this
  /// word's ordered cell path, which is what lets a bent/redirected word be
  /// typed straight through its turn.
  final String? activeWordId;
  final Direction currentDirection;
  final Set<(int, int)> highlightedCells;
  final AppFont font;

  const CrosswordState({
    required this.puzzle,
    this.userInputs = const <(int, int), String>{},
    this.selectedCell,
    this.activeWordId,
    this.currentDirection = Direction.right,
    this.highlightedCells = const <(int, int)>{},
    this.font = AppFont.defaultFont,
  });

  @override
  List<Object?> get props => [
        puzzle,
        userInputs,
        selectedCell,
        activeWordId,
        currentDirection,
        highlightedCells,
        font,
      ];

  CrosswordState copyWith({
    Map<(int, int), String>? userInputs,
    (int, int)? selectedCell,
    String? activeWordId,
    Direction? currentDirection,
    Set<(int, int)>? highlightedCells,
    AppFont? font,
  }) {
    return CrosswordState(
      puzzle: puzzle,
      userInputs: userInputs ?? this.userInputs,
      selectedCell: selectedCell ?? this.selectedCell,
      activeWordId: activeWordId ?? this.activeWordId,
      currentDirection: currentDirection ?? this.currentDirection,
      highlightedCells: highlightedCells ?? this.highlightedCells,
      font: font ?? this.font,
    );
  }

  /// Select [cell] as a standalone cell that belongs to no word, clearing the
  /// active word so later navigation and typing don't act on a stale word.
  /// (Separate from [copyWith] because that cannot null [activeWordId].)
  CrosswordState withLoneCell((int, int) cell) {
    return CrosswordState(
      puzzle: puzzle,
      userInputs: userInputs,
      selectedCell: cell,
      activeWordId: null,
      currentDirection: currentDirection,
      highlightedCells: {cell},
      font: font,
    );
  }
}
