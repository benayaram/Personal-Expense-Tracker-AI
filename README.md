# Moneywise

A simple Flutter Android expense tracker and savings companion. Local-first income/expense tracking, editable categories, notification review, reports, budgets, savings goals, recurring bill dates, planning calculators and optional private AI coaching.

**Status:** implementation under validation. Consult [validation evidence](docs/VALIDATION.md) before treating this as a release. No zero-bug or production-readiness claim is made.

## Project documents

- [Project brief and report](docs/PROJECT_BRIEF.md)
- [Android setup, signing and installation](docs/RELEASE.md)
- [AI server deployment](server/README.md)
- [Privacy](docs/PRIVACY.md)

## Development

Use Flutter 3.47.7 (stable), Java 21 and Android SDK API 36. The Gradle wrapper and distribution are checksum-pinned.

```sh
flutter pub get --enforce-lockfile
flutter analyze --fatal-infos
flutter test
flutter build apk --debug
cd android
./gradlew testDebugUnitTest
```

The debug APK is at `build/app/outputs/flutter-apk/app-debug.apk`. A debug build is for evaluation, not store distribution. CI runs the same checks and uploads the debug APK when successful. Node 22 tests need no packages or keys:

```sh
node --test server/index.test.mjs
```

Run `flutter run` with an attached Android device. All basic features work offline. Enable notification access only after reading the disclosure, then review candidates from the bell icon. Add an opening balance and record transfers as transfers. Currency is INR.

Configure optional coaching from Settings with the HTTPS address of your own deployed server and its access token. Do not put a Gemini provider key into Dart code or pass it through `--dart-define`; compiled mobile secrets are extractable. See the server guide.

The earlier [UI concept board](docs/UI_CONCEPT.png) is design reference; it is not a screenshot of the implemented app.

The app's launcher icon and editable SVG brand asset live under `android/app/src/main/res` and `assets/branding`. App ID: `app.moneywise.personal`.
