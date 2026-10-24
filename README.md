# Moneywise 1.1

Personal Android finance tracking with a purple dashboard, circular reports, visual savings goals and a Gemini coach with text and voice controls. No hosted backend is required.

[Download Moneywise 1.1.0](downloads/Moneywise-1.1.0-Android.zip?raw=true) · [Install instructions](downloads/README.md) · [Project report](docs/PROJECT_BRIEF.md) · [Validation](docs/VALIDATION.md)

## What you can do

- Record income, expenses and transfers. Merchant rules suggest editable categories; custom categories are supported. Reports update immediately after a save.
- View tracked balance, estimated safe-to-spend, monthly income/expenses and recent transactions in one dashboard.
- Compare income and expenses, browse circular category reports, and inspect recorded prior-month trends.
- Set category budgets, see in-app overspending alerts, and plan savings goals with progress, deadlines and monthly contributions.
- Ask Gemini questions based on recorded financial summaries, budgets, goals and six months of aggregated history. Type a question or dictate it, review the text, then explicitly send it.
- Listen to local insights or Gemini answers using Android text-to-speech; stop playback at any time.
- Show/hide your encrypted personal API key; select a preset, load compatible models from Google, or enter a custom model.

Transactions are entered manually. Notification reading, SMS access and automatic bank syncing remain disabled after the earlier Play Protect block. **Voice input requests ordinary microphone permission only when you choose it.** Voice recognition and synthesis depend on speech services installed on your phone and may use their online services. All essential tracking works with voice permission denied.

## Interface previews

These are widget-rendered previews of the implementation using explicitly fictional sample records, not physical-device screenshots.

[Home](docs/ui/home.png) · [Report](docs/ui/report.png) · [My Plan](docs/ui/plan.png)

## Gemini and privacy

Settings → Gemini API settings lets you show/hide, replace or remove your key and choose a model. **Load models from Google** uses your key to fetch models that advertise content generation; preset names alone do not establish availability. Review transcription before sending a question. Financial summaries go directly to Google only after confirmation. No raw audio, merchants or account/source identifiers are sent to Gemini. Keys stay encrypted on your phone and are excluded from financial backups. Configure Google API restrictions and usage limits for your account.

[Gemini and voice setup](docs/GEMINI_SETUP.md) · [Privacy](docs/PRIVACY.md) · [Release guide](docs/RELEASE.md) · [Fictional restore data](examples/README.md)

## Development

Flutter 3.47.7 stable, full JDK 21, Android SDK 36 and the SDK/NDK/CMake dependencies selected by the lockfile/toolchain.

```sh
flutter pub get --enforce-lockfile
flutter analyze --fatal-infos
flutter test
flutter build apk --debug
```

The universal evaluation APK is `build/app/outputs/flutter-apk/app-debug.apk`. Run `flutter run` with an attached Android device. App ID remains `app.moneywise.personal`; ledger format stays compatible with version 1.0.1 and its sample backups. Export your real records before an update.

This is a debug-signed evaluation build. Real-device microphone, speech-engine, Gemini and Play Protect checks remain necessary. Keep Play Protect enabled; do not override another installation block. Passing tests and signature verification are not Google approval or a zero-bug guarantee. Production signing is not configured. The prior [manual-only 1.0.1 download](downloads/Moneywise-Manual-1.0.1.zip?raw=true) remains available without microphone access.
