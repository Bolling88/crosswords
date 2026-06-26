import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'crossword_auth_l10n_en.dart';
import 'crossword_auth_l10n_sv.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of CrosswordAuthL10n
/// returned by `CrosswordAuthL10n.of(context)`.
///
/// Applications need to include `CrosswordAuthL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/crossword_auth_l10n.dart';
///
/// return MaterialApp(
///   localizationsDelegates: CrosswordAuthL10n.localizationsDelegates,
///   supportedLocales: CrosswordAuthL10n.supportedLocales,
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
/// be consistent with the languages listed in the CrosswordAuthL10n.supportedLocales
/// property.
abstract class CrosswordAuthL10n {
  CrosswordAuthL10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static CrosswordAuthL10n of(BuildContext context) {
    return Localizations.of<CrosswordAuthL10n>(context, CrosswordAuthL10n)!;
  }

  static const LocalizationsDelegate<CrosswordAuthL10n> delegate =
      _CrosswordAuthL10nDelegate();

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

  /// Sign-in screen title.
  ///
  /// In sv, this message translates to:
  /// **'Logga in'**
  String get signInTitle;

  /// Register screen title.
  ///
  /// In sv, this message translates to:
  /// **'Skapa konto'**
  String get registerTitle;

  /// Toggle from sign-in to register.
  ///
  /// In sv, this message translates to:
  /// **'Skapa ett konto'**
  String get toggleToRegister;

  /// Toggle from register to sign-in.
  ///
  /// In sv, this message translates to:
  /// **'Har du redan ett konto? Logga in'**
  String get toggleToSignIn;

  /// Email field label.
  ///
  /// In sv, this message translates to:
  /// **'E-post'**
  String get emailLabel;

  /// Password field label.
  ///
  /// In sv, this message translates to:
  /// **'Lösenord'**
  String get passwordLabel;

  /// Primary sign-in action.
  ///
  /// In sv, this message translates to:
  /// **'Logga in'**
  String get signInAction;

  /// Primary register action.
  ///
  /// In sv, this message translates to:
  /// **'Skapa konto'**
  String get registerAction;

  /// Forgot-password link.
  ///
  /// In sv, this message translates to:
  /// **'Glömt lösenord?'**
  String get forgotPassword;

  /// Continue with Google button.
  ///
  /// In sv, this message translates to:
  /// **'Fortsätt med Google'**
  String get continueWithGoogle;

  /// Continue with Apple button.
  ///
  /// In sv, this message translates to:
  /// **'Fortsätt med Apple'**
  String get continueWithApple;

  /// Divider between email and social sign-in.
  ///
  /// In sv, this message translates to:
  /// **'eller'**
  String get socialDivider;

  /// Password-reset email sent confirmation.
  ///
  /// In sv, this message translates to:
  /// **'Vi har skickat en återställningslänk till din e-post.'**
  String get resetSent;

  /// Validation: email required.
  ///
  /// In sv, this message translates to:
  /// **'Ange din e-postadress.'**
  String get emailRequired;

  /// Validation: password required.
  ///
  /// In sv, this message translates to:
  /// **'Ange ditt lösenord.'**
  String get passwordRequired;

  /// Validation: password too short.
  ///
  /// In sv, this message translates to:
  /// **'Lösenordet måste vara minst 6 tecken.'**
  String get passwordTooShort;

  /// Error: invalid credentials.
  ///
  /// In sv, this message translates to:
  /// **'Fel e-post eller lösenord.'**
  String get errorInvalidCredentials;

  /// Error: email already in use.
  ///
  /// In sv, this message translates to:
  /// **'E-postadressen används redan.'**
  String get errorEmailInUse;

  /// Error: invalid email.
  ///
  /// In sv, this message translates to:
  /// **'Ogiltig e-postadress.'**
  String get errorInvalidEmail;

  /// Error: weak password.
  ///
  /// In sv, this message translates to:
  /// **'Lösenordet är för svagt.'**
  String get errorWeakPassword;

  /// Error: network failure.
  ///
  /// In sv, this message translates to:
  /// **'Nätverksfel. Försök igen.'**
  String get errorNetwork;

  /// Error: generic failure.
  ///
  /// In sv, this message translates to:
  /// **'Något gick fel. Försök igen.'**
  String get errorGeneric;

  /// Account screen title.
  ///
  /// In sv, this message translates to:
  /// **'Konto'**
  String get accountTitle;

  /// Account button tooltip.
  ///
  /// In sv, this message translates to:
  /// **'Konto'**
  String get accountTooltip;

  /// Account screen: signed-in-as label.
  ///
  /// In sv, this message translates to:
  /// **'Inloggad som'**
  String get signedInAs;

  /// Sign-out action.
  ///
  /// In sv, this message translates to:
  /// **'Logga ut'**
  String get signOutAction;

  /// Sign-out confirmation dialog title.
  ///
  /// In sv, this message translates to:
  /// **'Logga ut?'**
  String get signOutConfirmTitle;

  /// Sign-out confirmation dialog body.
  ///
  /// In sv, this message translates to:
  /// **'Du loggas ut från ditt konto.'**
  String get signOutConfirmBody;
}

class _CrosswordAuthL10nDelegate
    extends LocalizationsDelegate<CrosswordAuthL10n> {
  const _CrosswordAuthL10nDelegate();

  @override
  Future<CrosswordAuthL10n> load(Locale locale) {
    return SynchronousFuture<CrosswordAuthL10n>(
      lookupCrosswordAuthL10n(locale),
    );
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'sv'].contains(locale.languageCode);

  @override
  bool shouldReload(_CrosswordAuthL10nDelegate old) => false;
}

CrosswordAuthL10n lookupCrosswordAuthL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return CrosswordAuthL10nEn();
    case 'sv':
      return CrosswordAuthL10nSv();
  }

  throw FlutterError(
    'CrosswordAuthL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
