import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';

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

  /// Clue cell of the active word, highlighted so the player can see which
  /// clue (and direction) they are filling.
  final (int, int)? activeClueCell;

  /// Cells marked wrong by a check action or autocheck. Editing a cell
  /// removes its mark.
  final Set<(int, int)> incorrectCells;

  /// Cells filled via reveal. They render muted and can no longer be edited.
  final Set<(int, int)> revealedCells;

  /// True when every fillable cell holds its solution letter.
  final bool isSolved;

  /// Word that most recently verified fully correct (check, autocheck, or
  /// reveal) plus a token bumped per confirmation; together they key the
  /// one-shot confirmation flash in the grid.
  final String? confirmedWordId;
  final int confirmedWordToken;

  final AppFont font;

  const CrosswordState({
    required this.puzzle,
    this.userInputs = const <(int, int), String>{},
    this.selectedCell,
    this.activeWordId,
    this.currentDirection = Direction.right,
    this.highlightedCells = const <(int, int)>{},
    this.activeClueCell,
    this.incorrectCells = const <(int, int)>{},
    this.revealedCells = const <(int, int)>{},
    this.isSolved = false,
    this.confirmedWordId,
    this.confirmedWordToken = 0,
    this.font = AppFont.defaultFont,
  });

  CrosswordState.copy(CrosswordState state)
      : puzzle = state.puzzle,
        userInputs = state.userInputs,
        selectedCell = state.selectedCell,
        activeWordId = state.activeWordId,
        currentDirection = state.currentDirection,
        highlightedCells = state.highlightedCells,
        activeClueCell = state.activeClueCell,
        incorrectCells = state.incorrectCells,
        revealedCells = state.revealedCells,
        isSolved = state.isSolved,
        confirmedWordId = state.confirmedWordId,
        confirmedWordToken = state.confirmedWordToken,
        font = state.font;

  @override
  List<Object?> get props => [
        puzzle,
        userInputs,
        selectedCell,
        activeWordId,
        currentDirection,
        highlightedCells,
        activeClueCell,
        incorrectCells,
        revealedCells,
        isSolved,
        confirmedWordId,
        confirmedWordToken,
        font,
      ];

  /// Carries [activeClueCell], [confirmedWordId], and [confirmedWordToken]
  /// through unchanged — those are only set via the dedicated `with*`
  /// transitions (the project avoids sentinel-based copyWith for nullables).
  CrosswordState copyWith({
    Map<(int, int), String>? userInputs,
    (int, int)? selectedCell,
    String? activeWordId,
    Direction? currentDirection,
    Set<(int, int)>? highlightedCells,
    Set<(int, int)>? incorrectCells,
    Set<(int, int)>? revealedCells,
    bool? isSolved,
    AppFont? font,
  }) {
    return CrosswordState(
      puzzle: puzzle,
      userInputs: userInputs ?? this.userInputs,
      selectedCell: selectedCell ?? this.selectedCell,
      activeWordId: activeWordId ?? this.activeWordId,
      currentDirection: currentDirection ?? this.currentDirection,
      highlightedCells: highlightedCells ?? this.highlightedCells,
      activeClueCell: activeClueCell,
      incorrectCells: incorrectCells ?? this.incorrectCells,
      revealedCells: revealedCells ?? this.revealedCells,
      isSolved: isSolved ?? this.isSolved,
      confirmedWordId: confirmedWordId,
      confirmedWordToken: confirmedWordToken,
      font: font ?? this.font,
    );
  }

  /// Activate [wordId] with its full selection context in one transition.
  /// Separate from [copyWith] because [activeClueCell] is nullable (a word
  /// may have no clue cell) and the project avoids sentinel-based copyWith.
  CrosswordState withActiveWord({
    required String wordId,
    required (int, int) selectedCell,
    required Direction direction,
    required Set<(int, int)> highlightedCells,
    required (int, int)? clueCell,
    Map<(int, int), String>? userInputs,
  }) {
    return CrosswordState(
      puzzle: puzzle,
      userInputs: userInputs ?? this.userInputs,
      selectedCell: selectedCell,
      activeWordId: wordId,
      currentDirection: direction,
      highlightedCells: highlightedCells,
      activeClueCell: clueCell,
      incorrectCells: incorrectCells,
      revealedCells: revealedCells,
      isSolved: isSolved,
      confirmedWordId: confirmedWordId,
      confirmedWordToken: confirmedWordToken,
      font: font,
    );
  }

  /// Select [cell] as a standalone cell that belongs to no word, clearing the
  /// active word (and its clue highlight) so later navigation and typing
  /// don't act on a stale word.
  CrosswordState withLoneCell((int, int) cell) {
    return CrosswordState(
      puzzle: puzzle,
      userInputs: userInputs,
      selectedCell: cell,
      activeWordId: null,
      currentDirection: currentDirection,
      highlightedCells: {cell},
      activeClueCell: null,
      incorrectCells: incorrectCells,
      revealedCells: revealedCells,
      isSolved: isSolved,
      confirmedWordId: confirmedWordId,
      confirmedWordToken: confirmedWordToken,
      font: font,
    );
  }

  /// Record that [wordId] just verified fully correct, bumping the token that
  /// keys the grid's confirmation flash.
  CrosswordState withConfirmedWord(String wordId) {
    return CrosswordState(
      puzzle: puzzle,
      userInputs: userInputs,
      selectedCell: selectedCell,
      activeWordId: activeWordId,
      currentDirection: currentDirection,
      highlightedCells: highlightedCells,
      activeClueCell: activeClueCell,
      incorrectCells: incorrectCells,
      revealedCells: revealedCells,
      isSolved: isSolved,
      confirmedWordId: wordId,
      confirmedWordToken: confirmedWordToken + 1,
      font: font,
    );
  }
}

/// One-shot event: the puzzle was just solved. Listener shows the
/// celebration dialog.
class PuzzleSolved extends CrosswordState {
  final Key key = UniqueKey();

  PuzzleSolved({required CrosswordState state}) : super.copy(state);

  @override
  List<Object?> get props => [...super.props, key];
}

/// One-shot event: the grid just became full but isn't correct. Listener
/// shows a gentle SnackBar nudge.
class PuzzleFilledButIncorrect extends CrosswordState {
  final Key key = UniqueKey();

  PuzzleFilledButIncorrect({required CrosswordState state}) : super.copy(state);

  @override
  List<Object?> get props => [...super.props, key];
}
