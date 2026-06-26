import 'package:crossword_core/crossword_core.dart';

import 'crossword_generation_exception.dart';
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

    // A picture cell spans rowspan×colspan grid positions but the backend
    // emits it as a single origin entry and omits the covered positions, so a
    // row containing a picture has fewer entries than the grid is wide. Derive
    // the dimensions from each cell's own coordinates and span (not the ragged
    // list shape) — otherwise `cols`/`rows` undercount by span-1 and the table
    // clips the rightmost/bottom cells while the arrow overlay still paints.
    var maxRow = -1;
    var maxCol = -1;
    for (final row in gridCells) {
      for (final c in row) {
        final bottom = c.row + c.rowspan - 1;
        final right = c.col + c.colspan - 1;
        if (bottom > maxRow) maxRow = bottom;
        if (right > maxCol) maxCol = right;
      }
    }
    final rows = maxRow + 1;
    final cols = maxCol + 1;

    // FIX 3: reject empty grid early so callers get a clear error.
    if (rows == 0 || cols == 0) {
      throw const CrosswordGenerationException('Generated puzzle has an empty grid');
    }

    final slotById = {for (final s in slots) s.slotId: s};

    final cells = <(int, int), Cell>{};
    final separatorEdges = <(int, int), Set<Direction>>{};
    final seedPositions = <(int, int)>{
      for (final s in seedCells) (s.row, s.col),
    };

    // Build a row-major solution signature that feeds a stable hash for the
    // puzzle id: answer cells contribute their letter, all other kinds
    // contribute '#'. FNV-1a is used so the id is deterministic across app
    // launches (String.hashCode is not stable).
    final solutionBuffer = StringBuffer();

    for (final row in gridCells) {
      for (final c in row) {
        final pos = (c.row, c.col);
        switch (c.kind) {
          case 'answer':
            // The generator emits answer cells that belong to no word (null
            // letter, empty word_ids). These are inert open positions, not a
            // malformed response, so render them as blocks rather than
            // aborting the whole puzzle.
            final letter = c.letter;
            if (letter == null) {
              cells[pos] = const BlockCell();
              solutionBuffer.write('#');
              break;
            }
            cells[pos] = AnswerCell(
              value: letter,
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
            solutionBuffer.write(letter);
          case 'clue':
            // FIX 5: a missing slot referenced by a clue tag is a malformed
            // response — throw rather than silently dropping the arrow.
            cells[pos] = ClueCell(arrows: _arrowsFor(c, slotById));
            solutionBuffer.write('#');
          default:
            // 'picture' / 'arrow' kinds are not produced with pictures off;
            // treat anything else as an inert block.
            cells[pos] = const BlockCell();
            solutionBuffer.write('#');
        }
      }
    }

    // FIX 9: hash the solution so the id is compact and does not embed answers
    // in plaintext (e.g. as a SharedPreferences key).
    final id = 'gen-${rows}x$cols-${_stableHash(solutionBuffer.toString())}';

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

    // Invariant: every grid cell that a word's path covers must be an AnswerCell.
    // A null-letter generator cell becomes a BlockCell, which is fine for inert
    // open positions, but if a slot's path covers such a position the puzzle is
    // corrupt — a Word would span a BlockCell, which gameplay code cannot handle.
    for (final word in words) {
      for (final pos in word.cells) {
        final cell = cells[pos];
        if (cell != null && cell is! AnswerCell) {
          throw CrosswordGenerationException(
            'Word ${word.id} path includes non-AnswerCell at (${pos.$1}, ${pos.$2})',
          );
        }
      }
    }

    return CrosswordPuzzle(
      rows: rows,
      cols: cols,
      cells: cells,
      words: words,
      seedPositions: seedPositions,
      separatorEdges: separatorEdges,
      id: id,
      title: title,
      languageCode: 'sv',
    );
  }

  /// Builds [ClueArrow]s for a clue cell, throwing on a missing slot. Arrows
  /// are ordered top-first (smaller word-start row, then col) so the renderer
  /// can split a two-clue box into top/bottom compartments without slot data.
  static List<ClueArrow> _arrowsFor(
    GenerationGridCellDto cell,
    Map<int, GenerationSlotDto> slotById,
  ) {
    final entries = <(GenerationSlotDto, ClueArrow)>[];
    for (final tag in cell.clueTags) {
      final slot = slotById[tag.id];
      if (slot == null) {
        throw CrosswordGenerationException(
          'Clue tag ${tag.id} references a missing slot',
        );
      }
      final dir = _direction(slot.direction);
      entries.add((
        slot,
        ClueArrow(
          direction: dir,
          shape: ArrowShapeResolver.resolve(
            clueRow: slot.clueRow,
            clueCol: slot.clueCol,
            startRow: slot.startRow,
            startCol: slot.startCol,
            base: dir,
          ),
          wordId: slot.slotId.toString(),
        ),
      ));
    }
    entries.sort((a, b) {
      final byRow = a.$1.startRow.compareTo(b.$1.startRow);
      return byRow != 0 ? byRow : a.$1.startCol.compareTo(b.$1.startCol);
    });
    return [for (final entry in entries) entry.$2];
  }

  /// FIX 4: unknown directions throw instead of assert-then-default.
  static Direction _direction(String raw) {
    switch (raw) {
      case 'right':
        return Direction.right;
      case 'down':
        return Direction.down;
      default:
        throw CrosswordGenerationException('Unknown slot direction: $raw');
    }
  }

  /// FNV-1a 32-bit hash — deterministic across app launches (unlike
  /// String.hashCode), so a generated puzzle maps to the same persistence key
  /// every run without embedding the solution in cleartext.
  static String _stableHash(String input) {
    var hash = 0x811c9dc5;
    for (final unit in input.codeUnits) {
      hash = (hash ^ unit) & 0xFFFFFFFF;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}
