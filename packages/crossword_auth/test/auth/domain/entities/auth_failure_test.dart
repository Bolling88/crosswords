import 'package:crossword_auth/auth/domain/entities/auth_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps known Firebase codes to typed reasons', () {
    expect(authFailureFromCode('invalid-credential').reason,
        AuthFailureReason.invalidCredentials);
    expect(authFailureFromCode('wrong-password').reason,
        AuthFailureReason.invalidCredentials);
    expect(authFailureFromCode('email-already-in-use').reason,
        AuthFailureReason.emailAlreadyInUse);
    expect(authFailureFromCode('invalid-email').reason,
        AuthFailureReason.invalidEmail);
    expect(authFailureFromCode('weak-password').reason,
        AuthFailureReason.weakPassword);
    expect(authFailureFromCode('network-request-failed').reason,
        AuthFailureReason.network);
  });

  test('maps unknown codes to the generic reason', () {
    expect(authFailureFromCode('something-odd').reason, AuthFailureReason.unknown);
  });

  test('cancelled is its own reason for aborted social sign-in', () {
    expect(const AuthFailure(AuthFailureReason.cancelled).reason,
        AuthFailureReason.cancelled);
  });
}
