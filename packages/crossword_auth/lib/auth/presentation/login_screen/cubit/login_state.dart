import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

enum LoginMode { signIn, register }

/// Why a sign-in / registration attempt failed. The cubit emits one of these;
/// the screen maps it to localized copy via [CrosswordAuthL10n]. Keeps human
/// strings out of the cubit (mirrors [AuthFailureReason]).
enum LoginErrorReason {
  emailRequired,
  passwordRequired,
  passwordTooShort,
  invalidCredentials,
  emailInUse,
  invalidEmail,
  weakPassword,
  network,
  generic,
}

class LoginState extends Equatable {
  final LoginMode mode;
  final bool isSubmitting;

  const LoginState({this.mode = LoginMode.signIn, this.isSubmitting = false});

  @override
  List<Object?> get props => [mode, isSubmitting];

  LoginState copyWith({LoginMode? mode, bool? isSubmitting}) {
    return LoginState(
      mode: mode ?? this.mode,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }

  LoginState.copy(LoginState state)
      : mode = state.mode,
        isSubmitting = state.isSubmitting;
}

/// Event state: a transient error to show as a SnackBar. Carries a UniqueKey
/// so identical consecutive reasons still trigger the listener.
class LoginError extends LoginState {
  final LoginErrorReason reason;
  final Key key = UniqueKey();

  LoginError({required LoginState state, required this.reason})
      : super.copy(state);

  @override
  List<Object?> get props => [...super.props, reason, key];
}

/// Event state: confirmation that a password-reset email was sent.
class LoginPasswordResetSent extends LoginState {
  final Key key = UniqueKey();

  LoginPasswordResetSent({required LoginState state}) : super.copy(state);

  @override
  List<Object?> get props => [...super.props, key];
}
