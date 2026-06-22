export 'gameplay/domain/entities/arrow_shape.dart';
export 'gameplay/domain/entities/cell.dart';
export 'gameplay/domain/entities/clue_arrow.dart';
export 'gameplay/domain/entities/crossword_puzzle.dart';
export 'gameplay/domain/entities/direction.dart';
export 'gameplay/domain/entities/word.dart';
// DTOs are exported for test-fixture construction (puzzle_resolver_test).
// External consumers should prefer CrosswordPuzzle and its domain types.
export 'gameplay/data/entities/dto/grid_cell_dto.dart';
export 'gameplay/data/entities/dto/grid_dto.dart';
export 'gameplay/data/entities/dto/position_dto.dart';
export 'gameplay/data/entities/dto/puzzle_dto.dart';
export 'gameplay/data/local_puzzle_data_source.dart';
export 'gameplay/data/puzzle_resolver.dart';
export 'gameplay/domain/services/arrow_shape_resolver.dart';
export 'load_bundled_puzzle.dart';
