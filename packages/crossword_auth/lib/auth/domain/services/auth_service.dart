import 'package:flutter/foundation.dart';

import '../entities/auth_user.dart';

/// Cross-feature shared auth state. Only cubits touch this service.
///
/// Implementations expose the current user via [currentUser] (driven by the
/// backing provider's auth-state stream) and throw [AuthFailure] on errors.
abstract class AuthService {
  /// The signed-in user, or null when signed out. Cubits listen to this.
  ValueListenable<AuthUser?> get currentUser;

  /// True until the backing provider reports its first auth state. The gate
  /// shows a loading state while this is true, avoiding a login-screen flash
  /// on cold start for an already-signed-in user.
  ValueListenable<bool> get isInitializing;

  Future<void> signInWithEmail(String email, String password);

  Future<void> registerWithEmail(String email, String password);

  Future<void> sendPasswordReset(String email);

  Future<void> signInWithGoogle();

  Future<void> signInWithApple();

  Future<void> signOut();

  /// The current user's Firebase ID token for the verifying backend, or null
  /// when signed out. The backend seam — unused until the backend exists.
  Future<String?> getIdToken();

  /// Release resources (the backing notifier / stream subscription).
  void dispose();
}
