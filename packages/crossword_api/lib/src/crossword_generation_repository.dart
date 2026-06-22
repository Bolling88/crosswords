import 'package:crossword_core/crossword_core.dart';

import 'crossword_generation_remote_data_source.dart';
import 'dto/crossword_generation_request.dart';
import 'generated_puzzle_mapper.dart';

/// Coordinates the remote data source and the mapper, returning a playable
/// [CrosswordPuzzle].
class CrosswordGenerationRepository {
  final CrosswordGenerationRemoteDataSource _remoteDataSource;

  CrosswordGenerationRepository({
    required CrosswordGenerationRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  Future<CrosswordPuzzle> generate({
    required int width,
    required int height,
    required int maxWordLen,
    required String title,
    List<String> seedWords = const [],
  }) async {
    final response = await _remoteDataSource.generate(
      CrosswordGenerationRequest(
        width: width,
        height: height,
        maxWordLen: maxWordLen,
        seedWords: seedWords,
      ),
    );
    return GeneratedPuzzleMapper.map(response, title: title);
  }
}
