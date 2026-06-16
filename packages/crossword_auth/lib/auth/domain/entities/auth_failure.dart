/// Provider-agnostic reasons a sign-in / registration can fail. The UI maps
/// these to Swedish copy; Firebase error codes never reach widgets.
enum AuthFailureReason {
  invalidCredentials,
  emailAlreadyInUse,
  invalidEmail,
  weakPassword,
  network,
  cancelled,
  unknown,
}

/// A typed auth error thrown by the service layer.
class AuthFailure implements Exception {
  final AuthFailureReason reason;

  const AuthFailure(this.reason);
}

/// Translate a Firebase Auth error `code` into an [AuthFailure].
AuthFailure authFailureFromCode(String code) {
  switch (code) {
    case 'invalid-credential':
    case 'wrong-password':
    case 'user-not-found':
      return const AuthFailure(AuthFailureReason.invalidCredentials);
    case 'email-already-in-use':
      return const AuthFailure(AuthFailureReason.emailAlreadyInUse);
    case 'invalid-email':
      return const AuthFailure(AuthFailureReason.invalidEmail);
    case 'weak-password':
      return const AuthFailure(AuthFailureReason.weakPassword);
    case 'network-request-failed':
      return const AuthFailure(AuthFailureReason.network);
    // Web popup/redirect dismissals — a user who closes the Google/Apple
    // popup is cancelling, not hitting an error.
    case 'popup-closed-by-user':
    case 'cancelled-popup-request':
    case 'web-context-cancelled':
      return const AuthFailure(AuthFailureReason.cancelled);
    default:
      return const AuthFailure(AuthFailureReason.unknown);
  }
}
