import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crossword_auth/crossword_auth.dart';

import '../../support/fake_auth_service.dart';

final CrosswordAuthL10n _l10n = lookupCrosswordAuthL10n(const Locale('sv'));

Widget _harness(FakeAuthService service) {
  return MaterialApp(
    locale: const Locale('sv'),
    localizationsDelegates: const [
      CrosswordAuthL10n.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('sv'), Locale('en')],
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

    expect(find.text(_l10n.signInTitle), findsWidgets);

    await tester.tap(find.text(_l10n.toggleToRegister));
    await tester.pump();

    expect(find.text(_l10n.registerTitle), findsWidgets);
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

    expect(find.text(_l10n.emailRequired), findsOneWidget);
    addTearDown(service.dispose);
  });
}
