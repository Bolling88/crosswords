/// Centralized user-facing strings. Primary language: Swedish ('sv').
class Strings {
  const Strings._();

  static const String appTitle = 'KORSORD';

  /// Label shown on image clue cells.
  static const String imageClueLabel = 'BILD';

  /// Tooltip/semantics label for the app-bar button that resets zoom & pan.
  static const String resetViewTooltip = 'Återställ vy';

  /// Tooltip/semantics label for the app-bar button that opens settings.
  static const String settingsTooltip = 'Inställningar';

  /// Title of the settings screen.
  static const String settingsTitle = 'Inställningar';

  /// Section header for the font picker on the settings screen.
  static const String fontSettingLabel = 'Typsnitt';

  /// Sample glyphs shown under each font option to preview its look.
  static const String fontPreviewSample = 'ABCÅÄÖ';

  /// Tooltip for the in-game actions menu.
  static const String gameMenuTooltip = 'Spelmeny';

  /// Game menu actions.
  static const String checkWordAction = 'Kontrollera ord';
  static const String checkPuzzleAction = 'Kontrollera allt';
  static const String revealLetterAction = 'Visa bokstav';
  static const String revealWordAction = 'Visa ord';
  static const String revealSolutionAction = 'Visa lösning';
  static const String clearWordAction = 'Rensa ord';
  static const String restartAction = 'Börja om';

  /// Reveal-solution confirmation dialog.
  static const String revealSolutionConfirmTitle = 'Visa lösningen?';
  static const String revealSolutionConfirmBody =
      'Hela korsordet fylls i med facit. Detta avslutar spelet.';

  /// Restart confirmation dialog.
  static const String restartConfirmTitle = 'Börja om?';
  static const String restartConfirmBody =
      'All ifylld text rensas. Detta går inte att ångra.';
  static const String cancelAction = 'Avbryt';

  /// Celebration dialog after solving the puzzle.
  static const String solvedTitle = 'Grattis!';
  static const String solvedBody = 'Du löste korsordet.';
  static const String closeAction = 'Stäng';

  /// SnackBar nudge when the grid is full but something is wrong.
  static const String puzzleFilledButIncorrect =
      'Korsordet är fullt – något stämmer inte än.';

  /// Section header for gameplay settings.
  static const String gameplaySettingLabel = 'Spel';

  /// Autocheck switch label and description.
  static const String autocheckLabel = 'Automatisk kontroll';
  static const String autocheckDescription =
      'Markera felaktiga bokstäver direkt';

  /// Generate screen.
  static const String generateTitle = 'Skapa korsord';
  static const String generateSizeLabel = 'Storlek';
  static const String generateMaxWordLenLabel = 'Längsta ord';
  static const String generateSeedWordsLabel = 'Egna ord';
  static const String generateSeedWordsHint = 'Skilj orden med komma';
  static const String generateLanguageLabel = 'Språk';
  static const String generateLanguageSwedish = 'Svenska';
  static const String generateMaxSecondsLabel = 'Max tid (s)';
  static const String generatePictureColsLabel = 'Bildrutor (bredd)';
  static const String generatePictureRowsLabel = 'Bildrutor (höjd)';
  static const String generateRandomSeedLabel = 'Slumpfrö';
  static const String generateRandomSeedHint = 'Lämna tomt för slumpmässigt';
  static const String generateAction = 'Skapa';
  static const String generatingLabel = 'Skapar…';
  static const String generateTestPuzzleAction = 'Testkorsord';
  static const String generatedPuzzleTitle = 'Korsord';
  static const String generationErrorMessage =
      'Kunde inte skapa korsordet. Försök igen.';

  /// Korsord direction words used in clue-cell semantics: a right-pointing
  /// arrow introduces an across word, a down-pointing arrow a down word.
  static const String directionAcross = 'vågrätt';
  static const String directionDown = 'lodrätt';

  /// Screen-reader label for an answer cell. Row/column are 1-based so the
  /// spoken position matches what a sighted player would count.
  static String answerCellSemantics({
    required int row,
    required int col,
    String? letter,
  }) {
    final position = 'rad ${row + 1}, kolumn ${col + 1}';
    if (letter == null || letter.isEmpty) {
      return 'Tom ruta, $position';
    }
    return 'Ruta, $position, bokstav $letter';
  }

  /// Screen-reader label for a clue cell, built from its already-formatted
  /// "clue, direction" fragments (one per arrow). Empty for a blank cell.
  static String clueCellSemantics(List<String> clues) {
    if (clues.isEmpty) return 'Tom ledtrådsruta';
    return 'Ledtråd: ${clues.join('. ')}';
  }

  /// Screen-reader label for an image clue.
  static const String imageClueSemantics = 'Bildledtråd';
}
