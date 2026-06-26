// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'crossword_ui_l10n.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class CrosswordUiL10nEn extends CrosswordUiL10n {
  CrosswordUiL10nEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'CROSSWORD';

  @override
  String get imageClueLabel => 'IMAGE';

  @override
  String get imageClueSemantics => 'Image clue';

  @override
  String get resetViewTooltip => 'Reset view';

  @override
  String get settingsTooltip => 'Settings';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get fontSettingLabel => 'Font';

  @override
  String get fontPreviewSample => 'ABCÅÄÖ';

  @override
  String get gameMenuTooltip => 'Game menu';

  @override
  String get checkWordAction => 'Check word';

  @override
  String get checkPuzzleAction => 'Check all';

  @override
  String get revealLetterAction => 'Reveal letter';

  @override
  String get revealWordAction => 'Reveal word';

  @override
  String get revealSolutionAction => 'Reveal solution';

  @override
  String get clearWordAction => 'Clear word';

  @override
  String get restartAction => 'Restart';

  @override
  String get revealSolutionConfirmTitle => 'Reveal the solution?';

  @override
  String get revealSolutionConfirmBody =>
      'The whole crossword will be filled in with the answers. This ends the game.';

  @override
  String get restartConfirmTitle => 'Restart?';

  @override
  String get restartConfirmBody =>
      'All entered text will be cleared. This cannot be undone.';

  @override
  String get cancelAction => 'Cancel';

  @override
  String get solvedTitle => 'Congratulations!';

  @override
  String get solvedBody => 'You solved the crossword.';

  @override
  String get closeAction => 'Close';

  @override
  String get puzzleFilledButIncorrect =>
      'The crossword is full – something isn\'t right yet.';

  @override
  String get gameplaySettingLabel => 'Gameplay';

  @override
  String get autocheckLabel => 'Automatic check';

  @override
  String get autocheckDescription => 'Mark incorrect letters immediately';

  @override
  String get generateTitle => 'Create crossword';

  @override
  String get generateSizeLabel => 'Size';

  @override
  String get generateMaxWordLenLabel => 'Longest word';

  @override
  String get generateSeedWordsLabel => 'Own words';

  @override
  String get generateSeedWordsHint => 'Separate words with commas';

  @override
  String get generateLanguageLabel => 'Language';

  @override
  String get generateLanguageSwedish => 'Swedish';

  @override
  String get generateMaxSecondsLabel => 'Max time (s)';

  @override
  String get generatePictureColsLabel => 'Image cells (width)';

  @override
  String get generatePictureRowsLabel => 'Image cells (height)';

  @override
  String get generateRandomSeedLabel => 'Random seed';

  @override
  String get generateRandomSeedHint => 'Leave empty for random';

  @override
  String get generateAction => 'Create';

  @override
  String get generatingLabel => 'Creating…';

  @override
  String get generateTestPuzzleAction => 'Test crossword';

  @override
  String get generatedPuzzleTitle => 'Crossword';

  @override
  String get generationErrorMessage =>
      'Couldn\'t create the crossword. Try again.';

  @override
  String get directionAcross => 'across';

  @override
  String get directionDown => 'down';

  @override
  String answerCellEmpty(int row, int col) {
    return 'Empty cell, row $row, column $col';
  }

  @override
  String answerCellFilled(int row, int col, String letter) {
    return 'Cell, row $row, column $col, letter $letter';
  }

  @override
  String get clueCellEmpty => 'Empty clue cell';

  @override
  String clueCellLabel(String clues) {
    return 'Clue: $clues';
  }
}
