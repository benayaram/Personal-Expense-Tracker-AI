# Gemini, model selection and voice

1. Open Moneywise → Settings (gear) → Gemini API settings.
2. Enter your own key from Google AI Studio. The eye button shows/hides it; existing saved keys start hidden. Keys stay encrypted on this phone and are excluded from ledger backups.
3. Choose a preset or press **Load models from Google**. The latter fetches models supported by the key. Preset names are suggestions, not availability guarantees. Custom model names are also supported.
4. Save, open Coach, and type a question. The request includes recorded category/month totals, budgets, goals and history after your confirmation, directly to Google. No hosting is needed.
5. For voice, tap **Voice question**, read the speech-service disclosure, and choose whether to grant microphone permission. Review/edit the transcription, then separately press **Share summary and ask**. Dictation alone never submits financial data to Gemini.
6. Press **Read answer aloud** or **Listen to insights** for Android speech output. **Stop audio** stops playback. Local insights can be read without a Gemini key. Voice also stops when the app leaves the foreground.

Speech input/output depend on installed/enabled Android speech services and voice/language availability. Offline recognition is preferred but not guaranteed; the configured speech provider may process audio online. Moneywise does not save audio files or send raw audio to Gemini. Microphone denial or a missing service leaves typed questions available. Audio playback can be heard by people nearby.

A key can be shown, replaced or removed in Settings. Removing it disconnects Gemini without deleting finances. Model discovery and advice require internet; API access, quota and charges depend on your Google project. Use suitable Google restrictions and usage limits. Avoid secrets/account numbers in questions and goal/category names.

Automated tests use dummy keys and simulated speech/HTTP transports. Check a real request and speech input/output on your own phone before relying on them. Keep keys out of GitHub and chat; do not embed a shared paid key in a publicly distributed APK.
