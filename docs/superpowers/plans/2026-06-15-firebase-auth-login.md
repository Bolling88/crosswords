# Firebase Auth & Login Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a hard-gated Firebase Authentication login (email/password, Google, Apple) to both `apps/mobile` and `apps/web`, with a shared `crossword_auth` package and a `getIdToken()` seam for a future verifying backend.

**Architecture:** A new workspace package `packages/crossword_auth` holds an `AuthUser` domain entity, an `AuthService` interface with a `FirebaseAuthService` implementation (Firebase types never leak past it), an `AuthGate` (cubit-driven gate widget) and a combined sign-in/create-account `LoginScreen`. Both apps initialise Firebase in `main()`, provide the service, and wrap their root in `AuthGate`. Pure/cubit logic is built first with TDD against a hand-written `FakeAuthService`; the Firebase-bound impl and platform config come after the apps are registered so real OAuth client IDs exist.

**Tech Stack:** Flutter, flutter_bloc (Cubit), equatable, firebase_core, firebase_auth, google_sign_in (v7), sign_in_with_apple, crypto (Apple nonce). Tests use `flutter_test` with hand-written fakes (the repo uses no bloc_test/mocktail).

---

## Conventions (from CLAUDE.md — apply to every task)

- All widgets are `StatelessWidget`. No `StatefulWidget`/`setState`/`initState`/`dispose`/`addListener` **in widgets**. Local state lives in a Cubit. Services (with `ValueNotifier`) are touched **only by cubits**.
- Cubit dependencies are private (`final AuthService _authService;`). `TextEditingController`/`FocusNode` live in the Cubit and are disposed in `close()`.
- Side effects (errors, toasts) use dedicated event-state classes carrying `final Key key = UniqueKey();` with `props` overriding to include the key. Never via `copyWith`.
- Screens follow the 3-widget pattern: `XScreen` (provides BlocProvider) → `XScreenBuilder` (BlocConsumer) → `XScreenContent` (pure UI).
- No hardcoded user-facing strings — use an `AuthStrings` constant class, Swedish copy. No hardcoded colors — use `AppColors` (from `crossword_ui`). No `!` null-assertion. No `withOpacity` (use `withAlpha`). Tappable rows use `InkWell` in `Material`. Trailing commas, `const`, single quotes.
- Import order: Dart/Flutter → packages → local, blank line between groups.

## File Structure

Created under `packages/crossword_auth/`:

| File | Responsibility |
|------|----------------|
| `pubspec.yaml`, `analysis_options.yaml` | Package manifest + lints |
| `lib/crossword_auth.dart` | Barrel export |
| `lib/auth/common/strings/auth_strings.dart` | Swedish auth copy |
| `lib/auth/domain/entities/auth_user.dart` | `AuthUser` domain model |
| `lib/auth/domain/entities/auth_failure.dart` | `AuthFailure` + `authFailureFromCode()` |
| `lib/auth/domain/services/auth_service.dart` | `AuthService` interface |
| `lib/auth/domain/services/firebase_auth_service.dart` | `FirebaseAuthService` impl |
| `lib/auth/presentation/auth_gate/cubit/auth_gate_cubit.dart` + `auth_gate_state.dart` | Gate state machine |
| `lib/auth/presentation/auth_gate/auth_gate.dart` | Gate widget |
| `lib/auth/presentation/login_screen/cubit/login_cubit.dart` + `login_state.dart` | Login logic |
| `lib/auth/presentation/login_screen/login_screen.dart` | Login UI (3-widget) |
| `test/auth/...` | Mirrors lib for entity/cubit tests + `FakeAuthService` |

Modified: root `pubspec.yaml` (workspace members), `apps/mobile/pubspec.yaml`, `apps/mobile/lib/main.dart`, `apps/web/pubspec.yaml`, `apps/web/lib/main.dart`, iOS/Android native config, `firebase.json`.

---

## Task 1: Scaffold the `crossword_auth` package

**Files:**
- Create: `packages/crossword_auth/pubspec.yaml`
- Create: `packages/crossword_auth/analysis_options.yaml`
- Create: `packages/crossword_auth/lib/crossword_auth.dart`
- Modify: `pubspec.yaml` (root, workspace list)

- [ ] **Step 1: Create the package pubspec**

`packages/crossword_auth/pubspec.yaml`:
```yaml
name: crossword_auth
description: Firebase auth identity + shared login UI for the Crosswords apps.
publish_to: 'none'
version: 0.0.1

environment:
  sdk: ^3.11.5

resolution: workspace

dependencies:
  flutter:
    sdk: flutter
  flutter_bloc: ^9.1.1
  equatable: ^2.0.7
  firebase_core: ^3.8.0
  firebase_auth: ^5.3.4
  google_sign_in: ^7.0.0
  sign_in_with_apple: ^6.1.3
  crypto: ^3.0.6
  crossword_ui:
    path: ../crossword_ui

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0

flutter:
  uses-material-design: true
```

- [ ] **Step 2: Create the package analysis_options** mirroring the repo lints

`packages/crossword_auth/analysis_options.yaml`:
```yaml
include: package:flutter_lints/flutter.yaml

linter:
  rules:
    - avoid_print
    - prefer_single_quotes
    - prefer_const_constructors
    - prefer_const_declarations
    - require_trailing_commas
    - avoid_unnecessary_containers
    - use_decorated_box
```

- [ ] **Step 3: Create an empty barrel** (filled in by later tasks)

`packages/crossword_auth/lib/crossword_auth.dart`:
```dart
export 'auth/common/strings/auth_strings.dart';
export 'auth/domain/entities/auth_failure.dart';
export 'auth/domain/entities/auth_user.dart';
export 'auth/domain/services/auth_service.dart';
export 'auth/domain/services/firebase_auth_service.dart';
export 'auth/presentation/auth_gate/auth_gate.dart';
export 'auth/presentation/auth_gate/cubit/auth_gate_cubit.dart';
export 'auth/presentation/auth_gate/cubit/auth_gate_state.dart';
export 'auth/presentation/login_screen/cubit/login_cubit.dart';
export 'auth/presentation/login_screen/cubit/login_state.dart';
export 'auth/presentation/login_screen/login_screen.dart';
```

Note: these target files don't exist yet, so `dart analyze` will report missing exports until later tasks create them. That's expected within this task; do not resolve by deleting exports.

- [ ] **Step 4: Register the package in the workspace**

