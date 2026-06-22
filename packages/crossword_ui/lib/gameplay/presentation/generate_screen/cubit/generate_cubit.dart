import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:crossword_api/crossword_api.dart';

import '../../../../common/data/constants/strings.dart';
import 'generate_state.dart';

class GeneratePuzzleCubit extends Cubit<GenerateState> {
  final PuzzleGenerationService _service;
  final TextEditingController seedWordsController = TextEditingController();

  GeneratePuzzleCubit({required PuzzleGenerationService service})
      : _service = service,
        super(const GenerateState());

  void selectSize(int size) =>
      emit(state.copyWith(width: size, height: size));

  void selectMaxWordLen(int value) =>
      emit(state.copyWith(maxWordLen: value));

  Future<void> generate() async {
    emit(state.copyWith(isGenerating: true));
    try {
      final puzzle = await _service.generate(
        width: state.width,
        height: state.height,
        maxWordLen: state.maxWordLen,
        title: Strings.generatedPuzzleTitle,
        seedWords: _parseSeedWords(seedWordsController.text),
      );
      emit(GenerationSucceeded(
        state: state.copyWith(isGenerating: false),
        puzzle: puzzle,
      ));
    } catch (_) {
      emit(ShowGenerationError(
        state: state.copyWith(isGenerating: false),
        message: Strings.generationErrorMessage,
      ));
    }
  }

  Future<void> openTestPuzzle() async {
    try {
      final puzzle = await _service.loadTestPuzzle();
      emit(GenerationSucceeded(state: state, puzzle: puzzle));
    } catch (_) {
      emit(ShowGenerationError(
        state: state,
        message: Strings.generationErrorMessage,
      ));
    }
  }

  List<String> _parseSeedWords(String raw) => raw
      .split(RegExp(r'[,\s]+'))
      .map((w) => w.trim().toUpperCase())
      .where((w) => w.isNotEmpty)
      .toList();

  @override
  Future<void> close() {
    seedWordsController.dispose();
    return super.close();
  }
}
