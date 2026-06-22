import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart' show Key, UniqueKey;

import 'package:crossword_core/crossword_core.dart';

class GenerateState extends Equatable {
  static const List<int> sizePresets = [11, 15, 17];
  static const List<int> maxWordLenPresets = [5, 6, 8];

  final int width;
  final int height;
  final int maxWordLen;
  final bool isGenerating;

  const GenerateState({
    this.width = 15,
    this.height = 15,
    this.maxWordLen = 6,
    this.isGenerating = false,
  });

  @override
  List<Object?> get props => [width, height, maxWordLen, isGenerating];

  GenerateState copyWith({
    int? width,
    int? height,
    int? maxWordLen,
    bool? isGenerating,
  }) {
    return GenerateState(
      width: width ?? this.width,
      height: height ?? this.height,
      maxWordLen: maxWordLen ?? this.maxWordLen,
      isGenerating: isGenerating ?? this.isGenerating,
    );
  }

  GenerateState.copy(GenerateState state)
      : width = state.width,
        height = state.height,
        maxWordLen = state.maxWordLen,
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

class ShowGenerationError extends GenerateState {
  final String message;
  final Key key = UniqueKey();

  ShowGenerationError({required GenerateState state, required this.message})
      : super.copy(state);

  @override
  List<Object?> get props => [...super.props, message, key];
}