In root `pubspec.yaml`, add to the `workspace:` list (keep alphabetical-ish, after the apps):
```yaml
workspace:
  - apps/mobile
  - apps/web
  - packages/crossword_auth
  - packages/crossword_core
  - packages/crossword_ui
```

- [ ] **Step 5: Resolve dependencies**

Run: `flutter pub get`
Expected: Resolves the workspace including `crossword_auth` and downloads firebase/google/apple packages. (Export errors from Step 3 are analyzer-only and do not block `pub get`.)

- [ ] **Step 6: Commit**

```bash
git add packages/crossword_auth/pubspec.yaml packages/crossword_auth/analysis_options.yaml packages/crossword_auth/lib/crossword_auth.dart pubspec.yaml pubspec.lock
git commit -m "build(auth): scaffold crossword_auth package"
```

---

## Task 2: `AuthUser` entity (TDD)

**Files:**
- Create: `packages/crossword_auth/lib/auth/domain/entities/auth_user.dart`
- Test: `packages/crossword_auth/test/auth/domain/entities/auth_user_test.dart`

- [ ] **Step 1: Write the failing test**

`packages/crossword_auth/test/auth/domain/entities/auth_user_test.dart`:
```dart
import 'package:crossword_auth/crossword_auth.dart';
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/auth/domain/entities/auth_user_test.dart` (from `packages/crossword_auth`)
Expected: FAIL — `AuthUser` is not defined.

- [ ] **Step 3: Write the entity**

`packages/crossword_auth/lib/auth/domain/entities/auth_user.dart`:
```dart
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/auth/domain/entities/auth_user_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add packages/crossword_auth/lib/auth/domain/entities/auth_user.dart packages/crossword_auth/test/auth/domain/entities/auth_user_test.dart
git commit -m "feat(auth): AuthUser domain entity"
```

---

## Task 3: `AuthFailure` + error mapping (TDD)

**Files:**
- Create: `packages/crossword_auth/lib/auth/domain/entities/auth_failure.dart`
- Test: `packages/crossword_auth/test/auth/domain/entities/auth_failure_test.dart`

- [ ] **Step 1: Write the failing test**

`packages/crossword_auth/test/auth/domain/entities/auth_failure_test.dart`:
```dart
import 'package:crossword_auth/crossword_auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps known Firebase codes to typed reasons', () {
    expect(authFailureFromCode('invalid-credential').reason,
        AuthFailureReason.invalidCredentials);
    expect(authFailureFromCode('wrong-password').reason,
        AuthFailureReason.invalidCredentials);
    expect(authFailureFromCode('email-already-in-use').reason,
        AuthFailureReason.emailAlreadyInUse);
    expect(authFailureFromCode('invalid-email').reason,
        AuthFailureReason.invalidEmail);
    expect(authFailureFromCode('weak-password').reason,
        AuthFailureReason.weakPassword);
    expect(authFailureFromCode('network-request-failed').reason,
        AuthFailureReason.network);
  });

  test('maps unknown codes to the generic reason', () {
    expect(authFailureFromCode('something-odd').reason, AuthFailureReason.unknown);
  });

  test('cancelled is its own reason for aborted social sign-in', () {
    expect(const AuthFailure(AuthFailureReason.cancelled).reason,
        AuthFailureReason.cancelled);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/auth/domain/entities/auth_failure_test.dart`
Expected: FAIL — `AuthFailure`/`authFailureFromCode` undefined.

- [ ] **Step 3: Write the failure type and mapper**

`packages/crossword_auth/lib/auth/domain/entities/auth_failure.dart`:
```dart
/// Provider-agnostic reasons a sign-in / registration can fail. The UI maps
/// these to Swedish copy; Firebase error codes never reach widgets.
enum AuthFailureReason {
  invalidCredentials,
  emailAlreadyInUse,
  invalidEmail,
  weakPassword,
  network,
  cancelled,
  unknown,
}

/// A typed auth error thrown by the service layer.
class AuthFailure implements Exception {
  final AuthFailureReason reason;

  const AuthFailure(this.reason);
}

/// Translate a Firebase Auth error `code` into an [AuthFailure].
AuthFailure authFailureFromCode(String code) {
  switch (code) {
    case 'invalid-credential':
    case 'wrong-password':
    case 'user-not-found':
      return const AuthFailure(AuthFailureReason.invalidCredentials);
    case 'email-already-in-use':
      return const AuthFailure(AuthFailureReason.emailAlreadyInUse);
    case 'invalid-email':
      return const AuthFailure(AuthFailureReason.invalidEmail);
    case 'weak-password':
      return const AuthFailure(AuthFailureReason.weakPassword);
    case 'network-request-failed':
      return const AuthFailure(AuthFailureReason.network);
    default:
      return const AuthFailure(AuthFailureReason.unknown);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/auth/domain/entities/auth_failure_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add packages/crossword_auth/lib/auth/domain/entities/auth_failure.dart packages/crossword_auth/test/auth/domain/entities/auth_failure_test.dart
git commit -m "feat(auth): typed AuthFailure and Firebase code mapping"
```

---

## Task 4: `AuthService` interface + `AuthStrings`

**Files:**
- Create: `packages/crossword_auth/lib/auth/domain/services/auth_service.dart`
- Create: `packages/crossword_auth/lib/auth/common/strings/auth_strings.dart`

No test (an abstract interface + constants). It is exercised by the cubit tests via `FakeAuthService` (Task 5).

- [ ] **Step 1: Write the `AuthService` interface**

`packages/crossword_auth/lib/auth/domain/services/auth_service.dart`:
```dart
import 'package:flutter/foundation.dart';

import '../entities/auth_user.dart';

/// Cross-feature shared auth state. Only cubits touch this service.
///
/// Implementations expose the current user via [currentUser] (driven by the
/// backing provider's auth-state stream) and throw [AuthFailure] on errors.
abstract class AuthService {
  /// The signed-in user, or null when signed out. Cubits listen to this.
  ValueListenable<AuthUser?> get currentUser;

  Future<void> signInWithEmail(String email, String password);

  Future<void> registerWithEmail(String email, String password);

  Future<void> sendPasswordReset(String email);

  Future<void> signInWithGoogle();

  Future<void> signInWithApple();

  Future<void> signOut();

  /// The current user's Firebase ID token for the verifying backend, or null
  /// when signed out. The backend seam — unused until the backend exists.
  Future<String?> getIdToken();

  /// Release resources (the backing notifier / stream subscription).
  void dispose();
}
```

