import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/auth_user.dart';
import '../../../domain/services/auth_service.dart';
import 'auth_gate_state.dart';

/// Subscribes to [AuthService.currentUser] and exposes a gate state. The cubit
/// (not a widget) is what listens to the service notifier, per project rules.
class AuthGateCubit extends Cubit<AuthGateState> {
  final AuthService _authService;

  AuthGateCubit({required AuthService authService})
      : _authService = authService,
        super(_stateFor(authService.currentUser.value)) {
    _authService.currentUser.addListener(_onUserChanged);
  }

  void _onUserChanged() => emit(_stateFor(_authService.currentUser.value));

  static AuthGateState _stateFor(AuthUser? user) => user == null
      ? const AuthGateState.unauthenticated()
      : AuthGateState.authenticated(user);

  @override
  Future<void> close() {
    _authService.currentUser.removeListener(_onUserChanged);
    return super.close();
  }
}
