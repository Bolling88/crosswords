// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'crossword_auth_l10n.dart';

// ignore_for_file: type=lint

/// The translations for Swedish (`sv`).
class CrosswordAuthL10nSv extends CrosswordAuthL10n {
  CrosswordAuthL10nSv([String locale = 'sv']) : super(locale);

  @override
  String get signInTitle => 'Logga in';

  @override
  String get registerTitle => 'Skapa konto';

  @override
  String get toggleToRegister => 'Skapa ett konto';

  @override
  String get toggleToSignIn => 'Har du redan ett konto? Logga in';

  @override
  String get emailLabel => 'E-post';

  @override
  String get passwordLabel => 'Lösenord';

  @override
  String get signInAction => 'Logga in';

  @override
  String get registerAction => 'Skapa konto';

  @override
  String get forgotPassword => 'Glömt lösenord?';

  @override
  String get continueWithGoogle => 'Fortsätt med Google';

  @override
  String get continueWithApple => 'Fortsätt med Apple';

  @override
  String get socialDivider => 'eller';

  @override
  String get resetSent =>
      'Vi har skickat en återställningslänk till din e-post.';

  @override
  String get emailRequired => 'Ange din e-postadress.';

  @override
  String get passwordRequired => 'Ange ditt lösenord.';

  @override
  String get passwordTooShort => 'Lösenordet måste vara minst 6 tecken.';

  @override
  String get errorInvalidCredentials => 'Fel e-post eller lösenord.';

  @override
  String get errorEmailInUse => 'E-postadressen används redan.';

  @override
  String get errorInvalidEmail => 'Ogiltig e-postadress.';

  @override
  String get errorWeakPassword => 'Lösenordet är för svagt.';

  @override
  String get errorNetwork => 'Nätverksfel. Försök igen.';

  @override
  String get errorGeneric => 'Något gick fel. Försök igen.';

  @override
  String get accountTitle => 'Konto';

  @override
  String get accountTooltip => 'Konto';

  @override
  String get signedInAs => 'Inloggad som';

  @override
  String get signOutAction => 'Logga ut';

  @override
  String get signOutConfirmTitle => 'Logga ut?';

  @override
  String get signOutConfirmBody => 'Du loggas ut från ditt konto.';
}
