// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'crossword_ui_l10n.dart';

// ignore_for_file: type=lint

/// The translations for Swedish (`sv`).
class CrosswordUiL10nSv extends CrosswordUiL10n {
  CrosswordUiL10nSv([String locale = 'sv']) : super(locale);

  @override
  String get appTitle => 'KORSORD';

  @override
  String get imageClueLabel => 'BILD';

  @override
  String get imageClueSemantics => 'Bildledtråd';

  @override
  String get resetViewTooltip => 'Återställ vy';

  @override
  String get settingsTooltip => 'Inställningar';

  @override
  String get settingsTitle => 'Inställningar';

  @override
  String get fontSettingLabel => 'Typsnitt';

  @override
  String get fontPreviewSample => 'ABCÅÄÖ';

  @override
  String get gameMenuTooltip => 'Spelmeny';

  @override
  String get checkWordAction => 'Kontrollera ord';

  @override
  String get checkPuzzleAction => 'Kontrollera allt';

  @override
  String get revealLetterAction => 'Visa bokstav';

  @override
  String get revealWordAction => 'Visa ord';

  @override
  String get revealSolutionAction => 'Visa lösning';

  @override
  String get clearWordAction => 'Rensa ord';

  @override
  String get restartAction => 'Börja om';

  @override
  String get revealSolutionConfirmTitle => 'Visa lösningen?';

  @override
  String get revealSolutionConfirmBody =>
      'Hela korsordet fylls i med facit. Detta avslutar spelet.';

  @override
  String get restartConfirmTitle => 'Börja om?';

  @override
  String get restartConfirmBody =>
      'All ifylld text rensas. Detta går inte att ångra.';

  @override
  String get cancelAction => 'Avbryt';

  @override
  String get solvedTitle => 'Grattis!';

  @override
  String get solvedBody => 'Du löste korsordet.';

  @override
  String get closeAction => 'Stäng';

  @override
  String get puzzleFilledButIncorrect =>
      'Korsordet är fullt – något stämmer inte än.';

  @override
  String get gameplaySettingLabel => 'Spel';

  @override
  String get autocheckLabel => 'Automatisk kontroll';

  @override
  String get autocheckDescription => 'Markera felaktiga bokstäver direkt';

  @override
  String get generateTitle => 'Skapa korsord';

  @override
  String get generateSizeLabel => 'Storlek';

  @override
  String get generateMaxWordLenLabel => 'Längsta ord';

  @override
  String get generateSeedWordsLabel => 'Egna ord';

  @override
  String get generateSeedWordsHint => 'Skilj orden med komma';

  @override
  String get generateLanguageLabel => 'Språk';

  @override
  String get generateLanguageSwedish => 'Svenska';

  @override
  String get generateMaxSecondsLabel => 'Max tid (s)';

  @override
  String get generatePictureColsLabel => 'Bildrutor (bredd)';

  @override
  String get generatePictureRowsLabel => 'Bildrutor (höjd)';

  @override
  String get generateRandomSeedLabel => 'Slumpfrö';

  @override
  String get generateRandomSeedHint => 'Lämna tomt för slumpmässigt';

  @override
  String get generateAction => 'Skapa';

  @override
  String get generatingLabel => 'Skapar…';

  @override
  String get generateTestPuzzleAction => 'Testkorsord';

  @override
  String get generatedPuzzleTitle => 'Korsord';

  @override
  String get generationErrorMessage =>
      'Kunde inte skapa korsordet. Försök igen.';

  @override
  String get directionAcross => 'vågrätt';

  @override
  String get directionDown => 'lodrätt';

  @override
  String answerCellEmpty(int row, int col) {
    return 'Tom ruta, rad $row, kolumn $col';
  }

  @override
  String answerCellFilled(int row, int col, String letter) {
    return 'Ruta, rad $row, kolumn $col, bokstav $letter';
  }

  @override
  String get clueCellEmpty => 'Tom ledtrådsruta';

  @override
  String clueCellLabel(String clues) {
    return 'Ledtråd: $clues';
  }
}