- [ ] **Step 2: Write `AuthStrings`** (Swedish)

`packages/crossword_auth/lib/auth/common/strings/auth_strings.dart`:
```dart
/// Centralized user-facing strings for the auth feature. Language: Swedish.
class AuthStrings {
  const AuthStrings._();

  // Screen titles / mode toggle
  static const String signInTitle = 'Logga in';
  static const String registerTitle = 'Skapa konto';
  static const String toggleToRegister = 'Skapa ett konto';
  static const String toggleToSignIn = 'Har du redan ett konto? Logga in';

  // Fields
  static const String emailLabel = 'E-post';
  static const String passwordLabel = 'Lösenord';

  // Primary actions
  static const String signInAction = 'Logga in';
  static const String registerAction = 'Skapa konto';
  static const String forgotPassword = 'Glömt lösenord?';

  // Social
  static const String continueWithGoogle = 'Fortsätt med Google';
  static const String continueWithApple = 'Fortsätt med Apple';
  static const String socialDivider = 'eller';

  // Confirmations
  static const String resetSent =
      'Vi har skickat en återställningslänk till din e-post.';

  // Validation
  static const String emailRequired = 'Ange din e-postadress.';
  static const String passwordRequired = 'Ange ditt lösenord.';
  static const String passwordTooShort = 'Lösenordet måste vara minst 6 tecken.';

  // Errors (mapped from AuthFailureReason)
  static const String errorInvalidCredentials = 'Fel e-post eller lösenord.';
  static const String errorEmailInUse = 'E-postadressen används redan.';
  static const String errorInvalidEmail = 'Ogiltig e-postadress.';
  static const String errorWeakPassword = 'Lösenordet är för svagt.';
  static const String errorNetwork = 'Nätverksfel. Försök igen.';
  static const String errorGeneric = 'Något gick fel. Försök igen.';
}
```

- [ ] **Step 3: Verify it analyzes**

Run: `flutter analyze lib/auth/domain/services/auth_service.dart lib/auth/common/strings/auth_strings.dart` (from `packages/crossword_auth`)
Expected: No issues for these two files (the barrel may still flag not-yet-created exports — ignore those).

- [ ] **Step 4: Commit**

```bash
git add packages/crossword_auth/lib/auth/domain/services/auth_service.dart packages/crossword_auth/lib/auth/common/strings/auth_strings.dart
git commit -m "feat(auth): AuthService interface and Swedish AuthStrings"
```

---

## Task 5: `FakeAuthService` test double + `AuthGateCubit` (TDD)

**Files:**
- Create: `packages/crossword_auth/test/auth/support/fake_auth_service.dart`
- Create: `packages/crossword_auth/lib/auth/presentation/auth_gate/cubit/auth_gate_state.dart`
- Create: `packages/crossword_auth/lib/auth/presentation/auth_gate/cubit/auth_gate_cubit.dart`
- Test: `packages/crossword_auth/test/auth/presentation/auth_gate/cubit/auth_gate_cubit_test.dart`

- [ ] **Step 1: Write the `FakeAuthService`** (shared test double, used here and in Task 6)

`packages/crossword_auth/test/auth/support/fake_auth_service.dart`:
```dart
import 'package:flutter/foundation.dart';

import 'package:crossword_auth/crossword_auth.dart';

/// Hand-written test double (the repo uses no mocking libraries). Drive
/// [user] to simulate auth-state changes; methods record calls and can be
/// set to throw.
class FakeAuthService implements AuthService {
  final ValueNotifier<AuthUser?> user;
  AuthFailure? throwOnNextCall;

  final List<String> calls = <String>[];
  String? lastEmail;
  String? lastPassword;

  FakeAuthService({AuthUser? initial}) : user = ValueNotifier<AuthUser?>(initial);

  void emit(AuthUser? value) => user.value = value;

  void _maybeThrow(String call) {
    calls.add(call);
    final failure = throwOnNextCall;
    if (failure != null) {
      throwOnNextCall = null;
      throw failure;
    }
  }

  @override
  ValueListenable<AuthUser?> get currentUser => user;

  @override
  Future<void> signInWithEmail(String email, String password) async {
    lastEmail = email;
    lastPassword = password;
    _maybeThrow('signInWithEmail');
  }

  @override
  Future<void> registerWithEmail(String email, String password) async {
    lastEmail = email;
    lastPassword = password;
    _maybeThrow('registerWithEmail');
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    lastEmail = email;
    _maybeThrow('sendPasswordReset');
  }

  @override
  Future<void> signInWithGoogle() async => _maybeThrow('signInWithGoogle');

  @override
  Future<void> signInWithApple() async => _maybeThrow('signInWithApple');

  @override
  Future<void> signOut() async => _maybeThrow('signOut');

  @override
  Future<String?> getIdToken() async {
    _maybeThrow('getIdToken');
    return user.value == null ? null : 'fake-token';
  }

  @override
  void dispose() => user.dispose();
}
```

- [ ] **Step 2: Write the failing `AuthGateCubit` test**

`packages/crossword_auth/test/auth/presentation/auth_gate/cubit/auth_gate_cubit_test.dart`:
```dart
import 'package:crossword_auth/crossword_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_auth_service.dart';

void main() {
  test('starts unauthenticated when no user is present', () {
    final service = FakeAuthService();
    final cubit = AuthGateCubit(authService: service);

    expect(cubit.state, const AuthGateState.unauthenticated());

    cubit.close();
    service.dispose();
  });

  test('starts authenticated when a user is already present', () {
    const user = AuthUser(uid: 'u1', email: 'a@b.se', displayName: null, photoUrl: null);
    final service = FakeAuthService(initial: user);
    final cubit = AuthGateCubit(authService: service);

    expect(cubit.state, const AuthGateState.authenticated(user));

    cubit.close();
    service.dispose();
  });

  test('reacts to sign-in then sign-out', () async {
    const user = AuthUser(uid: 'u1', email: 'a@b.se', displayName: null, photoUrl: null);
    final service = FakeAuthService();
    final cubit = AuthGateCubit(authService: service);

    final emitted = <AuthGateState>[];
    final sub = cubit.stream.listen(emitted.add);

    service.emit(user);
    service.emit(null);
    await Future<void>.delayed(Duration.zero);

    expect(emitted, const [
      AuthGateState.authenticated(user),
      AuthGateState.unauthenticated(),
    ]);

    await sub.cancel();
    cubit.close();
    service.dispose();
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/auth/presentation/auth_gate/cubit/auth_gate_cubit_test.dart`
Expected: FAIL — `AuthGateCubit`/`AuthGateState` undefined.

