import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'crossword_ui_l10n_en.dart';
import 'crossword_ui_l10n_sv.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of CrosswordUiL10n
/// returned by `CrosswordUiL10n.of(context)`.
///
/// Applications need to include `CrosswordUiL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/crossword_ui_l10n.dart';
///
/// return MaterialApp(
///   localizationsDelegates: CrosswordUiL10n.localizationsDelegates,
///   supportedLocales: CrosswordUiL10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the CrosswordUiL10n.supportedLocales
/// property.
abstract class CrosswordUiL10n {
  CrosswordUiL10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static CrosswordUiL10n of(BuildContext context) {
    return Localizations.of<CrosswordUiL10n>(context, CrosswordUiL10n)!;
  }

  static const LocalizationsDelegate<CrosswordUiL10n> delegate =
      _CrosswordUiL10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('sv'),
  ];

  /// Application title.
  ///
  /// In sv, this message translates to:
  /// **'KORSORD'**
  String get appTitle;

  /// Label shown on image clue cells.
  ///
  /// In sv, this message translates to:
  /// **'BILD'**
  String get imageClueLabel;

  /// Screen-reader label for an image clue.
  ///
  /// In sv, this message translates to:
  /// **'Bildledtråd'**
  String get imageClueSemantics;

  /// Tooltip/semantics for the app-bar button that resets zoom & pan.
  ///
  /// In sv, this message translates to:
  /// **'Återställ vy'**
  String get resetViewTooltip;

  /// Tooltip/semantics for the app-bar button that opens settings.
  ///
  /// In sv, this message translates to:
  /// **'Inställningar'**
  String get settingsTooltip;

  /// Title of the settings screen.
  ///
  /// In sv, this message translates to:
  /// **'Inställningar'**
  String get settingsTitle;

  /// Section header for the font picker.
  ///
  /// In sv, this message translates to:
  /// **'Typsnitt'**
  String get fontSettingLabel;

  /// Sample glyphs previewing each font option.
  ///
  /// In sv, this message translates to:
  /// **'ABCÅÄÖ'**
  String get fontPreviewSample;

  /// Tooltip for the in-game actions menu.
  ///
  /// In sv, this message translates to:
  /// **'Spelmeny'**
  String get gameMenuTooltip;

  /// Game menu: check the current word.
  ///
  /// In sv, this message translates to:
  /// **'Kontrollera ord'**
  String get checkWordAction;

  /// Game menu: check the whole puzzle.
  ///
  /// In sv, this message translates to:
  /// **'Kontrollera allt'**
  String get checkPuzzleAction;

  /// Game menu: reveal a letter.
  ///
  /// In sv, this message translates to:
  /// **'Visa bokstav'**
  String get revealLetterAction;

  /// Game menu: reveal a word.
  ///
  /// In sv, this message translates to:
  /// **'Visa ord'**
  String get revealWordAction;

  /// Game menu: reveal the whole solution.
  ///
  /// In sv, this message translates to:
  /// **'Visa lösning'**
  String get revealSolutionAction;

  /// Game menu: clear the current word.
  ///
  /// In sv, this message translates to:
  /// **'Rensa ord'**
  String get clearWordAction;

  /// Game menu: restart the puzzle.
  ///
  /// In sv, this message translates to:
  /// **'Börja om'**
  String get restartAction;

  /// Reveal-solution confirmation dialog title.
  ///
  /// In sv, this message translates to:
  /// **'Visa lösningen?'**
  String get revealSolutionConfirmTitle;

  /// Reveal-solution confirmation dialog body.
  ///
  /// In sv, this message translates to:
  /// **'Hela korsordet fylls i med facit. Detta avslutar spelet.'**
  String get revealSolutionConfirmBody;

  /// Restart confirmation dialog title.
  ///
  /// In sv, this message translates to:
  /// **'Börja om?'**
  String get restartConfirmTitle;

  /// Restart confirmation dialog body.
  ///
  /// In sv, this message translates to:
  /// **'All ifylld text rensas. Detta går inte att ångra.'**
  String get restartConfirmBody;

  /// Generic cancel action.
  ///
  /// In sv, this message translates to:
  /// **'Avbryt'**
  String get cancelAction;

  /// Celebration dialog title after solving.
  ///
  /// In sv, this message translates to:
  /// **'Grattis!'**
  String get solvedTitle;

  /// Celebration dialog body after solving.
  ///
  /// In sv, this message translates to:
  /// **'Du löste korsordet.'**
  String get solvedBody;

  /// Generic close action.
  ///
  /// In sv, this message translates to:
  /// **'Stäng'**
  String get closeAction;

  /// SnackBar nudge when the grid is full but wrong.
  ///
  /// In sv, this message translates to:
  /// **'Korsordet är fullt – något stämmer inte än.'**
  String get puzzleFilledButIncorrect;

  /// Section header for gameplay settings.
  ///
  /// In sv, this message translates to:
  /// **'Spel'**
  String get gameplaySettingLabel;

  /// Autocheck switch label.
  ///
  /// In sv, this message translates to:
  /// **'Automatisk kontroll'**
  String get autocheckLabel;

  /// Autocheck switch description.
  ///
  /// In sv, this message translates to:
  /// **'Markera felaktiga bokstäver direkt'**
  String get autocheckDescription;

  /// Generate screen title.
  ///
  /// In sv, this message translates to:
  /// **'Skapa korsord'**
  String get generateTitle;

  /// Generate screen: size field label.
  ///
  /// In sv, this message translates to:
  /// **'Storlek'**
  String get generateSizeLabel;

  /// Generate screen: longest-word field label.
  ///
  /// In sv, this message translates to:
  /// **'Längsta ord'**
  String get generateMaxWordLenLabel;

  /// Generate screen: own words field label.
  ///
  /// In sv, this message translates to:
  /// **'Egna ord'**
  String get generateSeedWordsLabel;

  /// Generate screen: own words field hint.
  ///
  /// In sv, this message translates to:
  /// **'Skilj orden med komma'**
  String get generateSeedWordsHint;

  /// Generate screen: language field label.
  ///
  /// In sv, this message translates to:
  /// **'Språk'**
  String get generateLanguageLabel;

  /// Generate screen: Swedish language option.
  ///
  /// In sv, this message translates to:
  /// **'Svenska'**
  String get generateLanguageSwedish;

  /// Generate screen: max time field label.
  ///
  /// In sv, this message translates to:
  /// **'Max tid (s)'**
  String get generateMaxSecondsLabel;

  /// Generate screen: image cells width field label.
  ///
  /// In sv, this message translates to:
  /// **'Bildrutor (bredd)'**
  String get generatePictureColsLabel;

  /// Generate screen: image cells height field label.
  ///
  /// In sv, this message translates to:
  /// **'Bildrutor (höjd)'**
  String get generatePictureRowsLabel;

  /// Generate screen: random seed field label.
  ///
  /// In sv, this message translates to:
  /// **'Slumpfrö'**
  String get generateRandomSeedLabel;

  /// Generate screen: random seed field hint.
  ///
  /// In sv, this message translates to:
  /// **'Lämna tomt för slumpmässigt'**
  String get generateRandomSeedHint;

  /// Generate screen: create action.
  ///
  /// In sv, this message translates to:
  /// **'Skapa'**
  String get generateAction;

  /// Generate screen: in-progress label.
  ///
  /// In sv, this message translates to:
  /// **'Skapar…'**
  String get generatingLabel;

  /// Generate screen: open the bundled test puzzle.
  ///
  /// In sv, this message translates to:
  /// **'Testkorsord'**
  String get generateTestPuzzleAction;

  /// Default title for a generated puzzle.
  ///
  /// In sv, this message translates to:
  /// **'Korsord'**
  String get generatedPuzzleTitle;

  /// Generate screen: generic generation failure message.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte skapa korsordet. Försök igen.'**
  String get generationErrorMessage;

  /// Direction word for an across clue (right-pointing arrow).
  ///
  /// In sv, this message translates to:
  /// **'vågrätt'**
  String get directionAcross;

  /// Direction word for a down clue (down-pointing arrow).
  ///
  /// In sv, this message translates to:
  /// **'lodrätt'**
  String get directionDown;

  /// Screen-reader label for an empty answer cell (1-based position).
  ///
  /// In sv, this message translates to:
  /// **'Tom ruta, rad {row}, kolumn {col}'**
  String answerCellEmpty(int row, int col);

  /// Screen-reader label for a filled answer cell (1-based position).
  ///
  /// In sv, this message translates to:
  /// **'Ruta, rad {row}, kolumn {col}, bokstav {letter}'**
  String answerCellFilled(int row, int col, String letter);

  /// Screen-reader label for a blank clue cell.
  ///
  /// In sv, this message translates to:
  /// **'Tom ledtrådsruta'**
  String get clueCellEmpty;

  /// Screen-reader label for a clue cell, built from joined fragments.
  ///
  /// In sv, this message translates to:
  /// **'Ledtråd: {clues}'**
  String clueCellLabel(String clues);
}

class _CrosswordUiL10nDelegate extends LocalizationsDelegate<CrosswordUiL10n> {
  const _CrosswordUiL10nDelegate();

  @override
  Future<CrosswordUiL10n> load(Locale locale) {
    return SynchronousFuture<CrosswordUiL10n>(lookupCrosswordUiL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'sv'].contains(locale.languageCode);

  @override
  bool shouldReload(_CrosswordUiL10nDelegate old) => false;
}

CrosswordUiL10n lookupCrosswordUiL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return CrosswordUiL10nEn();
    case 'sv':
      return CrosswordUiL10nSv();
  }

  throw FlutterError(
    'CrosswordUiL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
