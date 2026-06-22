import 'package:crossword_core/crossword_core.dart';

import 'crossword_generation_repository.dart';

/// Domain entry point for puzzle acquisition. Cubits depend on this rather than
/// the repository directly. [loadTestPuzzle] returns the bundled developer
/// puzzle.
class PuzzleGenerationService {
  final CrosswordGenerationRepository _repository;
  final Future<CrosswordPuzzle> Function() _loadTestPuzzleFn;

  PuzzleGenerationService({
    required CrosswordGenerationRepository repository,
    Future<CrosswordPuzzle> Function()? loadTestPuzzleFn,
  })  : _repository = repository,
        _loadTestPuzzleFn = loadTestPuzzleFn ?? loadBundledPuzzle;

  Future<CrosswordPuzzle> generate({
    required int width,
    required int height,
    required int maxWordLen,
    required String title,
    List<String> seedWords = const [],
  }) =>
      _repository.generate(
        width: width,
        height: height,
        maxWordLen: maxWordLen,
        title: title,
        seedWords: seedWords,
      );

  Future<CrosswordPuzzle> loadTestPuzzle() => _loadTestPuzzleFn();
}
