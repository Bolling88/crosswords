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
  static const String clearWordAction = 'Rensa ord';
  static const String restartAction = 'Börja om';

  /// Restart confirmation dialog.
  static const String restartConfirmTitle = 'Börja om?';
  static const String restartConfirmBody =
      'All ifylld text rensas. Detta går inte att ångra.';
  static const String cancelAction = 'Avbryt';
}
