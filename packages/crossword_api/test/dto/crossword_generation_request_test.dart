import 'package:crossword_api/crossword_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CrosswordGenerationRequest.toJson', () {
    test('includes all fields with defaults and omits null random_seed', () {
      const request = CrosswordGenerationRequest(
        width: 15,
        height: 15,
        maxWordLen: 6,
      );

      final json = request.toJson();

      expect(json['width'], 15);
      expect(json['height'], 15);
      expect(json['language_code'], 'sv');
      expect(json['seed_words'], <String>[]);
      expect(json['max_seconds'], 30);
      expect(json['max_word_len'], 6);
      expect(json['picture_cols'], 0);
      expect(json['picture_rows'], 0);
      expect(json.containsKey('random_seed'), isFalse);
    });

    test('includes random_seed and overridden fields when set', () {
      const request = CrosswordGenerationRequest(
        width: 17,
        height: 13,
        maxWordLen: 8,
        seedWords: ['KATT', 'HUND'],
        languageCode: 'sv',
        randomSeed: 42,
        maxSeconds: 60,
        pictureCols: 8,
        pictureRows: 6,
      );

      final json = request.toJson();

      expect(json['random_seed'], 42);
      expect(json['max_seconds'], 60);
      expect(json['picture_cols'], 8);
      expect(json['picture_rows'], 6);
      expect(json['seed_words'], ['KATT', 'HUND']);
    });
  });
}
