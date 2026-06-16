import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../entities/auth_failure.dart';
import '../entities/auth_user.dart';
import 'auth_service.dart';

/// [AuthService] backed by Firebase Authentication.
///
/// Identity only — the backend (future) verifies [getIdToken]. Email/password
/// is identical on every platform; Google/Apple branch on [kIsWeb] (popup on
/// web, native plugin + credential on mobile).
class FirebaseAuthService implements AuthService {
  /// The web OAuth client ID, needed by google_sign_in on Android to mint an
  /// ID token whose audience Firebase accepts. Read it from the generated
  /// `firebase_options.dart` web options (`clientId`) or the Google Cloud
  /// console (OAuth 2.0 "Web client"). Pass null on pure-iOS where the
  /// GoogleService-Info.plist client is used.
  final String? googleServerClientId;

  final FirebaseAuth _auth;
  final ValueNotifier<AuthUser?> _currentUser;

  FirebaseAuthService({FirebaseAuth? auth, this.googleServerClientId})
      : _auth = auth ?? FirebaseAuth.instance,
        _currentUser = ValueNotifier<AuthUser?>(null) {
    _currentUser.value = _mapUser(_auth.currentUser);
    _auth.authStateChanges().listen((user) {
      _currentUser.value = _mapUser(user);
    });
  }

  @override
  ValueListenable<AuthUser?> get currentUser => _currentUser;

  static AuthUser? _mapUser(User? user) {
    if (user == null) return null;
    return AuthUser(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      photoUrl: user.photoURL,
    );
  }

  @override
  Future<void> signInWithEmail(String email, String password) {
    return _guard(
      () async {
        await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      },
    );
  }

  @override
  Future<void> registerWithEmail(String email, String password) {
    return _guard(
      () async {
        await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      },
    );
  }

  @override
  Future<void> sendPasswordReset(String email) {
    return _guard(
      () async {
        await _auth.sendPasswordResetEmail(email: email);
      },
    );
  }

  @override
  Future<void> signInWithGoogle() async {
    if (kIsWeb) {
      await _guard(() async {
        await _auth.signInWithPopup(GoogleAuthProvider());
      });
      return;
    }
    try {
      final signIn = GoogleSignIn.instance;
      await signIn.initialize(serverClientId: googleServerClientId);
      // authenticate() throws GoogleSignInException on cancellation.
      final account = await signIn.authenticate(
        scopeHint: const ['email'],
      );
      // authentication getter is synchronous in google_sign_in 7.x.
      final idToken = account.authentication.idToken;
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      await _guard(() async {
        await _auth.signInWithCredential(credential);
      });
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const AuthFailure(AuthFailureReason.cancelled);
      }
      throw const AuthFailure(AuthFailureReason.unknown);
    }
  }

  @override
  Future<void> signInWithApple() async {
    if (kIsWeb) {
      await _guard(() async {
        await _auth.signInWithPopup(AppleAuthProvider());
      });
      return;
    }
    try {
      final rawNonce = _randomNonce();
      final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );
      final oauth = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
      );
      await _guard(() async {
        await _auth.signInWithCredential(oauth);
      });
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        throw const AuthFailure(AuthFailureReason.cancelled);
      }
      throw const AuthFailure(AuthFailureReason.unknown);
    }
  }

  @override
  Future<void> signOut() async {
    if (!kIsWeb) {
      // Best-effort: also clear the native Google session.
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {
        // Non-fatal — Firebase sign-out below is what matters.
      }
    }
    await _auth.signOut();
  }

  @override
  Future<String?> getIdToken() async => _auth.currentUser?.getIdToken();

  @override
  void dispose() => _currentUser.dispose();

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on FirebaseAuthException catch (e) {
      throw authFailureFromCode(e.code);
    }
  }

  static String _randomNonce([int length = 32]) {
    const chars =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
  }
}
