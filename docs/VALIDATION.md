# Validation evidence

Executed in the cloud environment on 23 October 2026 for the direct-Gemini version:

| Check | Observed result |
| --- | --- |
| Flutter 3.47.7 / Dart 3.13.5 | Installed and version verified |
| Full Temurin JDK 21.0.13 | Official release SHA256 verified; javac works |
| Frozen dependency resolution | Passed with committed pubspec.lock |
| Static analysis with fatal infos | Passed, no issues |
| Flutter domain, persistence, AI transport and widget tests | 30 passed; none skipped |
| Android Gradle parser suite | 5 passed; zero failures/errors/skipped in current XML result |
| Standalone Kotlin parser cross-check | Same 5 parser tests passed under JUnit |
| Android debug APK build | Passed; universal APK, version 1.0.0 (1), min SDK 24, target SDK 36 |
| APK signature | Verified; APK v2 signing, one debug signer |
| Packaged/merged manifest | Correct application ID and launch activity; protected notification listener, backup exclusions and no READ_SMS permission |
| APK source freshness | All current lib/*.dart sources predate this APK |
| Live Gemini call | Not run: owner has not entered a real API key |
| Physical-device notification capture and installation | Not run: adb reports no attached device |
| Signed production build | Not run: owner's production signing key not configured |
| Remote GitHub Actions result | Workflow configured; remote result not inspected |

APK: `build/app/outputs/flutter-apk/app-debug.apk` (178,944,733 bytes).

SHA256: `30dcfcfec2b3ec6079acfab47e8878c205beda8caf5b20dd282a96444b6928e5`

The app calls Gemini directly from the phone. No hosted backend or Render deployment is required. The owner enters/removes their own API key in Settings → Gemini API settings. Local tracking is independent of Gemini availability. Tests cover aggregate-only request payloads, key/header placement, quota/provider failures, timeouts, encrypted-storage integration boundaries, backup exclusion of keys and in-app key management. Mocked calls do not validate the owner's Google project or model availability.

The pinned Android build emits compatibility/deprecation warnings for legacy Kotlin/Gradle configuration, Java 8 settings in a dependency and SDK XML metadata. The current pinned toolchain builds and tests successfully; upgrading Gradle/Flutter or storage plugins requires a deliberate compatibility review.

This is an installable evaluation APK. Tests do not prove the absence of hidden bugs or replace real-device checks. See RELEASE.md for production signing and acceptance gates. No app-store publication is implied.

## Download package

The same verified APK is provided inside `downloads/Moneywise-Android.zip` for download from GitHub. The enclosed APK hash was checked against the APK checksum above after compression. No APK bytes or signatures were changed.

ZIP size: 75416325 bytes.

ZIP SHA256: `75aa501cb4acf91f1bf742645deaba0e5601ba22c1763ec8024396b3ebb0f1fb`