- [ ] **Step 4: Write the state**

`packages/crossword_auth/lib/auth/presentation/auth_gate/cubit/auth_gate_state.dart`:
```dart
import 'package:equatable/equatable.dart';

import '../../../domain/entities/auth_user.dart';

enum AuthGateStatus { loading, authenticated, unauthenticated }

class AuthGateState extends Equatable {
  final AuthGateStatus status;
  final AuthUser? user;

  const AuthGateState._(this.status, this.user);

  const AuthGateState.loading() : this._(AuthGateStatus.loading, null);
  const AuthGateState.unauthenticated()
      : this._(AuthGateStatus.unauthenticated, null);
  const AuthGateState.authenticated(AuthUser user)
      : this._(AuthGateStatus.authenticated, user);

  @override
  List<Object?> get props => [status, user];
}
```

- [ ] **Step 5: Write the cubit**

`packages/crossword_auth/lib/auth/presentation/auth_gate/cubit/auth_gate_cubit.dart`:
```dart
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/auth_user.dart';
import '../../../domain/services/auth_service.dart';
import 'auth_gate_state.dart';

/// Subscribes to [AuthService.currentUser] and exposes a gate state. The cubit
/// (not a widget) is what listens to the service notifier, per project rules.
class AuthGateCubit extends Cubit<AuthGateState> {
  final AuthService _authService;

  AuthGateCubit({required AuthService authService})
      : _authService = authService,
        super(_stateFor(authService.currentUser.value)) {
    _authService.currentUser.addListener(_onUserChanged);
  }

  void _onUserChanged() => emit(_stateFor(_authService.currentUser.value));

  static AuthGateState _stateFor(AuthUser? user) => user == null
      ? const AuthGateState.unauthenticated()
      : AuthGateState.authenticated(user);

  @override
  Future<void> close() {
    _authService.currentUser.removeListener(_onUserChanged);
    return super.close();
  }
}
```

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/auth/presentation/auth_gate/cubit/auth_gate_cubit_test.dart`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add packages/crossword_auth/test/auth/support/fake_auth_service.dart packages/crossword_auth/lib/auth/presentation/auth_gate/cubit/auth_gate_state.dart packages/crossword_auth/lib/auth/presentation/auth_gate/cubit/auth_gate_cubit.dart packages/crossword_auth/test/auth/presentation/auth_gate/cubit/auth_gate_cubit_test.dart
git commit -m "feat(auth): AuthGateCubit drives login gate from auth state"
```

---

## Task 6: `LoginCubit` + `LoginState` (TDD)

**Files:**
- Create: `packages/crossword_auth/lib/auth/presentation/login_screen/cubit/login_state.dart`
- Create: `packages/crossword_auth/lib/auth/presentation/login_screen/cubit/login_cubit.dart`
- Test: `packages/crossword_auth/test/auth/presentation/login_screen/cubit/login_cubit_test.dart`

- [ ] **Step 1: Write the failing test**

`packages/crossword_auth/test/auth/presentation/login_screen/cubit/login_cubit_test.dart`:
```dart
import 'package:crossword_auth/crossword_auth.dart';
import 'package:flutter_test/flutter_test.dart';

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

    expect(service.calls, isEmpty);
    expect(states.whereType<LoginError>().single.message,
        AuthStrings.passwordTooShort);

    await sub.cancel();
  });

  test('a thrown AuthFailure becomes a LoginError with mapped Swedish copy', () async {
    service.throwOnNextCall = const AuthFailure(AuthFailureReason.invalidCredentials);
    cubit.emailController.text = 'a@b.se';
    cubit.passwordController.text = 'secret1';

    final states = <LoginState>[];
    final sub = cubit.stream.listen(states.add);

    await cubit.submit();

    expect(states.whereType<LoginError>().single.message,
        AuthStrings.errorInvalidCredentials);
    expect(cubit.state.isSubmitting, isFalse);

    await sub.cancel();
  });

  test('sendPasswordReset with empty email emits validation error', () async {
    final states = <LoginState>[];
    final sub = cubit.stream.listen(states.add);

    await cubit.sendPasswordReset();

    expect(service.calls, isEmpty);
    expect(states.whereType<LoginError>().single.message, AuthStrings.emailRequired);

    await sub.cancel();
  });

  test('sendPasswordReset with email calls service and emits confirmation', () async {
    cubit.emailController.text = 'a@b.se';

    final states = <LoginState>[];
    final sub = cubit.stream.listen(states.add);

    await cubit.sendPasswordReset();

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

    expect(states.whereType<LoginError>(), isEmpty);
    await sub.cancel();
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/auth/presentation/login_screen/cubit/login_cubit_test.dart`
Expected: FAIL — `LoginCubit`/`LoginState`/`LoginMode` undefined.

- [ ] **Step 3: Write the state**

`packages/crossword_auth/lib/auth/presentation/login_screen/cubit/login_state.dart`:
```dart
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

enum LoginMode { signIn, register }

class LoginState extends Equatable {
  final LoginMode mode;
  final bool isSubmitting;

  const LoginState({this.mode = LoginMode.signIn, this.isSubmitting = false});

  @override
  List<Object?> get props => [mode, isSubmitting];

  LoginState copyWith({LoginMode? mode, bool? isSubmitting}) {
    return LoginState(
      mode: mode ?? this.mode,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }

  LoginState.copy(LoginState state)
      : mode = state.mode,
        isSubmitting = state.isSubmitting;
}

/// Event state: a transient error to show as a SnackBar. Carries a UniqueKey
/// so identical consecutive messages still trigger the listener.
class LoginError extends LoginState {
  final String message;
  @override
  final Key key = UniqueKey();

  LoginError({required LoginState state, required this.message})
      : super.copy(state);

  @override
  List<Object?> get props => [...super.props, message, key];
}

/// Event state: confirmation that a password-reset email was sent.
class LoginPasswordResetSent extends LoginState {
  @override
  final Key key = UniqueKey();

  LoginPasswordResetSent({required LoginState state}) : super.copy(state);

  @override
  List<Object?> get props => [...super.props, key];
}
```

- [ ] **Step 4: Write the cubit**

