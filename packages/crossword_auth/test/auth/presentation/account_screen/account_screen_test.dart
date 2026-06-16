import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crossword_auth/auth/common/strings/auth_strings.dart';
import 'package:crossword_auth/auth/domain/entities/auth_user.dart';
import 'package:crossword_auth/auth/presentation/account_screen/account_screen.dart';

import '../../support/fake_auth_service.dart';

Widget _harness(FakeAuthService service) {
  return MaterialApp(
    home: AccountScreen(authService: service),
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
    await tester.tap(find.text(AuthStrings.signOutAction).first);
    await tester.pumpAndSettle();

    // Dialog visible.
    expect(find.text(AuthStrings.signOutConfirmTitle), findsOneWidget);

    // Confirm (the dialog's Logga ut action — last match).
    await tester.tap(find.text(AuthStrings.signOutAction).last);
    await tester.pumpAndSettle();

    expect(service.calls, contains('signOut'));
    addTearDown(service.dispose);
  });
}
