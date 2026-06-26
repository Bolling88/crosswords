import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/auth_failure.dart';
import '../../../domain/services/auth_service.dart';
import 'login_state.dart';

class LoginCubit extends Cubit<LoginState> {
  final AuthService _authService;

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final FocusNode emailFocus = FocusNode();
  final FocusNode passwordFocus = FocusNode();

  LoginCubit({required AuthService authService})
      : _authService = authService,
        super(const LoginState());

  void toggleMode() {
    final next =
        state.mode == LoginMode.signIn ? LoginMode.register : LoginMode.signIn;
    emit(state.copyWith(mode: next));
  }

  Future<void> submit() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    final validation = _validate(email, password);
    if (validation != null) {
      emit(LoginError(state: state, reason: validation));
      return;
    }

    emit(state.copyWith(isSubmitting: true));
    try {
      if (state.mode == LoginMode.signIn) {
        await _authService.signInWithEmail(email, password);
      } else {
        await _authService.registerWithEmail(email, password);
      }
      // Success: AuthGate reacts to currentUser and removes this screen, which
      // closes the cubit — guard the reset so a late emit can't throw.
      if (!isClosed) emit(state.copyWith(isSubmitting: false));
    } on AuthFailure catch (failure) {
      emit(LoginError(
        state: state.copyWith(isSubmitting: false),
        reason: _reasonFor(failure),
      ));
    }
  }

  Future<void> sendPasswordReset() async {
    final email = emailController.text.trim();
    if (email.isEmpty) {
      emit(LoginError(state: state, reason: LoginErrorReason.emailRequired));
      return;
    }
    try {
      await _authService.sendPasswordReset(email);
      emit(LoginPasswordResetSent(state: state));
    } on AuthFailure catch (failure) {
      emit(LoginError(state: state, reason: _reasonFor(failure)));
    }
  }

  Future<void> signInWithGoogle() => _social(_authService.signInWithGoogle);

  Future<void> signInWithApple() => _social(_authService.signInWithApple);

  Future<void> _social(Future<void> Function() action) async {
    emit(state.copyWith(isSubmitting: true));
    try {
      await action();
      if (!isClosed) emit(state.copyWith(isSubmitting: false));
    } on AuthFailure catch (failure) {
      // A user-cancelled popup/sheet is not an error worth surfacing.
      if (failure.reason == AuthFailureReason.cancelled) {
        emit(state.copyWith(isSubmitting: false));
      } else {
        emit(LoginError(
          state: state.copyWith(isSubmitting: false),
          reason: _reasonFor(failure),
        ));
      }
    }
  }

  LoginErrorReason? _validate(String email, String password) {
    if (email.isEmpty) return LoginErrorReason.emailRequired;
    if (password.isEmpty) return LoginErrorReason.passwordRequired;
    if (password.length < 6) return LoginErrorReason.passwordTooShort;
    return null;
  }

  LoginErrorReason _reasonFor(AuthFailure failure) {
    switch (failure.reason) {
      case AuthFailureReason.invalidCredentials:
        return LoginErrorReason.invalidCredentials;
      case AuthFailureReason.emailAlreadyInUse:
        return LoginErrorReason.emailInUse;
      case AuthFailureReason.invalidEmail:
        return LoginErrorReason.invalidEmail;
      case AuthFailureReason.weakPassword:
        return LoginErrorReason.weakPassword;
      case AuthFailureReason.network:
        return LoginErrorReason.network;
      case AuthFailureReason.cancelled:
      case AuthFailureReason.unknown:
        return LoginErrorReason.generic;
    }
  }

  @override
  Future<void> close() {
    emailController.dispose();
    passwordController.dispose();
    emailFocus.dispose();
    passwordFocus.dispose();
    return super.close();
  }
}
