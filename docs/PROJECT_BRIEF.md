# Moneywise 1.1 — project report

## Purpose and design
A private Android personal-finance companion for understanding spending, planning savings and obtaining practical advice. The requested UI reference guides a purple gradient balance header, white rounded cards, category-colored ring reports, savings progress cards, and a centered add action. All displayed financial figures derive from recorded data. Currency is INR; English is the initial interface language.

## Delivered feature mapping

| Requested capability | Implemented behavior |
| --- | --- |
| Smart expense tracking | Manual transaction CRUD with automatic merchant-rule category suggestions, category edits and custom categories. Saving immediately refreshes reports. No notification/SMS/bank capture. |
| Goal-based savings | Custom goals for home, travel, education or other purposes; target, saved amount, deadline, progress and required monthly contribution. |
| Income and budget management | Income/expense/transfer distinction, opening balance separated from income, monthly category limits, reserves, savings commitments and income-vs-expense reports. |
| Actionable insights | In-app budget warnings, category proportions, recorded prior-month comparisons, transparent forecast/what-if/debt calculators and Gemini suggestions based on financial aggregates. |
| Unified dashboard | Current tracked balance, estimated safe-to-spend, month selection, income/expense cards, recent entries and an insights shortcut. |
| AI text and audio | Editable text questions or explicit speech-to-text; summary-sharing confirmation; Gemini answer text; optional read-aloud and stop controls. |
| Key visibility and model choice | Encrypted personal key with show/hide, removal and replacement; model dropdown, authenticated Google model discovery, and custom model name. |

## Navigation and workflow
Home shows a unified overview. Report provides income/expense ring charts, month selection, category breakdown, prior-month comparison and searchable entries. My Plan puts visual savings goals first, followed by category budgets, opening balance, reserves, recurring bills and planning calculators. Coach provides local insights and optional direct Gemini questions. Settings are reached through the gear icon; the central add button creates a transaction or goal according to the current screen.

Set opening balance under Plan; record actual income and expenses; mark transfers between owned accounts as transfers. Review budgets and create goals. Open Coach to type or dictate a question, review it, approve sharing a summary, and read/listen to the answer. No transaction capture, API request or recording starts automatically.

## Accounting and data model
Amounts use integer paise. Decimal input and display avoid floating-point accounting. Safe-to-spend equals opening balance plus recorded income minus recorded expenses, reserved bills and planned savings. Transfers do not affect income/expense totals. Negative available funds remain visible. Reports filter by local calendar month; incomplete months and missing records must not be interpreted as complete bank data.

Goals are manually recorded and informational; they do not move funds or double-count against the ledger. Monthly contributions divide remaining target by remaining calendar months, with overdue goals using one month. Bill due dates clamp to the last valid day in short months. Forecasts repeat recorded monthly income and spending and explicitly assume no change. Savings scenarios assume no returns; debt estimates assume fixed interest and payments.

Ledger schema version 1 stores transactions, categories, budgets, goals, recurring bills, opening balance and reserves. Existing 1.0.1 records/backups remain compatible. The ledger is limited to 10 million JSON characters so valid records fit the restore flow. Backup export is explicit plaintext clipboard sharing; restore validates then replaces records after confirmation. API keys are stored separately and excluded.

## Architecture
Flutter Material 3 UI and presentation widgets use a shared observable store. Pure Dart domain logic performs calculations and validation. Flutter secure storage is configured for encrypted Android persistence. The Android activity provides only legacy capture-storage cleanup and a foreground voice method channel; the notification listener has been removed.

Android SpeechRecognizer requests RECORD_AUDIO only on explicit voice input and uses the device's configured speech service. The app prefers offline recognition, but a service can use its online provider. Transcripts are editable and never auto-submitted. Android TextToSpeech reads requested text, queues bounded chunks and supports stop. Recognition and playback stop when the app leaves the foreground. Recognition sessions are guarded against stale callbacks. No audio file is created by Moneywise.

The phone calls a fixed Google Gemini HTTPS endpoint directly. Keys go in headers, never URLs. Requests include the question, as-of date, incomplete-data notice, category totals, budgets, goals, safe-to-spend and six months of aggregated history. Merchant names, raw audio and source/account identifiers are excluded. Missing history is labeled as unrecorded data. A model list request sends only the key and pagination parameters to Google. There is no hosted backend or hosting-sleep dependency.

## Failure behavior
Invalid amounts and backups are rejected without replacing committed records. Storage errors do not silently reset the ledger; users can retry or explicitly restore/reset. Gemini quota/auth/model failures, empty responses and network timeouts preserve offline tracking and local insights. Model discovery failures leave preset/custom selection available. Missing speech services or microphone denial preserve typed input. A key can be removed without deleting finances.

## Privacy and device limitations
No SMS, contacts, call-log, notification-reading, accessibility-service or overlay access is requested. Microphone access is optional and foreground-only. Device backup/transfer rules exclude app data; screenshots are blocked on Android. Device compromise remains outside these guarantees. Users approve Google data sharing and must review the API plan's processing, retention and cost terms. Goal names, category names and questions may themselves contain personal details.

## Validation and release gates
See VALIDATION.md for executed checks, exact counts and APK integrity. Automated voice tests use a mocked platform channel; transport tests use a mocked HTTP client. Widget renders show fictional data. These do not establish actual speech recognition, audio playback, model availability or Play Protect approval on the owner's phone. Real-device checks, a live key/model request and production signing remain required before a production-readiness claim. Keep Play Protect enabled.

Later features may include reviewed automatic transaction sources, receipt OCR, multi-currency accounting, a transactional database for high-volume use, and scheduled OS reminders. Recurring bills currently provide in-app reminders. Direct personal-key use targets the owner's private installation; shared public paid access requires a new credential design.
