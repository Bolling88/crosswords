# Firebase Auth & Login — Design

**Date:** 2026-06-15
**Status:** Approved (design), pending implementation plan

## Goal

Add user authentication to both apps (`apps/mobile`, `apps/web`) using Firebase
Authentication as the identity provider. Login is a **hard gate**: on launch the
user sees a login screen and must sign in or create an account before reaching
the puzzles.

Firebase is used **for identity only**. A separate backend (not built yet) will
verify the Firebase ID token. This pass builds the token *seam*
(`AuthService.getIdToken()`) but makes no backend call.

### Sign-in methods (launch)

- Email / password (with account creation + password reset)
- Google
- Apple

No anonymous sign-in. No Firestore. No cloud progress sync (progress stays in
the existing local `ProgressService`).

## Current state

- Dart workspace monorepo: `apps/mobile`, `apps/web`, shared
  `packages/crossword_core` (domain/JSON) and `packages/crossword_ui`
  (grid widgets, cubits, theme, `CrosswordPlayer`).
- Firebase is wired **only for web hosting** (`.firebaserc` →
  `korsord-crosswords`, `firebase.json` → hosting). No Firebase SDK deps, no
  auth, no registered Firebase apps (iOS/Android/Web all unregistered).
- Authenticated Firebase user: `bolling.ludwig@gmail.com`. Project on the Spark
  (free) plan — fine, Auth is free and Firestore is not used.
- Progress is local-only (`ProgressService` over `SharedPreferences`).

## Architecture

### New package: `packages/crossword_auth`

A new workspace package both apps depend on, isolating Firebase auth deps from
`crossword_core` and `crossword_ui`. Mobile and web share one login UI.

Follows the repo conventions in `CLAUDE.md`: clean architecture, Cubit pattern,
all widgets `StatelessWidget`, services accessed only by cubits, centralized
Swedish `Strings`, `AppColors`, `UniqueKey` event states for side effects.

```
packages/crossword_auth/
  lib/
    crossword_auth.dart                       # barrel export
    auth/
      domain/
        entities/
          auth_user.dart                      # uid, email, displayName, photoUrl
        services/
          auth_service.dart                   # interface + FirebaseAuthService impl
      presentation/
        login_screen/
          cubit/
            login_cubit.dart
            login_state.dart
          widgets/...
          login_screen.dart                   # Screen / Builder / Content (3-widget pattern)
        auth_gate/
          cubit/
            auth_gate_cubit.dart
            auth_gate_state.dart
          auth_gate.dart                       # gate widget
    common/
      strings/auth_strings.dart                # Swedish user-facing copy
```

Dependencies added to `crossword_auth`: `firebase_core`, `firebase_auth`,
`google_sign_in`, `sign_in_with_apple`, `flutter_bloc`, `equatable`.

### `AuthUser` (domain entity)

Plain domain model — Firebase types never leak past `AuthService`. Extends
`Equatable`, `const` constructor, `final` fields. Fields: `uid`, `email`,
`displayName`, `photoUrl`. Built from a `firebase_auth.User` inside the service.

### `AuthService` (shared cross-feature state)

Interface plus `FirebaseAuthService` implementation. Per `CLAUDE.md`,
cross-feature shared state uses a `ValueNotifier`; only cubits read it.

- `ValueNotifier<AuthUser?> currentUser` — driven by
  `FirebaseAuth.instance.authStateChanges()`; `null` when signed out.
- `Future<void> signInWithEmail(String email, String password)`
- `Future<void> registerWithEmail(String email, String password)`
- `Future<void> sendPasswordReset(String email)`
- `Future<void> signInWithGoogle()`
- `Future<void> signInWithApple()`
- `Future<void> signOut()`
- `Future<String?> getIdToken()` — **the backend seam.** Delegates to
  `FirebaseAuth.instance.currentUser?.getIdToken()`. Returned to a future
  backend for verification; unused for now.

Errors surface as a small set of typed failures (e.g. `AuthFailure` with a
reason) translated to Swedish messages in the cubit, so `FirebaseAuthException`
codes don't leak into the UI.

**Platform split:** email/password and `signOut`/`getIdToken` are identical on
all platforms. For Google and Apple the implementation branches on `kIsWeb`:

- **Mobile (iOS/Android):** native `google_sign_in` / `sign_in_with_apple` →
  build a Firebase `AuthCredential` → `signInWithCredential`.
