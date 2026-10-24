# Moneywise 1.1.0 validation

Executed on 24 October 2026 for version 1.1.0 (3):

| Check | Observed outcome |
| --- | --- |
| Flutter static analysis with fatal infos | Passed, no issues |
| Automated Flutter tests | 37 passed, none skipped |
| Financial and storage checks | Integer money, transfers, opening balance, budgets, goals, backup validation/recovery and key exclusion covered |
| Model discovery | Mocked HTTP: Google-only HTTPS routing, key in header, pagination, supported-model filtering and safe failure behavior |
| Key/model UI | Existing key hidden by default; explicit show/hide; dropdown persistence; key removal preserves records |
| Voice UI | Mocked native channel: no listening on startup, consent before dictation, editable transcript without auto-submit, denial/service fallback, read-aloud and stop |
| Small screen / enlarged text | Main tabs passed at 390×844 with 1.5 text scale; overflow found during development was corrected |
| Rendered UI review | Separate render check passed for Home, Report and Plan with fictional data; PNG previews in docs/ui |
| Android debug APK | Built successfully; version 1.1.0 (3), existing application ID |
| Signature | Verified APK v2 signature, debug signer |
| APK permissions | INTERNET, optional-use RECORD_AUDIO, internal signature permission only; no notification listener, SMS, contacts, call log, overlay or accessibility access |
| Source freshness | Current Dart and native voice sources predate the packaged APK |
| Download archive | Enclosed APK checksum matched original after compression |

APK SHA256: `00fca9b5c1b9cffc9be9c168dbfc4a5360ec4cade2dece4dec7d31ccb30dfcd3`

Archive: `Moneywise-1.1.0-Android.zip` (75,444,530 bytes).

## Checks not established

No physical Android device is attached. Real microphone permissions, recognition accuracy, installed speech/voice engines, actual audible playback, lifecycle behavior on device, Play Protect assessment and installation/update still require owner testing. Platform-channel mocks do not prove native audio works on the owner's phone. A real Google key/model/quota request was not run. Production signing is not configured; remote CI status was not inspected.

This remains an evaluation build, not a Google-approved or zero-bug release. Keep Play Protect enabled. The older no-microphone manual build remains available separately. Current pinned tooling builds, but emits legacy Kotlin/Gradle and dependency compatibility warnings; review compatibility before toolchain upgrades.