`packages/crossword_auth/lib/auth/presentation/login_screen/cubit/login_cubit.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../common/strings/auth_strings.dart';
import '../../../domain/entities/auth_failure.dart';
import '../../../domain/services/auth_service.dart';
import 'login_state.dart';

class LoginCubit extends Cubit<LoginState> {
  final AuthService _authService;

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final FocusNode emailFocus = FocusNode();
  final FocusNode passwordFocus = FocusNode();

  LoginCubit({required AuthService authService})
      : _authService = authService,
        super(const LoginState());

  void toggleMode() {
    final next =
        state.mode == LoginMode.signIn ? LoginMode.register : LoginMode.signIn;
    emit(state.copyWith(mode: next));
  }

  Future<void> submit() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    final validation = _validate(email, password);
    if (validation != null) {
      emit(LoginError(state: state, message: validation));
      return;
    }

    emit(state.copyWith(isSubmitting: true));
    try {
      if (state.mode == LoginMode.signIn) {
        await _authService.signInWithEmail(email, password);
      } else {
        await _authService.registerWithEmail(email, password);
      }
      // Success: AuthGate reacts to currentUser; nothing more to do here.
      emit(state.copyWith(isSubmitting: false));
    } on AuthFailure catch (failure) {
      emit(state.copyWith(isSubmitting: false));
      emit(LoginError(state: state, message: _messageFor(failure)));
    }
  }

  Future<void> sendPasswordReset() async {
    final email = emailController.text.trim();
    if (email.isEmpty) {
      emit(LoginError(state: state, message: AuthStrings.emailRequired));
      return;
    }
    try {
      await _authService.sendPasswordReset(email);
      emit(LoginPasswordResetSent(state: state));
    } on AuthFailure catch (failure) {
      emit(LoginError(state: state, message: _messageFor(failure)));
    }
  }

  Future<void> signInWithGoogle() => _social(_authService.signInWithGoogle);

  Future<void> signInWithApple() => _social(_authService.signInWithApple);

  Future<void> _social(Future<void> Function() action) async {
    emit(state.copyWith(isSubmitting: true));
    try {
      await action();
      emit(state.copyWith(isSubmitting: false));
    } on AuthFailure catch (failure) {
      emit(state.copyWith(isSubmitting: false));
      // A user-cancelled popup/sheet is not an error worth surfacing.
      if (failure.reason != AuthFailureReason.cancelled) {
        emit(LoginError(state: state, message: _messageFor(failure)));
      }
    }
  }

  String? _validate(String email, String password) {
    if (email.isEmpty) return AuthStrings.emailRequired;
    if (password.isEmpty) return AuthStrings.passwordRequired;
    if (password.length < 6) return AuthStrings.passwordTooShort;
    return null;
  }

  String _messageFor(AuthFailure failure) {
    switch (failure.reason) {
      case AuthFailureReason.invalidCredentials:
        return AuthStrings.errorInvalidCredentials;
      case AuthFailureReason.emailAlreadyInUse:
        return AuthStrings.errorEmailInUse;
      case AuthFailureReason.invalidEmail:
        return AuthStrings.errorInvalidEmail;
      case AuthFailureReason.weakPassword:
        return AuthStrings.errorWeakPassword;
      case AuthFailureReason.network:
        return AuthStrings.errorNetwork;
      case AuthFailureReason.cancelled:
      case AuthFailureReason.unknown:
        return AuthStrings.errorGeneric;
    }
  }

  @override
  Future<void> close() {
    emailController.dispose();
    passwordController.dispose();
    emailFocus.dispose();
    passwordFocus.dispose();
    return super.close();
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/auth/presentation/login_screen/cubit/login_cubit_test.dart`
Expected: PASS (all cases).

- [ ] **Step 6: Commit**

```bash
git add packages/crossword_auth/lib/auth/presentation/login_screen/cubit/login_state.dart packages/crossword_auth/lib/auth/presentation/login_screen/cubit/login_cubit.dart packages/crossword_auth/test/auth/presentation/login_screen/cubit/login_cubit_test.dart
git commit -m "feat(auth): LoginCubit with validation, modes, and error mapping"
```

---

## Task 7: `LoginScreen` UI (3-widget pattern)

**Files:**
- Create: `packages/crossword_auth/lib/auth/presentation/login_screen/login_screen.dart`
- Test: `packages/crossword_auth/test/auth/presentation/login_screen/login_screen_test.dart`

- [ ] **Step 1: Write a widget test for the key behaviours**

`packages/crossword_auth/test/auth/presentation/login_screen/login_screen_test.dart`:
```dart
import 'package:crossword_auth/crossword_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/auth/presentation/login_screen/login_screen_test.dart`
Expected: FAIL — `LoginScreenBuilder` undefined.

- [ ] **Step 3: Write the screen** (Screen / Builder / Content)

