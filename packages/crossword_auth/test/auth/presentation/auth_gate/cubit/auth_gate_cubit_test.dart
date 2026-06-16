import 'package:flutter_test/flutter_test.dart';
import 'package:crossword_auth/auth/domain/entities/auth_user.dart';
import 'package:crossword_auth/auth/presentation/auth_gate/cubit/auth_gate_cubit.dart';
import 'package:crossword_auth/auth/presentation/auth_gate/cubit/auth_gate_state.dart';

import '../../../support/fake_auth_service.dart';

void main() {
  test('starts unauthenticated when no user is present', () {
    final service = FakeAuthService();
    final cubit = AuthGateCubit(authService: service);

    expect(cubit.state, const AuthGateState.unauthenticated());

    cubit.close();
    service.dispose();
  });

  test('starts authenticated when a user is already present', () {
    const user = AuthUser(uid: 'u1', email: 'a@b.se', displayName: null, photoUrl: null);
    final service = FakeAuthService(initial: user);
    final cubit = AuthGateCubit(authService: service);

    expect(cubit.state, const AuthGateState.authenticated(user));

    cubit.close();
    service.dispose();
  });

  test('starts in loading while initializing, then resolves on first event', () async {
    const user = AuthUser(uid: 'u1', email: 'a@b.se', displayName: null, photoUrl: null);
    final service = FakeAuthService(isInitializing: true);
    final cubit = AuthGateCubit(authService: service);

    expect(cubit.state, const AuthGateState.loading());

    // First auth event: the user resolves and initialization completes.
    service.emit(user);
    service.initializing.value = false;
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state, const AuthGateState.authenticated(user));

    cubit.close();
    service.dispose();
  });

  test('reacts to sign-in then sign-out', () async {
    const user = AuthUser(uid: 'u1', email: 'a@b.se', displayName: null, photoUrl: null);
    final service = FakeAuthService();
    final cubit = AuthGateCubit(authService: service);

    final emitted = <AuthGateState>[];
    final sub = cubit.stream.listen(emitted.add);

    service.emit(user);
    service.emit(null);
    await Future<void>.delayed(Duration.zero);

    expect(emitted, const [
      AuthGateState.authenticated(user),
      AuthGateState.unauthenticated(),
    ]);

    await sub.cancel();
    cubit.close();
    service.dispose();
  });
}
