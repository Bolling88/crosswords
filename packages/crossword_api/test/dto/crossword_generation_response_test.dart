import 'dart:convert';
import 'dart:io';

import 'package:crossword_api/crossword_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fromJson parses the live 9x9 sample', () {
    final raw = File('test/fixtures/generation_response_9x9.json')
        .readAsStringSync();
    final res = CrosswordGenerationResponse.fromJson(
        jsonDecode(raw) as Map<String, dynamic>);

    expect(res.success, isTrue);
    expect(res.failureReason, isNull);

    final grid = res.gridCells;
    expect(grid, isNotNull);
    expect(grid?.length, 9);
    expect(grid?.first.length, 9);

    final slots = res.slots;
    expect(slots?.length, 26);

    final assignments = res.assignments;
    expect(assignments?.length, 26);

    final slot0 = slots?.firstWhere((s) => s.slotId == 0);
    expect(slot0?.direction, 'right');
    expect(slot0?.length, 5);
    expect(slot0?.startRow, 1);
    expect(slot0?.startCol, 0);

    final word0 = assignments?.firstWhere((a) => a.slotId == 0).word;
    expect(word0, 'ÅSIKT');

    final clueCell = grid?[0][0];
    expect(clueCell?.kind, 'clue');
    expect(clueCell?.clueTags.single.id, 0);
    expect(clueCell?.clueTags.single.arrow, '→');
  });
}
