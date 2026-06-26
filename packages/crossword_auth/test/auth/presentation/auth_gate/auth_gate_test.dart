import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crossword_auth/crossword_auth.dart';

import '../../support/fake_auth_service.dart';

final CrosswordAuthL10n _l10n = lookupCrosswordAuthL10n(const Locale('sv'));

void main() {
  testWidgets('shows login when signed out, child when signed in', (tester) async {
    final service = FakeAuthService();

    await tester.pumpWidget(MaterialApp(
      locale: const Locale('sv'),
      localizationsDelegates: const [
        CrosswordAuthL10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('sv'), Locale('en')],
      home: AuthGate(
        authService: service,
        child: const Text('PUZZLES'),
      ),
    ));
    await tester.pump();

    expect(find.text('PUZZLES'), findsNothing);
    expect(find.text(_l10n.signInTitle), findsWidgets);

    service.emit(const AuthUser(
      uid: 'u1',
      email: 'a@b.se',
      displayName: null,
      photoUrl: null,
    ));
    await tester.pumpAndSettle();

    expect(find.text('PUZZLES'), findsOneWidget);
    addTearDown(service.dispose);
  });
}
