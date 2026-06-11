import 'gameplay/data/local_puzzle_data_source.dart';
import 'gameplay/domain/entities/crossword_puzzle.dart';

/// Loads the bundled crossword shipped inside this package.
Future<CrosswordPuzzle> loadBundledPuzzle() =>
    LocalPuzzleDataSource().loadGeneratedPuzzle();
