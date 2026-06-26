import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:crossword_api/crossword_api.dart';

import 'generate_state.dart';

class GeneratePuzzleCubit extends Cubit<GenerateState> {
  final PuzzleGenerationService _service;

  /// The localized default title stamped onto a generated puzzle. Resolved by
  /// the screen from [CrosswordUiL10n] and injected here so the cubit never
  /// touches localization itself.
  final String _generatedPuzzleTitle;

  final TextEditingController seedWordsController = TextEditingController();
  final TextEditingController randomSeedController = TextEditingController();

  GeneratePuzzleCubit({
    required PuzzleGenerationService service,
    required String generatedPuzzleTitle,
  })  : _service = service,
        _generatedPuzzleTitle = generatedPuzzleTitle,
        super(const GenerateState());

  void selectSize(int size) => emit(
        state.copyWith(
          width: size,
          height: size,
          pictureCols:
              state.pictureCols > size ? size : state.pictureCols,
          pictureRows:
              state.pictureRows > size ? size : state.pictureRows,
        ),
      );

  void selectMaxWordLen(int value) =>
      emit(state.copyWith(maxWordLen: value));

  void selectLanguage(String code) =>
      emit(state.copyWith(languageCode: code));

  void incrementMaxSeconds() => emit(
        state.copyWith(
          maxSeconds: _clamp(
            state.maxSeconds + GenerateState.maxSecondsStep,
            GenerateState.minMaxSeconds,
            GenerateState.maxMaxSeconds,
          ),
        ),
      );

  void decrementMaxSeconds() => emit(
        state.copyWith(
          maxSeconds: _clamp(
            state.maxSeconds - GenerateState.maxSecondsStep,
            GenerateState.minMaxSeconds,
            GenerateState.maxMaxSeconds,
          ),
        ),
      );

  void incrementPictureCols() => emit(
        state.copyWith(
          pictureCols: _clamp(
            state.pictureCols + 1,
            GenerateState.minPictureDim,
            state.width,
          ),
        ),
      );

  void decrementPictureCols() => emit(
        state.copyWith(
          pictureCols: _clamp(
            state.pictureCols - 1,
            GenerateState.minPictureDim,
            state.width,
          ),
        ),
      );

  void incrementPictureRows() => emit(
        state.copyWith(
          pictureRows: _clamp(
            state.pictureRows + 1,
            GenerateState.minPictureDim,
            state.height,
          ),
        ),
      );

  void decrementPictureRows() => emit(
        state.copyWith(
          pictureRows: _clamp(
            state.pictureRows - 1,
            GenerateState.minPictureDim,
            state.height,
          ),
        ),
      );

  Future<void> generate() async {
    emit(state.copyWith(isGenerating: true));
    try {
      final puzzle = await _service.generate(
        width: state.width,
        height: state.height,
        maxWordLen: state.maxWordLen,
        title: _generatedPuzzleTitle,
        seedWords: _parseSeedWords(seedWordsController.text),
        languageCode: state.languageCode,
        randomSeed: _parseRandomSeed(randomSeedController.text),
        maxSeconds: state.maxSeconds,
        pictureCols: state.pictureCols,
        pictureRows: state.pictureRows,
      );
      emit(GenerationSucceeded(
        state: state.copyWith(isGenerating: false),
        puzzle: puzzle,
      ));
    } catch (e, stack) {
      debugPrint('Puzzle generation failed: $e');
      debugPrint('$stack');
      emit(ShowGenerationError(state: state.copyWith(isGenerating: false)));
    }
  }

  Future<void> openTestPuzzle() async {
    emit(state.copyWith(isGenerating: true));
    try {
      final puzzle = await _service.loadTestPuzzle();
      emit(GenerationSucceeded(
        state: state.copyWith(isGenerating: false),
        puzzle: puzzle,
      ));
    } catch (e, stack) {
      debugPrint('Test puzzle load failed: $e');
      debugPrint('$stack');
      emit(ShowGenerationError(state: state.copyWith(isGenerating: false)));
    }
  }

  int _clamp(int value, int min, int max) =>
      value < min ? min : (value > max ? max : value);

  List<String> _parseSeedWords(String raw) => raw
      .split(RegExp(r'[,\s]+'))
      .map((w) => w.trim().toUpperCase())
      .where((w) => w.isNotEmpty)
      .toList();

  int? _parseRandomSeed(String raw) => int.tryParse(raw.trim());

  @override
  Future<void> close() {
    seedWordsController.dispose();
    randomSeedController.dispose();
    return super.close();
  }
}
