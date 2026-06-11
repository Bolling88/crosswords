/// The handwritten fonts the player can choose for the crossword.
///
/// [googleFamily] is the family name passed to `GoogleFonts.getFont`.
enum AppFont {
  patrickHand('Patrick Hand'),
  caveat('Caveat'),
  indieFlower('Indie Flower'),
  shadowsIntoLight('Shadows Into Light'),
  kalam('Kalam'),
  architectsDaughter('Architects Daughter'),
  comingSoon('Coming Soon'),
  gloriaHallelujah('Gloria Hallelujah'),
  justAnotherHand('Just Another Hand');

  const AppFont(this.googleFamily);

  /// Google Fonts family name, e.g. 'Patrick Hand'.
  final String googleFamily;

  /// Human-readable name shown in the picker.
  String get displayName => googleFamily;

  /// The font used when nothing has been chosen yet.
  static const AppFont defaultFont = AppFont.patrickHand;

  /// Resolves a stored [name] back to a font, falling back to [defaultFont]
  /// when the value is missing or unrecognised.
  static AppFont fromName(String? name) {
    return AppFont.values.firstWhere(
      (font) => font.name == name,
      orElse: () => defaultFont,
    );
  }
}