- **Web:** `FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider())` and
  `signInWithPopup(OAuthProvider("apple.com"))`.

### `AuthGateCubit` + `AuthGate`

`AuthGateCubit` subscribes to `AuthService.currentUser` (a cubit, not a widget,
touches the notifier) and emits `AuthGateState`:

- `AuthGateLoading` — initial, before the first auth-state event.
- `AuthGateUnauthenticated` — show `LoginScreen`.
- `AuthGateAuthenticated(AuthUser user)` — show `child`.

`AuthGate({required Widget child})` is a `StatelessWidget` that provides
`AuthGateCubit` and uses `BlocBuilder` to switch between a loading indicator,
`LoginScreen`, and `child`. Each app wraps its existing root in `AuthGate`.

### `LoginScreen` + `LoginCubit`

Three-widget pattern (`LoginScreen` / `LoginScreenBuilder` /
`LoginScreenContent`), all `StatelessWidget`.

**Combined sign-in / create-account screen.** A `mode` field in `LoginState`
toggles between *Logga in* and *Skapa konto*; the email/password form is shared,
with a toggle link to switch and a *Glömt lösenord?* link that triggers
`sendPasswordReset`. Google and Apple buttons appear in both modes.

`LoginCubit` (per `CLAUDE.md`):

- Owns `emailController`, `passwordController`, and `FocusNode`s; disposes them
  in `close()`.
- Holds `LoginState`: `mode` (signIn | register), `isSubmitting`, validation
  flags.
- Calls `AuthService`; on success the `AuthGate` reacts automatically via
  `currentUser` (no manual navigation needed).
- Surfaces errors / password-reset confirmation via `UniqueKey` event states
  (`ShowAuthError`, `ShowResetSent`), shown as SnackBars in the Builder's
  listener. Never via `copyWith`.

All user-facing copy in Swedish via `AuthStrings`. Colors via `AppColors`.
Tappable rows use `InkWell` in `Material`.

### Per-app wiring

Each app independently:

1. Adds `firebase_core` + `crossword_auth` to its `pubspec.yaml`.
2. Gets its own generated `firebase_options.dart`.
3. In `main()`: `WidgetsFlutterBinding.ensureInitialized()` →
   `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)` →
   construct `FirebaseAuthService` → provide it (alongside existing services) →
   wrap the root widget in `AuthGate`.

`apps/web` additionally loads the Firebase web SDK / config as part of the
generated web setup.

## Firebase & platform configuration (non-code work)

Sequenced in the implementation plan:

1. **Register apps** (iOS, Android, Web) in `korsord-crosswords` via
   `flutterfire configure` (or Firebase MCP `firebase_create_app` +
   `firebase_get_sdk_config`). Produces `firebase_options.dart`,
   `google-services.json` (Android), `GoogleService-Info.plist` (iOS).
2. **Enable providers** in Firebase Auth: Email/Password, Google, Apple.
3. **Google:** add Android SHA-1/SHA-256 (Firebase MCP `firebase_create_android_sha`),
   iOS reversed-client-ID URL scheme in `Info.plist`, web authorized domains.
4. **Apple (needs Apple Developer account — partly manual):**
   - iOS: add the *Sign in with Apple* capability.
   - Web: create an Apple *Service ID* + key and register it in Firebase Auth's
     Apple provider config.
   The plan will flag the exact manual values needed; everything else is
   automated.

## Out of scope

- Any call to the verifying backend (only `getIdToken()` seam is built).
- Firestore / cloud progress sync.
- Anonymous / guest play.
- Account management UI beyond login + password reset + sign-out
  (e.g. change email, delete account, profile editing).

## Testing

- `AuthService`: unit-test the `AuthUser` mapping, error translation, and
  `getIdToken` delegation with a faked/mocked `FirebaseAuth`.
- `AuthGateCubit`: emits Loading → Unauthenticated/Authenticated as the
  `currentUser` notifier changes (`bloc_test`).
- `LoginCubit`: mode toggle, validation, success path (service called), error
  event states, password-reset event state — with a fake `AuthService`.
- `AuthUser` entity: equality / `props`.

## Open risks

- Apple sign-in on web requires Apple Developer configuration that can't be
  fully automated; if the Apple Service ID isn't ready, Apple-on-web ships
  behind the other two methods without blocking email/Google.
- `google_sign_in` major-version API differences between mobile and web are
  sidestepped by using `signInWithPopup` on web.
