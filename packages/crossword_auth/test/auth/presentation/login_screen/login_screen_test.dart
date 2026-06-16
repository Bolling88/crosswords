import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crossword_auth/auth/common/strings/auth_strings.dart';
import 'package:crossword_auth/auth/presentation/login_screen/cubit/login_cubit.dart';
import 'package:crossword_auth/auth/presentation/login_screen/login_screen.dart';

import '../../support/fake_auth_service.dart';

Widget _harness(FakeAuthService service) {
  return MaterialApp(
    home: BlocProvider(
      create: (_) => LoginCubit(authService: service),
      child: const LoginScreenBuilder(),
    ),
  );
}

void main() {
  testWidgets('shows sign-in title and toggles to register', (tester) async {
    final service = FakeAuthService();
    await tester.pumpWidget(_harness(service));

    expect(find.text(AuthStrings.signInTitle), findsWidgets);

    await tester.tap(find.text(AuthStrings.toggleToRegister));
    await tester.pump();

    expect(find.text(AuthStrings.registerTitle), findsWidgets);
    addTearDown(service.dispose);
  });

  testWidgets('typing email/password and submitting calls the service', (tester) async {
    final service = FakeAuthService();
    await tester.pumpWidget(_harness(service));

    await tester.enterText(find.byKey(const Key('login_email')), 'a@b.se');
    await tester.enterText(find.byKey(const Key('login_password')), 'secret1');
    await tester.tap(find.byKey(const Key('login_submit')));
    await tester.pump();

    expect(service.calls, contains('signInWithEmail'));
    addTearDown(service.dispose);
  });

  testWidgets('an error state shows a SnackBar', (tester) async {
    final service = FakeAuthService();
    await tester.pumpWidget(_harness(service));

    await tester.tap(find.byKey(const Key('login_submit'))); // empty -> validation error
    await tester.pump();

    expect(find.text(AuthStrings.emailRequired), findsOneWidget);
    addTearDown(service.dispose);
  });
}
