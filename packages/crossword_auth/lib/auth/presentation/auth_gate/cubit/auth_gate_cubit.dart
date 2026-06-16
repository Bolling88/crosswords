import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/services/auth_service.dart';
import 'auth_gate_state.dart';

/// Subscribes to [AuthService] and exposes a gate state. The cubit (not a
/// widget) is what listens to the service notifiers, per project rules.
class AuthGateCubit extends Cubit<AuthGateState> {
  final AuthService _authService;

  AuthGateCubit({required AuthService authService})
      : _authService = authService,
        super(_stateFor(authService)) {
    _authService.currentUser.addListener(_onChanged);
    _authService.isInitializing.addListener(_onChanged);
  }

  void _onChanged() => emit(_stateFor(_authService));

  static AuthGateState _stateFor(AuthService service) {
    if (service.isInitializing.value) return const AuthGateState.loading();
    final user = service.currentUser.value;
    return user == null
        ? const AuthGateState.unauthenticated()
        : AuthGateState.authenticated(user);
  }

  @override
  Future<void> close() {
    _authService.currentUser.removeListener(_onChanged);
    _authService.isInitializing.removeListener(_onChanged);
    return super.close();
  }
}
