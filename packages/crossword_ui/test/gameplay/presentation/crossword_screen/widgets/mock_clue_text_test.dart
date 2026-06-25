import 'package:flutter_test/flutter_test.dart';

import 'package:crossword_ui/gameplay/presentation/crossword_screen/widgets/mock_clue_text.dart';

void main() {
  group('mockClueText', () {
    test('is deterministic for a given word id', () {
      expect(mockClueText('7'), mockClueText('7'));
      expect(mockClueText('21'), mockClueText('21'));
    });

    test('always returns non-empty prose', () {
      for (final id in ['0', '1', '6', '8', '18', '21', '23', '999']) {
        expect(mockClueText(id), isNotEmpty);
      }
    });

    test('varies across different ids', () {
      final clues = {for (final id in ['0', '1', '2', '3', '4']) mockClueText(id)};
      expect(clues.length, greaterThan(1));
    });
  });
}
