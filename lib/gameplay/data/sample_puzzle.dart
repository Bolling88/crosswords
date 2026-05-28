import 'package:crosswords/gameplay/data/entities/cell.dart';
import 'package:crosswords/gameplay/data/entities/crossword_puzzle.dart';
import 'package:crosswords/gameplay/data/entities/direction.dart';

CrosswordPuzzle buildSamplePuzzle() {
  // 13x15 Swedish korsord grid layout
  // H=hint, .=answer, #=blocked, I=image origin, i=image span
  const layout = [
    'H....#H....#H', // R0
    '....#H...#H..', // R1
    '.H....#H.....', // R2
    '#...#.H...#H.', // R3
    'H......#H...#', // R4
    '..#......#...', // R5
    'H....#H....#.', // R6
    '...#.H.......', // R7
    '#.H...#..H...', // R8
    '....#......#.', // R9
    'H....#H...Iii', // R10
    '...#H.....iii', // R11
    'H.....#...iii', // R12
    '#H...#.......', // R13
    '....#H...#H..', // R14
  ];

  const clues = [
    'Husdjur',
    'Svensk stad',
    'Smak',
    'Fågel',
    'Färg',
    'Årstid',
    'Maträtt',
    'Träd',
    'Land',
    'Yrke',
    'Sport',
    'Blomma',
    'Djur',
    'Dryck',
    'Möbel',
    'Verktyg',
    'Planet',
    'Metall',
    'Tyg',
    'Ö',
    'Krydda',
    'Känsla',
    'Fisk',
  ];

  const fillLetters = 'KVISTNORDHAXFLYGMUDDERPASKEN';

  final cells = <(int, int), Cell>{};
  var clueIndex = 0;
  var letterIndex = 0;

  for (var row = 0; row < layout.length; row++) {
    for (var col = 0; col < layout[row].length; col++) {
      final ch = layout[row][col];
      switch (ch) {
        case 'H':
          final arrows = <Direction>[];
          if (col + 1 < 13 && layout[row][col + 1] == '.') {
            arrows.add(Direction.right);
          }
          if (row + 1 < 15 && layout[row + 1][col] == '.') {
            arrows.add(Direction.down);
          }
          if (arrows.isEmpty) arrows.add(Direction.right);
          cells[(row, col)] = HintCell(
            clueText: clues[clueIndex % clues.length],
            arrows: arrows,
          );
          clueIndex++;
        case '.':
          cells[(row, col)] = AnswerCell(
            solution: fillLetters[letterIndex % fillLetters.length],
          );
          letterIndex++;
        case '#':
          cells[(row, col)] = const BlockedCell();
        case 'I':
          cells[(row, col)] = const ImageCell(
            spanRows: 3,
            spanCols: 3,
            isOrigin: true,
          );
        case 'i':
          cells[(row, col)] = const ImageCell(
            spanRows: 3,
            spanCols: 3,
            isOrigin: false,
          );
      }
    }
  }

  return CrosswordPuzzle(rows: 15, cols: 13, cells: cells);
}
