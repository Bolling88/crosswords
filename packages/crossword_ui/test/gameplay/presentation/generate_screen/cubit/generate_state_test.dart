import 'package:crossword_ui/gameplay/presentation/generate_screen/cubit/generate_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GenerateState', () {
    test('has expected defaults for new fields', () {
      const state = GenerateState();
      expect(state.languageCode, 'sv');
      expect(state.maxSeconds, 30);
      expect(state.pictureCols, 0);
      expect(state.pictureRows, 0);
    });

    test('copyWith updates new fields and preserves the rest', () {
      const state = GenerateState();
      final updated = state.copyWith(
        maxSeconds: 60,
        pictureCols: 8,
        pictureRows: 6,
      );
      expect(updated.maxSeconds, 60);
      expect(updated.pictureCols, 8);
      expect(updated.pictureRows, 6);
      expect(updated.width, state.width);
      expect(updated.languageCode, 'sv');
    });

    test('new fields participate in equality', () {
      const a = GenerateState();
      final b = a.copyWith(maxSeconds: 60);
      expect(a == b, isFalse);
      expect(a == a.copyWith(), isTrue);
    });
  });
}
