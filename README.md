# crosswords

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Deploying the Web App to Firebase Hosting

The web target lives in `apps/web` and deploys to the Firebase project
`korsord-crosswords` (live at https://korsord-crosswords.web.app).

### One command

```bash
scripts/deploy_web.sh
```

This does a **clean** build of `apps/web` and then deploys hosting:

```bash
cd apps/web
flutter clean
flutter pub get
flutter build web --release
cd ..
firebase deploy --only hosting --project korsord-crosswords
```

### Prerequisites

- Firebase CLI installed (`npm install -g firebase-tools`) and authenticated
  (`firebase login`).
- Hosting config is already checked in: `firebase.json` (serves
  `apps/web/build/web` with SPA rewrites) and `.firebaserc` (default project
  `korsord-crosswords`).

### Always clean-build before deploying

Never `firebase deploy` a plain incremental web build. An incremental
`flutter build web` can reuse a stale generated web plugin registrant
(`web_plugin_registrant.dart`) that omits `FirebaseCoreWeb`. The deployed site
then throws inside `Firebase.initializeApp` and white-screens before any UI
renders. `flutter clean` forces the registrant to regenerate with all web
plugins, which `scripts/deploy_web.sh` does for you.

### After deploying

Returning visitors may need one hard refresh because of Flutter's
service-worker cache. To verify a deploy, load the live URL in a fresh
(cache-disabled) browser session and confirm no runtime exception is thrown
during startup.
