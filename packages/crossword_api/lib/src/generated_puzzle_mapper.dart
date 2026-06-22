import 'package:crossword_core/crossword_core.dart';

import 'dto/crossword_generation_response.dart';

/// Converts a successful [CrosswordGenerationResponse] into a playable
/// [CrosswordPuzzle]. Slots are straight runs; each becomes one [Word], and
/// each clue tag becomes a [ClueArrow] whose glyph is derived from the clue's
/// position relative to its slot's start. Clue prose is not provided by the
/// generator yet, so [Word.clueText] stays null.
class GeneratedPuzzleMapper {
  const GeneratedPuzzleMapper._();

  static CrosswordPuzzle map(
    CrosswordGenerationResponse response, {
    required String title,
  }) {
    final gridCells = response.gridCells ?? const [];
    final slots = response.slots ?? const [];
    final seedCells = response.seedCells ?? const [];

    final rows = gridCells.length;
    final cols = rows == 0 ? 0 : gridCells.first.length;

    final slotById = {for (final s in slots) s.slotId: s};

    final cells = <(int, int), Cell>{};
    final separatorEdges = <(int, int), Set<Direction>>{};
    final seedPositions = <(int, int)>{
      for (final s in seedCells) (s.row, s.col),
    };

    for (final row in gridCells) {
      for (final c in row) {
        final pos = (c.row, c.col);
        switch (c.kind) {
          case 'answer':
            cells[pos] = AnswerCell(
              value: c.letter ?? '',
              isSeed: seedPositions.contains(pos),
            );
            if (c.sepRight.isNotEmpty) {
              separatorEdges
                  .putIfAbsent(pos, () => <Direction>{})
                  .add(Direction.right);
            }
            if (c.sepBottom.isNotEmpty) {
              separatorEdges
                  .putIfAbsent(pos, () => <Direction>{})
                  .add(Direction.down);
            }
          case 'clue':
            cells[pos] = ClueCell(
              arrows: [
                for (final tag in c.clueTags)
                  if (slotById[tag.id] case final slot?)
                    ClueArrow(
                      direction: _direction(slot.direction),
                      shape: ArrowShapeResolver.resolve(
                        clueRow: slot.clueRow,
                        clueCol: slot.clueCol,
                        startRow: slot.startRow,
                        startCol: slot.startCol,
                        base: _direction(slot.direction),
                      ),
                      wordId: slot.slotId.toString(),
                    ),
              ],
            );
          default:
            // 'picture' / 'arrow' kinds are not produced with pictures off;
            // treat anything else as an inert block.
            cells[pos] = const BlockCell();
        }
      }
    }

    final words = <Word>[];
    for (final slot in slots) {
      final dir = _direction(slot.direction);
      final path = <(int, int)>[];
      for (var i = 0; i < slot.length; i++) {
        final r = dir == Direction.right ? slot.startRow : slot.startRow + i;
        final cc = dir == Direction.right ? slot.startCol + i : slot.startCol;
        path.add((r, cc));
      }
      words.add(Word(
        id: slot.slotId.toString(),
        direction: dir,
        cells: path,
      ));
    }

    return CrosswordPuzzle(
      rows: rows,
      cols: cols,
      cells: cells,
      words: words,
      seedPositions: seedPositions,
      separatorEdges: separatorEdges,
      title: title,
      languageCode: 'sv',
    );
  }

  static Direction _direction(String raw) {
    assert(
      raw == 'right' || raw == 'down',
      'Unexpected slot direction: $raw',
    );
    return raw == 'down' ? Direction.down : Direction.right;
  }
}
