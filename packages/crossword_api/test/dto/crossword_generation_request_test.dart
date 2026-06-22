import 'package:crossword_api/crossword_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('toJson sends user params plus fixed sv/pictures-off defaults', () {
    final json = const CrosswordGenerationRequest(
      width: 15,
      height: 15,
      maxWordLen: 6,
      seedWords: ['KATT', 'HUND'],
    ).toJson();

    expect(json['width'], 15);
    expect(json['height'], 15);
    expect(json['max_word_len'], 6);
    expect(json['seed_words'], ['KATT', 'HUND']);
    expect(json['language_code'], 'sv');
    expect(json['picture_cols'], 0);
    expect(json['picture_rows'], 0);
    expect(json['max_seconds'], 30);
  });
}
