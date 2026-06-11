import 'package:crossword_core/crossword_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const across = Word(
    id: 'word-1',
    direction: Direction.right,
    cells: [(0, 1), (0, 2)],
  );
  const down = Word(
    id: 'word-2',
    direction: Direction.down,
    cells: [(0, 1), (1, 1)],
  );
  const puzzle = CrosswordPuzzle(
    rows: 2,
    cols: 3,
    cells: {},
    words: [across, down],
    title: 't',
    languageCode: 'sv',
  );

  test('wordById finds by id', () {
    expect(puzzle.wordById('word-2'), down);
    expect(puzzle.wordById('nope'), isNull);
  });

  test('wordAt matches direction and membership', () {
    expect(puzzle.wordAt((0, 1), Direction.right), across);
    expect(puzzle.wordAt((0, 1), Direction.down), down);
    expect(puzzle.wordAt((1, 1), Direction.right), isNull);
  });
}
