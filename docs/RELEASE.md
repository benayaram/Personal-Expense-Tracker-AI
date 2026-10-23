# Android development and release

## Prerequisites
Flutter 3.47.7 stable, Java 21, Android SDK platform 36 and its build tools, and the SDK/NDK versions requested by Flutter. Flutter is pinned in CI. Use Android Studio's SDK Manager and read/accept the applicable Android licenses. `flutter doctor -v` must identify the SDK and a connected supported device.

The resolved `pubspec.lock` is committed. Use `flutter pub get --enforce-lockfile` to preserve dependency resolution and package integrity. Update dependencies intentionally and rerun checks before committing a new lockfile.

```sh
flutter analyze --fatal-infos
flutter test --coverage
flutter build apk --debug
cd android
./gradlew testDebugUnitTest --no-daemon
```

Install an evaluation build with `adb install -r build/app/outputs/flutter-apk/app-debug.apk` from the project root. Enable notification access through the app disclosure; Android may require manually allowing restricted settings for sideloaded apps. Never instruct users to weaken device protections generally. Notification capture is optional, and manual entry remains available.

## Production signing
The release build deliberately has no debug-signing fallback. Create and protect your own signing key using Android's official signing workflow; do not commit the key or passwords. Losing this key can prevent future updates for sideloaded installations. Prefer Play App Signing for Play distribution.

Create ignored `android/key.properties` locally:

```properties
storeFile=/absolute/path/to/your-upload-key.jks
storePassword=YOUR_LOCAL_SECRET
keyAlias=YOUR_KEY_ALIAS
keyPassword=YOUR_LOCAL_SECRET
```

Then run `flutter build apk --release` for a signed APK or `flutter build appbundle --release` for Play. Verify the APK with `apksigner verify --verbose` and test installation/update on a real device. Keep all signing passwords out of command history and CI logs; use your CI secret manager.

The application ID is `app.moneywise.personal`. Confirm ownership/uniqueness before publishing; changing it later creates a different app. Increment the version/build number in pubspec.yaml for updates. The project name and icon are working branding rather than a trademark clearance.

## Device acceptance checklist
- Fresh install, opening balance, income/expense/transfer entry, editing, deleting and restart persistence.
- Small display, large text, keyboard open, rotation, talkback and dark-system setting behavior.
- Notifications: opt-in, supported app success alert, failed alert exclusion, repeat alert, cross-app duplicate review, process death, permission revocation and queue capacity.
- Budget overspend, overdue/completed goal, due day 31 in a short month, incomplete-month forecast warning and debt payment below interest.
- Offline startup, offline coach fallback, invalid Gemini API key, model refusal and network timeout.
- Backup export, validated restore, malformed restore preserving records, encrypted storage failure and deletion pausing capture.
- Signed APK installation and update over prior signed builds without data loss.

For your private installation, no hosting or Play submission is required. If publishing later, supply an appropriate privacy policy, complete Play Data Safety declarations and review Google's current policies.

Debug and production APKs normally have different signing certificates. Android will not install a differently signed release as an update over the debug app. Export a secure backup first, uninstall the debug app if necessary, install the production build, and restore the backup. Keep the production signing certificate consistent for future updates.
