import 'package:crossword_auth/auth/domain/entities/auth_user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('two users with the same fields are equal', () {
    const a = AuthUser(uid: 'u1', email: 'a@b.se', displayName: 'A', photoUrl: null);
    const b = AuthUser(uid: 'u1', email: 'a@b.se', displayName: 'A', photoUrl: null);

    expect(a, b);
  });

  test('users with different uids are not equal', () {
    const a = AuthUser(uid: 'u1', email: 'a@b.se', displayName: null, photoUrl: null);
    const b = AuthUser(uid: 'u2', email: 'a@b.se', displayName: null, photoUrl: null);

    expect(a, isNot(b));
  });
}
