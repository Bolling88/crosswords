import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crossword_auth/auth/common/strings/auth_strings.dart';
import 'package:crossword_auth/auth/domain/entities/auth_user.dart';
import 'package:crossword_auth/auth/presentation/auth_gate/auth_gate.dart';

import '../../support/fake_auth_service.dart';

void main() {
  testWidgets('shows login when signed out, child when signed in', (tester) async {
    final service = FakeAuthService();

    await tester.pumpWidget(MaterialApp(
      home: AuthGate(
        authService: service,
        child: const Text('PUZZLES'),
      ),
    ));
    await tester.pump();

    expect(find.text('PUZZLES'), findsNothing);
    expect(find.text(AuthStrings.signInTitle), findsWidgets);

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
