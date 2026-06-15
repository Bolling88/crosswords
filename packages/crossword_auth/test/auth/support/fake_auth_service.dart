import 'package:flutter/foundation.dart';

import 'package:crossword_auth/auth/domain/entities/auth_failure.dart';
import 'package:crossword_auth/auth/domain/entities/auth_user.dart';
import 'package:crossword_auth/auth/domain/services/auth_service.dart';

/// Hand-written test double (the repo uses no mocking libraries). Drive
/// [user] to simulate auth-state changes; methods record calls and can be
/// set to throw.
class FakeAuthService implements AuthService {
  final ValueNotifier<AuthUser?> user;
  AuthFailure? throwOnNextCall;

  final List<String> calls = <String>[];
  String? lastEmail;
  String? lastPassword;

  FakeAuthService({AuthUser? initial}) : user = ValueNotifier<AuthUser?>(initial);

  void emit(AuthUser? value) => user.value = value;

  void _maybeThrow(String call) {
    calls.add(call);
    final failure = throwOnNextCall;
    if (failure != null) {
      throwOnNextCall = null;
      throw failure;
    }
  }

  @override
  ValueListenable<AuthUser?> get currentUser => user;

  @override
  Future<void> signInWithEmail(String email, String password) async {
    lastEmail = email;
    lastPassword = password;
    _maybeThrow('signInWithEmail');
  }

  @override
  Future<void> registerWithEmail(String email, String password) async {
    lastEmail = email;
    lastPassword = password;
    _maybeThrow('registerWithEmail');
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    lastEmail = email;
    _maybeThrow('sendPasswordReset');
  }

  @override
  Future<void> signInWithGoogle() async => _maybeThrow('signInWithGoogle');

  @override
  Future<void> signInWithApple() async => _maybeThrow('signInWithApple');

  @override
  Future<void> signOut() async => _maybeThrow('signOut');

  @override
  Future<String?> getIdToken() async {
    _maybeThrow('getIdToken');
    return user.value == null ? null : 'fake-token';
  }

  @override
  void dispose() => user.dispose();
}
