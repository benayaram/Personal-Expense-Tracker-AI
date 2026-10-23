#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test
flutter analyze --fatal-infos
flutter test --coverage
node --test server/index.test.mjs
flutter build apk --debug
(cd android && ./gradlew testDebugUnitTest --no-daemon)
