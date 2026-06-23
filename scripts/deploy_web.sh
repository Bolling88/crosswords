#!/usr/bin/env bash
#
# Deploy the web app (apps/web) to Firebase Hosting from a CLEAN build.
#
# Why clean every time: an incremental `flutter build web` can reuse a stale
# generated web plugin registrant (web_plugin_registrant.dart) that omits
# FirebaseCoreWeb. The deployed site then throws inside Firebase.initializeApp
# and white-screens before any UI renders. `flutter clean` forces the registrant
# to regenerate with all web plugins, which prevents that failure.
#
# Usage: scripts/deploy_web.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="korsord-crosswords"

echo "==> Clean build of apps/web"
(
  cd "$ROOT/apps/web"
  flutter clean
  flutter pub get
  flutter build web --release
)

echo "==> Deploying hosting to $PROJECT"
cd "$ROOT"
firebase deploy --only hosting --project "$PROJECT"

echo "==> Done. https://$PROJECT.web.app"
echo "Note: returning visitors may need one hard refresh (Flutter service-worker cache)."
