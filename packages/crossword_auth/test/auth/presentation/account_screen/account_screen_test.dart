import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crossword_auth/crossword_auth.dart';
import 'package:crossword_ui/crossword_ui.dart';

import '../../support/fake_auth_service.dart';

final CrosswordAuthL10n _l10n = lookupCrosswordAuthL10n(const Locale('sv'));

Widget _harness(FakeAuthService service) {
  return MaterialApp(
    locale: const Locale('sv'),
    localizationsDelegates: const [
      CrosswordAuthL10n.delegate,
      CrosswordUiL10n.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('sv'), Locale('en')],
    home: RepositoryProvider<AuthService>.value(
      value: service,
      child: const AccountScreen(),
    ),
  );
}

void main() {
  testWidgets('shows the signed-in email', (tester) async {
    final service = FakeAuthService(
      initial: const AuthUser(uid: 'u1', email: 'a@b.se', displayName: null, photoUrl: null),
    );
    await tester.pumpWidget(_harness(service));

    expect(find.text('a@b.se'), findsOneWidget);
    addTearDown(service.dispose);
  });

  testWidgets('Logga ut shows a confirm dialog; confirming calls signOut', (tester) async {
    final service = FakeAuthService(
      initial: const AuthUser(uid: 'u1', email: 'a@b.se', displayName: null, photoUrl: null),
    );
    await tester.pumpWidget(_harness(service));

    // Tap the body button.
    await tester.tap(find.text(_l10n.signOutAction).first);
    await tester.pumpAndSettle();

    // Dialog visible.
    expect(find.text(_l10n.signOutConfirmTitle), findsOneWidget);

    // Confirm (the dialog's Logga ut action — last match).
    await tester.tap(find.text(_l10n.signOutAction).last);
    await tester.pumpAndSettle();

    expect(service.calls, contains('signOut'));
    addTearDown(service.dispose);
  });
}
