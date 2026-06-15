/// Centralized user-facing strings for the auth feature. Language: Swedish.
class AuthStrings {
  const AuthStrings._();

  // Screen titles / mode toggle
  static const String signInTitle = 'Logga in';
  static const String registerTitle = 'Skapa konto';
  static const String toggleToRegister = 'Skapa ett konto';
  static const String toggleToSignIn = 'Har du redan ett konto? Logga in';

  // Fields
  static const String emailLabel = 'E-post';
  static const String passwordLabel = 'Lösenord';

  // Primary actions
  static const String signInAction = 'Logga in';
  static const String registerAction = 'Skapa konto';
  static const String forgotPassword = 'Glömt lösenord?';

  // Social
  static const String continueWithGoogle = 'Fortsätt med Google';
  static const String continueWithApple = 'Fortsätt med Apple';
  static const String socialDivider = 'eller';

  // Confirmations
  static const String resetSent =
      'Vi har skickat en återställningslänk till din e-post.';

  // Validation
  static const String emailRequired = 'Ange din e-postadress.';
  static const String passwordRequired = 'Ange ditt lösenord.';
  static const String passwordTooShort = 'Lösenordet måste vara minst 6 tecken.';

  // Errors (mapped from AuthFailureReason)
  static const String errorInvalidCredentials = 'Fel e-post eller lösenord.';
  static const String errorEmailInUse = 'E-postadressen används redan.';
  static const String errorInvalidEmail = 'Ogiltig e-postadress.';
  static const String errorWeakPassword = 'Lösenordet är för svagt.';
  static const String errorNetwork = 'Nätverksfel. Försök igen.';
  static const String errorGeneric = 'Något gick fel. Försök igen.';
}
