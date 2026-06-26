/// Request body for `POST /crossword-puzzles/generate`. Carries every field of
/// the generation schema. `random_seed` is omitted when null so the backend
/// picks its own seed; image clues use [pictureCols]/[pictureRows] (0 = off).
class CrosswordGenerationRequest {
  final int width;
  final int height;
  final int maxWordLen;
  final List<String> seedWords;
  final String languageCode;
  final int? randomSeed;
  final int maxSeconds;
  final int pictureCols;
  final int pictureRows;

  const CrosswordGenerationRequest({
    required this.width,
    required this.height,
    required this.maxWordLen,
    this.seedWords = const [],
    this.languageCode = 'sv',
    this.randomSeed,
    this.maxSeconds = 30,
    this.pictureCols = 0,
    this.pictureRows = 0,
  });

  Map<String, dynamic> toJson() => {
        'width': width,
        'height': height,
        'language_code': languageCode,
        'seed_words': seedWords,
        if (randomSeed != null) 'random_seed': randomSeed,
        'max_seconds': maxSeconds,
        'max_word_len': maxWordLen,
        'picture_cols': pictureCols,
        'picture_rows': pictureRows,
      };
}
