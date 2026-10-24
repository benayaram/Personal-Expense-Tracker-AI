# Moneywise privacy design

Moneywise is a personal Android app. It has no hosted backend, login database, advertising SDK or analytics SDK. Transactions, goals, budgets, Gemini settings and the API key are stored encrypted on your phone. Android cloud backup and device-transfer backup are excluded, and Android screenshots are blocked. An unlocked or compromised phone can still expose information; use a device lock.

Version 1.0.1 does not declare a notification listener or provide notification-access settings. It cannot automatically read payment notifications. Transactions are entered manually, with editable category suggestions. No SMS, contacts, call-log, accessibility-service or overlay access is requested.

Gemini is optional. When you explicitly ask for coaching and approve sharing, your phone sends your question, category totals, budgets and goal names directly to Google Gemini over HTTPS. Merchant names, raw notification text and source identifiers are excluded. Questions and goal/category names can still contain personal information. Your Gemini API key goes only to Google's API in an HTTP header, never in a request URL or ledger backup. This app cannot control Google's processing or retention under your API account's terms.

Backups contain financial records as plaintext when explicitly copied to the clipboard. Other software may access the clipboard; save the backup securely and clear the clipboard. The Gemini key is excluded. Uninstalling or losing your phone may permanently remove local records, so keep your own backups.

Delete-all removes the ledger, settings, API key and legacy capture storage. External backups and information previously sent to Google are not removed by local deletion. Removing the key separately disconnects future Gemini calls without deleting your ledger.

This describes the implementation for personal use. If you later publish or operate a service for others, add operator contact details and deployment-specific legal/store disclosures and review the authentication design.
