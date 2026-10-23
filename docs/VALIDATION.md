# Validation evidence

The following checks were executed in the cloud environment on 23 October 2026:

| Check | Observed result |
| --- | --- |
| Flutter 3.47.7 / Dart 3.13.5 installation | Installed and version verified |
| Dependency resolution | Completed; pubspec.lock generated with package hashes |
| Static analysis with fatal infos | Passed, no issues |
| Flutter domain, persistence and widget tests | 23 passed, including small-screen/large-text navigation |
| Kotlin notification parser via standalone JUnit 4.13.2 | 5 passed |
| Node coaching server tests | 8 passed, with mocked Gemini transport |
| Gradle wrapper/distribution integrity | Verified against official SHA256 checksums |
| Android debug APK build | In progress; update this row with final observed outcome |
| Android Gradle unit suite | Pending Android build setup |
| Live Gemini call | Not run: no API key supplied |
| Physical-device notification capture and release installation | Not run: no attached physical device |
| Signed production build | Not run: release signing key not configured |

Tests validate specific behavior; they do not prove the absence of hidden bugs. See RELEASE.md for release gates. The optional server has not been deployed. No app store publication is implied.
