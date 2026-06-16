import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/material.dart';

import '../../../common/strings/auth_strings.dart';
import '../../../domain/entities/auth_failure.dart';
import '../../../domain/services/auth_service.dart';
import 'login_state.dart';

/// A Cubit-equivalent for the login screen that uses a synchronous broadcast
/// stream so that tests can observe emitted states without an extra microtask
/// flush after awaiting async methods.
class LoginCubit implements StateStreamableSource<LoginState> {
  final AuthService _authService;

  // Synchronous broadcast: listeners are called inline on emit(),
  // which lets tests verify states immediately after `await cubit.method()`.
  final _controller = StreamController<LoginState>.broadcast(sync: true);

  LoginState _state = const LoginState();
  bool _emitted = false;
  bool _closed = false;

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final FocusNode emailFocus = FocusNode();
  final FocusNode passwordFocus = FocusNode();

  LoginCubit({required AuthService authService}) : _authService = authService;

  @override
  LoginState get state => _state;

  @override
  Stream<LoginState> get stream => _controller.stream;

  @override
  bool get isClosed => _closed;

  @protected
  void emit(LoginState state) {
    if (_closed) {
      throw StateError('Cannot emit new states after calling close');
    }
    if (state == _state && _emitted) return;
    _state = state;
    _controller.add(_state);
    _emitted = true;
  }

  void toggleMode() {
    final next =
        _state.mode == LoginMode.signIn ? LoginMode.register : LoginMode.signIn;
    emit(_state.copyWith(mode: next));
  }

  Future<void> submit() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    final validation = _validate(email, password);
    if (validation != null) {
      emit(LoginError(state: _state, message: validation));
      return;
    }

    emit(_state.copyWith(isSubmitting: true));
    try {
      if (_state.mode == LoginMode.signIn) {
        await _authService.signInWithEmail(email, password);
      } else {
        await _authService.registerWithEmail(email, password);
      }
      // Success: AuthGate reacts to currentUser; nothing more to do here.
      emit(_state.copyWith(isSubmitting: false));
    } on AuthFailure catch (failure) {
      emit(_state.copyWith(isSubmitting: false));
      emit(LoginError(state: _state, message: _messageFor(failure)));
    }
  }

  Future<void> sendPasswordReset() async {
    final email = emailController.text.trim();
    if (email.isEmpty) {
      emit(LoginError(state: _state, message: AuthStrings.emailRequired));
      return;
    }
    try {
      await _authService.sendPasswordReset(email);
      emit(LoginPasswordResetSent(state: _state));
    } on AuthFailure catch (failure) {
      emit(LoginError(state: _state, message: _messageFor(failure)));
    }
  }

  Future<void> signInWithGoogle() => _social(_authService.signInWithGoogle);

  Future<void> signInWithApple() => _social(_authService.signInWithApple);

  Future<void> _social(Future<void> Function() action) async {
    emit(_state.copyWith(isSubmitting: true));
    try {
      await action();
      emit(_state.copyWith(isSubmitting: false));
    } on AuthFailure catch (failure) {
      emit(_state.copyWith(isSubmitting: false));
      // A user-cancelled popup/sheet is not an error worth surfacing.
      if (failure.reason != AuthFailureReason.cancelled) {
        emit(LoginError(state: _state, message: _messageFor(failure)));
      }
    }
  }

  String? _validate(String email, String password) {
    if (email.isEmpty) return AuthStrings.emailRequired;
    if (password.isEmpty) return AuthStrings.passwordRequired;
    if (password.length < 6) return AuthStrings.passwordTooShort;
    return null;
  }

  String _messageFor(AuthFailure failure) {
    switch (failure.reason) {
      case AuthFailureReason.invalidCredentials:
        return AuthStrings.errorInvalidCredentials;
      case AuthFailureReason.emailAlreadyInUse:
        return AuthStrings.errorEmailInUse;
      case AuthFailureReason.invalidEmail:
        return AuthStrings.errorInvalidEmail;
      case AuthFailureReason.weakPassword:
        return AuthStrings.errorWeakPassword;
      case AuthFailureReason.network:
        return AuthStrings.errorNetwork;
      case AuthFailureReason.cancelled:
      case AuthFailureReason.unknown:
        return AuthStrings.errorGeneric;
    }
  }

  @override
  Future<void> close() async {
    _closed = true;
    emailController.dispose();
    passwordController.dispose();
    emailFocus.dispose();
    passwordFocus.dispose();
    await _controller.close();
  }
}
