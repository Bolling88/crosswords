import 'package:flutter_test/flutter_test.dart';
import 'package:crossword_auth/auth/domain/entities/auth_failure.dart';
import 'package:crossword_auth/auth/domain/entities/auth_user.dart';
import 'package:crossword_auth/auth/presentation/account_screen/cubit/account_cubit.dart';
import 'package:crossword_auth/auth/presentation/account_screen/cubit/account_state.dart';

import '../../../support/fake_auth_service.dart';

void main() {
  test('initial state carries the current user', () {
    const user = AuthUser(uid: 'u1', email: 'a@b.se', displayName: null, photoUrl: null);
    final service = FakeAuthService(initial: user);
    final cubit = AccountCubit(authService: service);

    expect(cubit.state.user, user);

    cubit.close();
    service.dispose();
  });

  test('signOut calls the service and emits AccountSignedOut', () async {
    const user = AuthUser(uid: 'u1', email: 'a@b.se', displayName: null, photoUrl: null);
    final service = FakeAuthService(initial: user);
    final cubit = AccountCubit(authService: service);

    final states = <AccountState>[];
    final sub = cubit.stream.listen(states.add);

    await cubit.signOut();
    await Future<void>.delayed(Duration.zero);

    expect(service.calls, contains('signOut'));
    expect(states.whereType<AccountSignedOut>(), isNotEmpty);

    await sub.cancel();
    cubit.close();
    service.dispose();
  });

  test('a failed signOut emits AccountSignOutError', () async {
    const user = AuthUser(uid: 'u1', email: 'a@b.se', displayName: null, photoUrl: null);
    final service = FakeAuthService(initial: user);
    service.throwOnNextCall = const AuthFailure(AuthFailureReason.unknown);
    final cubit = AccountCubit(authService: service);

    final states = <AccountState>[];
    final sub = cubit.stream.listen(states.add);

    await cubit.signOut();
    await Future<void>.delayed(Duration.zero);

    expect(states.whereType<AccountSignOutError>(), isNotEmpty);
    expect(states.whereType<AccountSignedOut>(), isEmpty);

    await sub.cancel();
    cubit.close();
    service.dispose();
  });
}
