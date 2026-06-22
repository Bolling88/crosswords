/// Request body for `POST /crossword-puzzles/generate`. Exposes the three
/// user-controlled params; language is fixed to Swedish and pictures are off
/// (image clues are not supported yet).
class CrosswordGenerationRequest {
  final int width;
  final int height;
  final int maxWordLen;
  final List<String> seedWords;

  const CrosswordGenerationRequest({
    required this.width,
    required this.height,
    required this.maxWordLen,
    this.seedWords = const [],
  });

  Map<String, dynamic> toJson() => {
        'width': width,
        'height': height,
        'language_code': 'sv',
        'seed_words': seedWords,
        'max_seconds': 30,
        'max_word_len': maxWordLen,
        'picture_cols': 0,
        'picture_rows': 0,
      };
}
