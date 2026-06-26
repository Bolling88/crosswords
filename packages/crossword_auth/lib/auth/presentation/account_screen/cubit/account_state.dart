import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import '../../../domain/entities/auth_user.dart';

class AccountState extends Equatable {
  final AuthUser? user;

  const AccountState({this.user});

  @override
  List<Object?> get props => [user];

  AccountState.copy(AccountState state) : user = state.user;
}

/// Event state: sign-out succeeded; the UI pops back to the gate (which now
/// shows the login screen).
class AccountSignedOut extends AccountState {
  final Key key = UniqueKey();

  AccountSignedOut({required AccountState state}) : super.copy(state);

  @override
  List<Object?> get props => [...super.props, key];
}

/// Event state: sign-out failed; show a transient error. Carries no copy — the
/// screen renders the localized [CrosswordAuthL10n.errorGeneric] itself.
class AccountSignOutError extends AccountState {
  final Key key = UniqueKey();

  AccountSignOutError({required AccountState state}) : super.copy(state);

  @override
  List<Object?> get props => [...super.props, key];
}
