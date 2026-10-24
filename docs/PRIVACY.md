# Moneywise 1.1 privacy

Moneywise stores the ledger and settings encrypted on your Android phone. It has no hosted backend, account database, advertising SDK or analytics SDK. Android cloud backup and device-transfer rules exclude app data; Android screenshots are blocked. Use a device lock; an unlocked or compromised phone can still expose information.

The notification listener remains removed. The app cannot automatically read bank/payment notifications or SMS. It does not request contacts, call logs, accessibility, overlay or notification-reading access. Transaction entry is manual, with editable merchant-rule category suggestions.

Optional voice input requests ordinary RECORD_AUDIO permission only when you explicitly choose Voice question. Android's configured speech service handles recognition and may use its online provider despite the offline preference. The transcript fills an editable question; it is not auto-submitted. Moneywise does not create audio files or continuously record. Recognition stops on cancel, timeout or leaving the foreground.

Optional output uses Android TextToSpeech and the device's installed voice engine, which may require downloaded voices or its online provider. It reads only the text you request, supports stop and stops on backgrounding. Playback can be heard nearby.

After confirmation, Gemini requests send the question and recorded financial aggregates, budgets and goal names directly to Google over HTTPS. Raw audio, merchants, source IDs and account identifiers are excluded. Questions/goal/category names can still contain personal details. Google processing and retention follow your API account's terms. The key is carried in a Google API header, never a URL, and is encrypted locally. The eye button reveals it only at your request. Loading models sends the key to Google's model-list endpoint but no financial summary.

Backups exclude the API key. Clipboard exports are plaintext after explicit consent; save them securely and clear the clipboard. Restore replaces records after validation and confirmation. Uninstall/device loss may remove records permanently. Existing schema-1 backups remain supported.

Delete-all removes ledger, settings, key and legacy capture storage. External backups and information already processed by Google or a speech provider are not deleted by local reset. Removing only the key preserves finances. Review the provider terms and consider the risks before sending personal information.

This is a personal-use evaluation app. Public distribution requires appropriate operator/store disclosures and a review of credential handling. Tests/signatures do not guarantee device safety or Google Play Protect approval. Keep Play Protect enabled.
