# Moneywise

A simple Flutter Android expense tracker and savings companion for personal use. Local income/expense tracking, editable categories, reports, budgets, savings goals, recurring bill dates, planning calculators and Gemini coaching.

**No hosted server is required.** Your phone stores manually entered transactions locally. When you request AI advice, it calls Google Gemini directly using your own API key. Tracking and local insights work without internet or an API key.

**Permission update (1.0.1):** The notification listener and its settings are removed. Only normal internet access and an internal signature permission remain. Play Protect approval has not been verified on a phone; keep protection enabled.

**Release status:** evaluation build; see [validation evidence](docs/VALIDATION.md). Production signing and physical-device acceptance remain release gates. No zero-bug claim is made.

## Install on your phone

[Download the Android package](downloads/Moneywise-Manual-1.0.1.zip?raw=true) (about 75 MB). Extract the ZIP and open **Moneywise-Manual-1.0.1.apk**. See [download instructions](downloads/README.md).

## Documents

- [Project report and brief](docs/PROJECT_BRIEF.md)
- [Android setup, signing and installation](docs/RELEASE.md)
- [Gemini setup](docs/GEMINI_SETUP.md)
- [Privacy](docs/PRIVACY.md)

## Development

Use Flutter 3.47.7 stable, a full JDK 21 (including javac), and Android SDK API 36. Gradle installs the SDK/NDK/CMake versions needed by the pinned plugins. The Gradle wrapper/distribution and Dart dependencies have integrity checks.

```sh
flutter pub get --enforce-lockfile
flutter analyze --fatal-infos
flutter test
flutter build apk --debug
cd android
./gradlew testDebugUnitTest
```

The evaluation APK is `build/app/outputs/flutter-apk/app-debug.apk`. CI runs checks and uploads that APK after a successful build. Run `flutter run` with an attached Android device to develop interactively.

Set your opening balance under Plan; it does not count as income. Record income, expenses and transfers. Currency is INR. This version uses manual entry and does not request notification access. Automatic notification capture was removed after Play Protect blocked the earlier build.

For AI, open **Settings → Gemini API settings** and enter your key and an available Gemini model. The key is encrypted on your phone, excluded from ledger backups, and never embedded in this repository. You can replace or remove it in the same screen. Set appropriate API restrictions/usage limits in your Google project. Direct key use is intended for your personal installation; reassess authentication before distributing an app with shared paid access.

The earlier [UI concept board](docs/UI_CONCEPT.png) is design reference, not a screenshot of the implementation. The launcher icon and editable SVG are under `android/app/src/main/res` and `assets/branding`. App ID: `app.moneywise.personal`.
