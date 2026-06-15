import 'package:equatable/equatable.dart';

import '../../../domain/entities/auth_user.dart';

enum AuthGateStatus { loading, authenticated, unauthenticated }

class AuthGateState extends Equatable {
  final AuthGateStatus status;
  final AuthUser? user;

  const AuthGateState._(this.status, this.user);

  const AuthGateState.loading() : this._(AuthGateStatus.loading, null);
  const AuthGateState.unauthenticated()
      : this._(AuthGateStatus.unauthenticated, null);
  const AuthGateState.authenticated(AuthUser user)
      : this._(AuthGateStatus.authenticated, user);

  @override
  List<Object?> get props => [status, user];
}
