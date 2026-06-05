import 'package:crosswords/gameplay/data/entities/dto/grid_cell_dto.dart';
import 'package:crosswords/gameplay/data/entities/dto/grid_dto.dart';
import 'package:crosswords/gameplay/data/entities/dto/position_dto.dart';
import 'package:crosswords/gameplay/data/entities/dto/puzzle_dto.dart';
import 'package:crosswords/gameplay/data/puzzle_resolver.dart';
import 'package:crosswords/gameplay/domain/entities/arrow_shape.dart';
import 'package:crosswords/gameplay/domain/entities/cell.dart';
import 'package:crosswords/gameplay/domain/entities/direction.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a PuzzleDto from a compact grid spec for focused tests.
PuzzleDto _puzzle(List<List<GridCellDto>> rows, {List<PositionDto> seeds = const []}) {
  return PuzzleDto(
    title: 't',
    languageCode: 'sv',
    grid: GridDto(width: rows.first.length, height: rows.length, rows: rows),
    seedPositions: seeds,
  );
}

const _block = BlockCellDto();
AnswerCellDto _a(
  String v, {
  bool rightRedirect = false,
  bool downRedirect = false,
  String? rightSeparator,
}) =>
    AnswerCellDto(
      value: v,
      rightRedirect: rightRedirect,
      downRedirect: downRedirect,
      rightSeparator: rightSeparator,
    );

void main() {
  test('resolves a straight across word', () {
    final dto = _puzzle([
      [
        const ClueCellDto(rightWordId: 'w1', rightClueId: 'c1', rightStart: PositionDto(col: 1, row: 0)),
        _a('C'),
        _a('A'),
        _a('T'),
      ],
    ]);

    final puzzle = PuzzleResolver.resolve(dto);
    final word = puzzle.wordById('w1');

    expect(word, isNotNull);
    expect(word!.direction, Direction.right);
    expect(word.cells, [(0, 1), (0, 2), (0, 3)]);
  });

  test('clue arrow shape is straightRight when start is adjacent right', () {
    final dto = _puzzle([
      [
        const ClueCellDto(rightWordId: 'w1', rightStart: PositionDto(col: 1, row: 0)),
        _a('A'),
        _a('B'),
      ],
    ]);

    final clue = PuzzleResolver.resolve(dto).cells[(0, 0)] as ClueCell;
    expect(clue.arrows.single.shape, ArrowShape.straightRight);
  });

  test('bent arrow: across word whose start is below the clue', () {
    // Clue at (0,0). Across word starts at (1,0) and runs right.
    final dto = _puzzle([
      [
        const ClueCellDto(rightWordId: 'w1', rightStart: PositionDto(col: 0, row: 1)),
        _block,
        _block,
      ],
      [
        _a('A'),
        _a('B'),
        _a('C'),
      ],
    ]);

    final puzzle = PuzzleResolver.resolve(dto);
    final clue = puzzle.cells[(0, 0)] as ClueCell;
    expect(clue.arrows.single.shape, ArrowShape.bentDownThenRight);
    expect(puzzle.wordById('w1')!.cells, [(1, 0), (1, 1), (1, 2)]);
  });

  test('redirect: across word turns down at a right_redirect cell', () {
    // A B(redirect) then down to C, D.
    final dto = _puzzle([
      [
        const ClueCellDto(rightWordId: 'w1', rightStart: PositionDto(col: 1, row: 0)),
        _a('A'),
        _a('B', rightRedirect: true),
      ],
      [
        _block,
        _block,
        _a('C'),
      ],
      [
        _block,
        _block,
        _a('D'),
      ],
    ]);

    final word = PuzzleResolver.resolve(dto).wordById('w1');
    expect(word!.cells, [(0, 1), (0, 2), (1, 2), (2, 2)]);
  });

  test('records separator index and a right separator edge', () {
    final dto = _puzzle([
      [
        const ClueCellDto(rightWordId: 'w1', rightStart: PositionDto(col: 1, row: 0)),
        _a('A', rightSeparator: '_'),
        _a('B'),
      ],
    ]);

    final puzzle = PuzzleResolver.resolve(dto);
    expect(puzzle.wordById('w1')!.separators, {0});
    expect(puzzle.separatorEdges[(0, 1)], contains(Direction.right));
  });

  test('two-clue cell yields an across and a down word with two arrows', () {
    final dto = _puzzle([
      [
        const ClueCellDto(
          rightWordId: 'across',
          rightStart: PositionDto(col: 1, row: 0),
          downWordId: 'down',
          downStart: PositionDto(col: 0, row: 1),
        ),
        _a('A'),
      ],
      [
        _a('B'),
        _block,
      ],
    ]);

    final puzzle = PuzzleResolver.resolve(dto);
    final clue = puzzle.cells[(0, 0)] as ClueCell;
    expect(clue.arrows.length, 2);
    expect(puzzle.wordById('across')!.direction, Direction.right);
    expect(puzzle.wordById('down')!.direction, Direction.down);
  });

  test('marks seed answer cells and preserves åäö values', () {
    final dto = _puzzle([
      [
        const ClueCellDto(rightWordId: 'w1', rightStart: PositionDto(col: 1, row: 0)),
        _a('Å'),
        _a('Ä'),
      ],
    ], seeds: const [PositionDto(col: 1, row: 0)]);

    final puzzle = PuzzleResolver.resolve(dto);
    final seedCell = puzzle.cells[(0, 1)] as AnswerCell;
    final plainCell = puzzle.cells[(0, 2)] as AnswerCell;
    expect(seedCell.value, 'Å');
    expect(seedCell.isSeed, isTrue);
    expect(plainCell.isSeed, isFalse);
  });
}