`packages/crossword_auth/lib/auth/presentation/login_screen/login_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:crossword_ui/crossword_ui.dart';

import '../../common/strings/auth_strings.dart';
import '../../domain/services/auth_service.dart';
import 'cubit/login_cubit.dart';
import 'cubit/login_state.dart';

/// Provides the [LoginCubit]. Built standalone by [AuthGate] when signed out.
class LoginScreen extends StatelessWidget {
  final AuthService authService;

  const LoginScreen({required this.authService, super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LoginCubit(authService: authService),
      child: const LoginScreenBuilder(),
    );
  }
}

class LoginScreenBuilder extends StatelessWidget {
  const LoginScreenBuilder({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LoginCubit, LoginState>(
      listenWhen: (_, state) =>
          state is LoginError || state is LoginPasswordResetSent,
      listener: (context, state) {
        final messenger = ScaffoldMessenger.of(context);
        if (state is LoginError) {
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(state.message)));
        } else if (state is LoginPasswordResetSent) {
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(const SnackBar(content: Text(AuthStrings.resetSent)));
        }
      },
      builder: (context, state) => LoginScreenContent(state: state),
    );
  }
}

class LoginScreenContent extends StatelessWidget {
  final LoginState state;

  const LoginScreenContent({required this.state, super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<LoginCubit>();
    final isRegister = state.mode == LoginMode.register;
    final title =
        isRegister ? AuthStrings.registerTitle : AuthStrings.signInTitle;
    final primaryLabel =
        isRegister ? AuthStrings.registerAction : AuthStrings.signInAction;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(color: AppColors.ink),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    key: const Key('login_email'),
                    controller: cubit.emailController,
                    focusNode: cubit.emailFocus,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    enabled: !state.isSubmitting,
                    decoration: const InputDecoration(
                      labelText: AuthStrings.emailLabel,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('login_password'),
                    controller: cubit.passwordController,
                    focusNode: cubit.passwordFocus,
                    obscureText: true,
                    enabled: !state.isSubmitting,
                    decoration: const InputDecoration(
                      labelText: AuthStrings.passwordLabel,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (!isRegister) ...[
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed:
                            state.isSubmitting ? null : cubit.sendPasswordReset,
                        child: const Text(AuthStrings.forgotPassword),
                      ),
                    ),
                  ] else
                    const SizedBox(height: 12),
                  const SizedBox(height: 4),
                  FilledButton(
                    key: const Key('login_submit'),
                    onPressed: state.isSubmitting ? null : cubit.submit,
                    child: state.isSubmitting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(primaryLabel),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: state.isSubmitting ? null : cubit.toggleMode,
                    child: Text(
                      isRegister
                          ? AuthStrings.toggleToSignIn
                          : AuthStrings.toggleToRegister,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const _OrDivider(),
                  const SizedBox(height: 16),
                  _SocialButton(
                    label: AuthStrings.continueWithGoogle,
                    onPressed:
                        state.isSubmitting ? null : cubit.signInWithGoogle,
                  ),
                  const SizedBox(height: 12),
                  _SocialButton(
                    label: AuthStrings.continueWithApple,
                    onPressed: state.isSubmitting ? null : cubit.signInWithApple,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.gridLine)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            AuthStrings.socialDivider,
            style: const TextStyle(color: AppColors.inkMuted),
          ),
        ),
        const Expanded(child: Divider(color: AppColors.gridLine)),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const _SocialButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.paper,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppColors.gridLine),
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.ink),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/auth/presentation/login_screen/login_screen_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add packages/crossword_auth/lib/auth/presentation/login_screen/login_screen.dart packages/crossword_auth/test/auth/presentation/login_screen/login_screen_test.dart
git commit -m "feat(auth): combined sign-in/register LoginScreen"
```

---

## Task 8: `AuthGate` widget

**Files:**
- Create: `packages/crossword_auth/lib/auth/presentation/auth_gate/auth_gate.dart`
- Test: `packages/crossword_auth/test/auth/presentation/auth_gate/auth_gate_test.dart`

- [ ] **Step 1: Write a widget test**

`packages/crossword_auth/test/auth/presentation/auth_gate/auth_gate_test.dart`:
```dart
import 'package:crossword_auth/crossword_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
    await tester.pump();

    expect(find.text('PUZZLES'), findsOneWidget);
    addTearDown(service.dispose);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/auth/presentation/auth_gate/auth_gate_test.dart`
Expected: FAIL — `AuthGate` undefined.

- [ ] **Step 3: Write the gate widget**

`packages/crossword_auth/lib/auth/presentation/auth_gate/auth_gate.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/services/auth_service.dart';
import '../login_screen/login_screen.dart';
import 'cubit/auth_gate_cubit.dart';
import 'cubit/auth_gate_state.dart';

/// Hard auth gate: renders [child] when signed in, otherwise the login screen.
class AuthGate extends StatelessWidget {
  final AuthService authService;
  final Widget child;

  const AuthGate({
    required this.authService,
    required this.child,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AuthGateCubit(authService: authService),
      child: BlocBuilder<AuthGateCubit, AuthGateState>(
        builder: (context, state) {
          switch (state.status) {
            case AuthGateStatus.loading:
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            case AuthGateStatus.unauthenticated:
              return LoginScreen(authService: authService);
            case AuthGateStatus.authenticated:
              return child;
          }
        },
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/auth/presentation/auth_gate/auth_gate_test.dart`
Expected: PASS.

- [ ] **Step 5: Run the whole package suite + analyze**

Run: `flutter test` then `flutter analyze` (from `packages/crossword_auth`)
Expected: All tests pass; analyze reports no issues (barrel now resolves except `firebase_auth_service.dart`, created in Task 10 — temporarily remove that one export line if analyze blocks, and restore it in Task 10). 

Note: To keep this task green, comment out the `firebase_auth_service.dart` export in `lib/crossword_auth.dart` now and restore it in Task 10 Step 5.

- [ ] **Step 6: Commit**

```bash
git add packages/crossword_auth/lib/auth/presentation/auth_gate/auth_gate.dart packages/crossword_auth/test/auth/presentation/auth_gate/auth_gate_test.dart packages/crossword_auth/lib/crossword_auth.dart
git commit -m "feat(auth): AuthGate widget switching login vs app"
```

---

## Task 9: Register Firebase apps + enable providers (configuration)

This task is configuration, not code. It must run before Task 10 so real OAuth client IDs and `firebase_options.dart` exist. Requires the FlutterFire CLI.

**Files:**
- Create (generated): `apps/mobile/lib/firebase_options.dart`, `apps/web/lib/firebase_options.dart`
- Create (generated): `apps/mobile/android/app/google-services.json`, `apps/mobile/ios/Runner/GoogleService-Info.plist`

- [ ] **Step 1: Install/verify the FlutterFire CLI**

Run:
```bash
dart pub global activate flutterfire_cli
flutterfire --version
```
Expected: prints a version. Ensure `firebase login` is already authenticated as `bolling.ludwig@gmail.com` (it is, per the environment).

- [ ] **Step 2: Configure the mobile app** (registers iOS + Android Firebase apps and writes config)

Run from `apps/mobile`:
```bash
flutterfire configure \
  --project=korsord-crosswords \
  --platforms=android,ios \
  --out=lib/firebase_options.dart \
  --ios-bundle-id=<IOS_BUNDLE_ID> \
  --android-package-name=<ANDROID_APPLICATION_ID> \
  --yes
```
Fill `<IOS_BUNDLE_ID>` from `apps/mobile/ios/Runner.xcodeproj` (PRODUCT_BUNDLE_IDENTIFIER) and `<ANDROID_APPLICATION_ID>` from `apps/mobile/android/app/build.gradle(.kts)` (`applicationId`).
Expected: writes `lib/firebase_options.dart`, `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`, and registers the apps in the project.

- [ ] **Step 3: Configure the web app**

Run from `apps/web`:
```bash
flutterfire configure \
  --project=korsord-crosswords \
  --platforms=web \
  --out=lib/firebase_options.dart \
  --yes
```
Expected: writes `apps/web/lib/firebase_options.dart` and registers a Web app.

- [ ] **Step 4: Enable sign-in providers in the Firebase console**

