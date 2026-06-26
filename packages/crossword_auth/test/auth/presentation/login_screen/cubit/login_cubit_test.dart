import 'package:flutter_test/flutter_test.dart';
import 'package:crossword_auth/auth/domain/entities/auth_failure.dart';
import 'package:crossword_auth/auth/presentation/login_screen/cubit/login_cubit.dart';
import 'package:crossword_auth/auth/presentation/login_screen/cubit/login_state.dart';

import '../../../support/fake_auth_service.dart';

void main() {
  late FakeAuthService service;
  late LoginCubit cubit;

  setUp(() {
    service = FakeAuthService();
    cubit = LoginCubit(authService: service);
  });

  tearDown(() {
    cubit.close();
    service.dispose();
  });

  test('starts in sign-in mode', () {
    expect(cubit.state.mode, LoginMode.signIn);
  });

  test('toggleMode flips to register and back', () {
    cubit.toggleMode();
    expect(cubit.state.mode, LoginMode.register);
    cubit.toggleMode();
    expect(cubit.state.mode, LoginMode.signIn);
  });

  test('submit in sign-in mode calls signInWithEmail', () async {
    cubit.emailController.text = 'a@b.se';
    cubit.passwordController.text = 'secret1';

    await cubit.submit();

    expect(service.calls, contains('signInWithEmail'));
    expect(service.lastEmail, 'a@b.se');
  });

  test('submit in register mode calls registerWithEmail', () async {
    cubit.toggleMode();
    cubit.emailController.text = 'a@b.se';
    cubit.passwordController.text = 'secret1';

    await cubit.submit();

    expect(service.calls, contains('registerWithEmail'));
  });

  test('submit with short password emits a validation error and does not call the service', () async {
    cubit.emailController.text = 'a@b.se';
    cubit.passwordController.text = '123';

    final states = <LoginState>[];
    final sub = cubit.stream.listen(states.add);

    await cubit.submit();
    await Future<void>.delayed(Duration.zero);

    expect(service.calls, isEmpty);
    expect(states.whereType<LoginError>().single.reason,
        LoginErrorReason.passwordTooShort);

    await sub.cancel();
  });

  test('a thrown AuthFailure becomes a LoginError with the mapped reason', () async {
    service.throwOnNextCall = const AuthFailure(AuthFailureReason.invalidCredentials);
    cubit.emailController.text = 'a@b.se';
    cubit.passwordController.text = 'secret1';

    final states = <LoginState>[];
    final sub = cubit.stream.listen(states.add);

    await cubit.submit();
    await Future<void>.delayed(Duration.zero);

    expect(states.whereType<LoginError>().single.reason,
        LoginErrorReason.invalidCredentials);
    expect(cubit.state.isSubmitting, isFalse);

    await sub.cancel();
  });

  test('sendPasswordReset with empty email emits validation error', () async {
    final states = <LoginState>[];
    final sub = cubit.stream.listen(states.add);

    await cubit.sendPasswordReset();
    await Future<void>.delayed(Duration.zero);

    expect(service.calls, isEmpty);
    expect(states.whereType<LoginError>().single.reason,
        LoginErrorReason.emailRequired);

    await sub.cancel();
  });

  test('sendPasswordReset with email calls service and emits confirmation', () async {
    cubit.emailController.text = 'a@b.se';

    final states = <LoginState>[];
    final sub = cubit.stream.listen(states.add);

    await cubit.sendPasswordReset();
    await Future<void>.delayed(Duration.zero);

    expect(service.calls, contains('sendPasswordReset'));
    expect(states.whereType<LoginPasswordResetSent>(), isNotEmpty);

    await sub.cancel();
  });

  test('signInWithGoogle delegates to the service', () async {
    await cubit.signInWithGoogle();
    expect(service.calls, contains('signInWithGoogle'));
  });

  test('a cancelled social sign-in is swallowed (no error state)', () async {
    service.throwOnNextCall = const AuthFailure(AuthFailureReason.cancelled);

    final states = <LoginState>[];
    final sub = cubit.stream.listen(states.add);

    await cubit.signInWithApple();
    await Future<void>.delayed(Duration.zero);

    expect(states.whereType<LoginError>(), isEmpty);
    await sub.cancel();
  });
}
