import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart' show Key, UniqueKey;

import 'package:crossword_core/crossword_core.dart';

class GenerateState extends Equatable {
  static const List<int> sizePresets = [11, 15, 17];
  static const List<int> maxWordLenPresets = [5, 6, 8];

  static const int minMaxSeconds = 5;
  static const int maxMaxSeconds = 120;
  static const int maxSecondsStep = 5;
  static const int minPictureDim = 0;

  final int width;
  final int height;
  final int maxWordLen;
  final String languageCode;
  final int maxSeconds;
  final int pictureCols;
  final int pictureRows;
  final bool isGenerating;

  const GenerateState({
    this.width = 15,
    this.height = 15,
    this.maxWordLen = 6,
    this.languageCode = 'sv',
    this.maxSeconds = 30,
    this.pictureCols = 0,
    this.pictureRows = 0,
    this.isGenerating = false,
  });

  @override
  List<Object?> get props => [
        width,
        height,
        maxWordLen,
        languageCode,
        maxSeconds,
        pictureCols,
        pictureRows,
        isGenerating,
      ];

  GenerateState copyWith({
    int? width,
    int? height,
    int? maxWordLen,
    String? languageCode,
    int? maxSeconds,
    int? pictureCols,
    int? pictureRows,
    bool? isGenerating,
  }) {
    return GenerateState(
      width: width ?? this.width,
      height: height ?? this.height,
      maxWordLen: maxWordLen ?? this.maxWordLen,
      languageCode: languageCode ?? this.languageCode,
      maxSeconds: maxSeconds ?? this.maxSeconds,
      pictureCols: pictureCols ?? this.pictureCols,
      pictureRows: pictureRows ?? this.pictureRows,
      isGenerating: isGenerating ?? this.isGenerating,
    );
  }

  GenerateState.copy(GenerateState state)
      : width = state.width,
        height = state.height,
        maxWordLen = state.maxWordLen,
        languageCode = state.languageCode,
        maxSeconds = state.maxSeconds,
        pictureCols = state.pictureCols,
        pictureRows = state.pictureRows,
        isGenerating = state.isGenerating;
}

class GenerationSucceeded extends GenerateState {
  final CrosswordPuzzle puzzle;
  final Key key = UniqueKey();

  GenerationSucceeded({required GenerateState state, required this.puzzle})
      : super.copy(state);

  @override
  List<Object?> get props => [...super.props, puzzle, key];
}

/// Event state: generation failed. Carries no copy — the screen renders the
/// localized [CrosswordUiL10n.generationErrorMessage] itself.
class ShowGenerationError extends GenerateState {
  final Key key = UniqueKey();

  ShowGenerationError({required GenerateState state}) : super.copy(state);

  @override
  List<Object?> get props => [...super.props, key];
}