Manual (console → Authentication → Sign-in method): enable **Email/Password**, **Google**, and **Apple**. (Apple's full config is finished in Task 13.) Verify with the MCP tool by listing apps:

Run (MCP): `firebase_list_apps` with platform `all`.
Expected: now lists the iOS, Android, and Web apps just created.

- [ ] **Step 5: Verify Android google-services applied / gradle wiring**

Ensure `apps/mobile/android/app/build.gradle` (or `.gradle.kts`) applies the Google services plugin and that `android/build.gradle` has the classpath. FlutterFire usually patches this; if not, add:
- Project `android/settings.gradle` plugins block: `id "com.google.gms.google-services" version "4.4.2" apply false`
- App `android/app/build.gradle`: `apply plugin: 'com.google.gms.google-services'` (or `id("com.google.gms.google-services")` in `.kts`).

Run: `cd apps/mobile && flutter build apk --debug` (or `flutter run` on a device)
Expected: builds without "google-services.json missing" errors.

- [ ] **Step 6: Commit the generated config**

```bash
git add apps/mobile/lib/firebase_options.dart apps/web/lib/firebase_options.dart apps/mobile/android/app/google-services.json apps/mobile/ios/Runner/GoogleService-Info.plist apps/mobile/android apps/mobile/ios
git commit -m "build(auth): register Firebase apps and add generated config"
```
Note: `google-services.json`/`GoogleService-Info.plist` contain only public client config (safe to commit), not secrets.

---

## Task 10: `FirebaseAuthService` implementation

The Firebase-bound implementation. Not unit-tested (it wraps plugin singletons); verified by the manual smoke test in Task 14. The pure logic it relies on (`AuthUser` mapping shape, `authFailureFromCode`) is already tested.

**Files:**
- Create: `packages/crossword_auth/lib/auth/domain/services/firebase_auth_service.dart`
- Modify: `packages/crossword_auth/lib/crossword_auth.dart` (restore the export)

- [ ] **Step 1: Write the implementation**

`packages/crossword_auth/lib/auth/domain/services/firebase_auth_service.dart`:
```dart
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
    return _guard(() =>
        _auth.signInWithEmailAndPassword(email: email, password: password));
  }

  @override
  Future<void> registerWithEmail(String email, String password) {
    return _guard(() => _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        ));
  }

  @override
  Future<void> sendPasswordReset(String email) {
    return _guard(() => _auth.sendPasswordResetEmail(email: email));
  }

  @override
  Future<void> signInWithGoogle() async {
    if (kIsWeb) {
      await _guard(() => _auth.signInWithPopup(GoogleAuthProvider()));
      return;
    }
    try {
      final signIn = GoogleSignIn.instance;
      await signIn.initialize(serverClientId: googleServerClientId);
      final account = await signIn.authenticate(scopeHint: const ['email']);
      final idToken = account.authentication.idToken;
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      await _guard(() => _auth.signInWithCredential(credential));
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
      await _guard(() => _auth.signInWithPopup(AppleAuthProvider()));
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
      await _guard(() => _auth.signInWithCredential(oauth));
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
```

- [ ] **Step 2: Restore the barrel export**

In `lib/crossword_auth.dart`, ensure this line is present/uncommented:
```dart
export 'auth/domain/services/firebase_auth_service.dart';
```

- [ ] **Step 3: Analyze**

Run: `flutter analyze` (from `packages/crossword_auth`)
Expected: No issues. (If `GoogleSignInException`/`GoogleSignInExceptionCode` names differ in the resolved google_sign_in version, check `flutter pub deps` for the exact API and adjust the catch — the cancel-detection is the only version-sensitive part.)

- [ ] **Step 4: Run the full package suite** (ensures nothing regressed)

Run: `flutter test` (from `packages/crossword_auth`)
Expected: All prior tests still PASS (this task adds no tests; it's plugin-bound).

- [ ] **Step 5: Commit**

```bash
git add packages/crossword_auth/lib/auth/domain/services/firebase_auth_service.dart packages/crossword_auth/lib/crossword_auth.dart
git commit -m "feat(auth): FirebaseAuthService (email, Google, Apple, token seam)"
```

---

## Task 11: Wire the gate into `apps/mobile`

**Files:**
- Modify: `apps/mobile/pubspec.yaml`
- Modify: `apps/mobile/lib/main.dart`

- [ ] **Step 1: Add dependencies**

In `apps/mobile/pubspec.yaml`, under `dependencies:` add:
```yaml
  firebase_core: ^3.8.0
  crossword_auth:
    path: ../../packages/crossword_auth
```
Run: `flutter pub get`
Expected: resolves.

- [ ] **Step 2: Initialise Firebase, provide the service, wrap root in `AuthGate`**

Edit `apps/mobile/lib/main.dart`. Add imports (package group):
```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:crossword_auth/crossword_auth.dart';
```
and the local import:
```dart
import 'firebase_options.dart';
```

Change `main()` to initialise Firebase and build the service:
```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  final prefs = await SharedPreferences.getInstance();
  final fontService = FontService(prefs: prefs);
  final settingsService = GameplaySettingsService(prefs: prefs);
  final progressService = ProgressService(prefs: prefs);
  final authService = FirebaseAuthService();
  final puzzle = await loadBundledPuzzle();
  runApp(CrosswordsApp(
    fontService: fontService,
    settingsService: settingsService,
    progressService: progressService,
    authService: authService,
    puzzle: puzzle,
  ));
}
```

Add the field + constructor param to `CrosswordsApp`:
```dart
  final AuthService authService;
```
(in the constructor, add `required this.authService,`)

Register it in `MultiRepositoryProvider.providers`:
```dart
        RepositoryProvider<AuthService>.value(value: authService),
```

Wrap the `home:` widget in the gate:
```dart
        home: AuthGate(
          authService: authService,
          child: MobileCrosswordScreen(puzzle: puzzle),
        ),
```

- [ ] **Step 3: Analyze**

Run: `cd apps/mobile && flutter analyze`
Expected: No issues.

- [ ] **Step 4: Smoke-run on a simulator/emulator**

Run: `cd apps/mobile && flutter run`
Expected: app launches to the login screen (hard gate); after a successful email sign-in it shows the crossword.

- [ ] **Step 5: Commit**

```bash
git add apps/mobile/pubspec.yaml apps/mobile/lib/main.dart pubspec.lock
git commit -m "feat(mobile): gate the app behind Firebase login"
```

---

## Task 12: Wire the gate into `apps/web`

**Files:**
- Modify: `apps/web/pubspec.yaml`
- Modify: `apps/web/lib/main.dart`
- Modify: `apps/web/web/index.html` (Firebase web init, if not auto-handled)

- [ ] **Step 1: Add dependencies**

In `apps/web/pubspec.yaml`, under `dependencies:` add:
```yaml
  firebase_core: ^3.8.0
  crossword_auth:
    path: ../../packages/crossword_auth
```
Run: `flutter pub get`
Expected: resolves.

- [ ] **Step 2: Initialise Firebase + wrap root in `AuthGate`**

Edit `apps/web/lib/main.dart`. Add imports:
```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:crossword_auth/crossword_auth.dart';

import 'firebase_options.dart';
```
Update `main()` (mirror Task 11 Step 2): add `await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);` and construct the service. On web, Google/Apple go through `signInWithPopup`, so `googleServerClientId` is irrelevant — construct it plainly:
```dart
  final authService = FirebaseAuthService();
```
Pass it into `CrosswordsWebApp`, add the field/param, register the `RepositoryProvider<AuthService>.value(value: authService)`, and wrap `home:`:
```dart
        home: AuthGate(
          authService: authService,
          child: WebCrosswordScreen(puzzle: puzzle),
        ),
```

- [ ] **Step 3: Analyze**

Run: `cd apps/web && flutter analyze`
Expected: No issues.

- [ ] **Step 4: Smoke-run in Chrome**

Run: `cd apps/web && flutter run -d chrome`
Expected: launches to the login screen; email sign-in works; Google opens a popup. (Apple-on-web works after Task 13.)

- [ ] **Step 5: Add Firebase Hosting authorized domain (if testing on the deployed URL)**

Manual (console → Authentication → Settings → Authorized domains): ensure the Hosting domain (`korsord-crosswords.web.app` / custom) is listed. `localhost` is allowed by default for local runs.

- [ ] **Step 6: Commit**

```bash
git add apps/web/pubspec.yaml apps/web/lib/main.dart pubspec.lock
git commit -m "feat(web): gate the app behind Firebase login"
```

---

## Task 13: Platform OAuth config (Google + Apple)

Configuration to make Google and Apple actually succeed on devices. Code is already in place; these are project/native settings.

- [ ] **Step 1: Android — add SHA-1 and SHA-256 to the Firebase Android app**

Get the debug signing report:
```bash
cd apps/mobile/android && ./gradlew signingReport
```
Copy the SHA-1 and SHA-256 for the debug variant. Add them via the Firebase MCP tool:

Run (MCP) `firebase_create_android_sha` for each: app id = the Android app id from `firebase_list_apps`, `sha_hash` = the value, `cert_type` = `SHA_1` then `SHA_256`.
Then re-download `google-services.json` (FlutterFire: re-run Task 9 Step 2, or console → download) and replace `apps/mobile/android/app/google-services.json`.
Expected: Google sign-in stops failing with `ApiException: 10` on Android.

- [ ] **Step 2: iOS — add the reversed client ID URL scheme**

Open `apps/mobile/ios/Runner/GoogleService-Info.plist`, copy `REVERSED_CLIENT_ID`. In Xcode (Runner target → Info → URL Types) or directly in `ios/Runner/Info.plist`, add:
```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>REVERSED_CLIENT_ID_VALUE_HERE</string>
    </array>
  </dict>
</array>
```
Expected: Google sign-in returns to the app on iOS.

- [ ] **Step 3: iOS — add the Sign in with Apple capability**

In Xcode: Runner target → Signing & Capabilities → **+ Capability → Sign in with Apple**. This edits `Runner.entitlements`.
Expected: `SignInWithApple.getAppleIDCredential` works on a real device / simulator (iOS 13+).

- [ ] **Step 4: Apple — Service ID + key for web (Apple Developer account; partly manual)**

For Apple-on-web only. In the Apple Developer portal: create a **Services ID**, enable Sign in with Apple, set the return URL to `https://korsord-crosswords.firebaseapp.com/__/auth/handler`. Create a **Sign in with Apple key**. In Firebase console → Authentication → Apple provider, fill **Services ID**, **Apple Team ID**, **Key ID**, and the **private key**.
Expected: Apple popup on web completes. If the Apple Developer account isn't ready, ship Email + Google first; Apple-on-web is independent and can follow.

- [ ] **Step 5: Manual verification matrix** (no commit; native config already committed in Task 9 where relevant)

Verify on each platform: Email sign-in/register, Google, Apple, password reset email arrives, sign-out returns to the login screen.

- [ ] **Step 6: Commit any native file changes**

```bash
git add apps/mobile/ios/Runner/Info.plist apps/mobile/ios/Runner/Runner.entitlements apps/mobile/android/app/google-services.json
git commit -m "build(auth): Google/Apple native OAuth config"
```

---

## Task 14: Full verification pass

**Files:** none (verification only).

- [ ] **Step 1: Analyze the whole workspace**

Run: `flutter analyze` (from repo root)
Expected: No issues in `packages/crossword_auth`, `apps/mobile`, `apps/web`.

- [ ] **Step 2: Run all tests**

Run: `flutter test` in `packages/crossword_auth`, then `apps/mobile`, then `apps/web`.
Expected: all green.

- [ ] **Step 3: Manual smoke on mobile + web**

Confirm the hard gate (login appears first), a full email round-trip, Google, Apple (where configured), password reset, and sign-out → back to login. Confirm `getIdToken()` returns a non-null string when signed in (temporary debug print in a cubit, removed before commit — do not leave `print` in, it violates `avoid_print`).

- [ ] **Step 4: Final commit if any fixups were needed**

```bash
git add -A
git commit -m "chore(auth): verification fixups"
```

---

## Notes & risks

- **google_sign_in v7 cancel detection** (`GoogleSignInException`/`GoogleSignInExceptionCode`) is the one version-sensitive spot. If the resolved API differs, adjust only the `catch` in `signInWithGoogle`; the rest of the flow (initialize → authenticate → idToken → credential) is stable.
- **Apple-on-web** depends on Apple Developer config (Task 13 Step 4) and can lag the other methods without blocking them.
- **Plugin versions** in Task 1 are floor constraints (`^`); `flutter pub get` may resolve higher. If a major bump changes an API used here, prefer pinning to the resolved minor in `pubspec.yaml`.
- **No backend call** is built — only `getIdToken()`. When the verifying backend exists, add a thin client that calls it with the token; the seam is ready.
