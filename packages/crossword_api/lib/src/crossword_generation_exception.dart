/// Raised when crossword generation fails — a transport error, a non-200
/// response, or a body with `success: false`.
class CrosswordGenerationException implements Exception {
  final String message;

  const CrosswordGenerationException(this.message);

  @override
  String toString() => 'CrosswordGenerationException: $message';
}
