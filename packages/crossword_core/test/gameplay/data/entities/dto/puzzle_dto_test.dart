import 'dart:convert';
import 'dart:io';

import 'package:crossword_core/crossword_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses the bundled generator JSON', () {
    final raw = File('assets/puzzles/generated_crossword.json').readAsStringSync();
    final dto = PuzzleDto.fromJson(jsonDecode(raw) as Map<String, dynamic>);

    expect(dto.title, 'Generated crossword');
    expect(dto.languageCode, 'sv');
    expect(dto.grid.width, 13);
    expect(dto.grid.height, 15);
    expect(dto.grid.rows.length, 15);
    expect(dto.grid.rows.every((r) => r.length == 13), isTrue);
    expect(dto.seedPositions.length, 14);

    // First cell is a clue that points right with a non-adjacent start.
    final first = dto.grid.rows[0][0] as ClueCellDto;
    expect(first.rightWordId, 'word-12');
    expect(first.rightStart?.row, 1);
    expect(first.rightStart?.col, 0);

    // A redirected answer cell exists (row 2, col 12 -> "K", right_redirect).
    final redirected = dto.grid.rows[2][12] as AnswerCellDto;
    expect(redirected.value, 'K');
    expect(redirected.rightRedirect, isTrue);

    // A separator cell exists (row 13, col 1 -> "I", right_separator "_").
    final separated = dto.grid.rows[13][1] as AnswerCellDto;
    expect(separated.rightSeparator, '_');
  });
}
