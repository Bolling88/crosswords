// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'crossword_auth_l10n.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class CrosswordAuthL10nEn extends CrosswordAuthL10n {
  CrosswordAuthL10nEn([String locale = 'en']) : super(locale);

  @override
  String get signInTitle => 'Sign in';

  @override
  String get registerTitle => 'Create account';

  @override
  String get toggleToRegister => 'Create an account';

  @override
  String get toggleToSignIn => 'Already have an account? Sign in';

  @override
  String get emailLabel => 'Email';

  @override
  String get passwordLabel => 'Password';

  @override
  String get signInAction => 'Sign in';

  @override
  String get registerAction => 'Create account';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get continueWithApple => 'Continue with Apple';

  @override
  String get socialDivider => 'or';

  @override
  String get resetSent => 'We\'ve sent a reset link to your email.';

  @override
  String get emailRequired => 'Enter your email address.';

  @override
  String get passwordRequired => 'Enter your password.';

  @override
  String get passwordTooShort => 'The password must be at least 6 characters.';

  @override
  String get errorInvalidCredentials => 'Wrong email or password.';

  @override
  String get errorEmailInUse => 'The email address is already in use.';

  @override
  String get errorInvalidEmail => 'Invalid email address.';

  @override
  String get errorWeakPassword => 'The password is too weak.';

  @override
  String get errorNetwork => 'Network error. Try again.';

  @override
  String get errorGeneric => 'Something went wrong. Try again.';

  @override
  String get accountTitle => 'Account';

  @override
  String get accountTooltip => 'Account';

  @override
  String get signedInAs => 'Signed in as';

  @override
  String get signOutAction => 'Sign out';

  @override
  String get signOutConfirmTitle => 'Sign out?';

  @override
  String get signOutConfirmBody => 'You\'ll be signed out of your account.';
}
