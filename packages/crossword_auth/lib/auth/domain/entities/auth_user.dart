import 'package:equatable/equatable.dart';

/// Authenticated user as the app sees it. Firebase types never leak past the
/// service boundary — the service maps `firebase_auth.User` into this.
class AuthUser extends Equatable {
  final String uid;
  final String? email;
  final String? displayName;
  final String? photoUrl;

  const AuthUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.photoUrl,
  });

  @override
  List<Object?> get props => [uid, email, displayName, photoUrl];
}
