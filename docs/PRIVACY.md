# Moneywise privacy design

Moneywise stores transactions, goals, budgets and settings in encrypted device storage. Notification candidates use Android Keystore encryption. Android backup is disabled, and screenshots are blocked on Android. Device compromise or an unlocked shared phone can still expose information; encryption does not replace a device lock.

Notification access is optional and technically grants broad access through Android. The service filters a specific set of bank/payment app package names before parsing. It does not upload notification bodies, read SMS, request bank login credentials or make payments. Only parsed candidate fields and recent event hashes are retained. The user reviews candidates before adding transactions.

Optional cloud coaching sends the user's question, category totals, budgets and goal names to their configured HTTPS backend and then Gemini. Users approve each request and should not include account numbers or other sensitive text. The AI provider and the operator of a deployed backend have their own terms and retention policies. Local deletion cannot delete records already held by them. The included backend deliberately does not log request bodies, tokens, keys or provider error bodies and does not persist financial summaries.

Backups are plaintext when copied to the clipboard, with explicit warning and consent. Other software may access clipboard contents. Store exports securely and clear the clipboard afterward. Uninstalling can permanently remove local records; keep backups if recovery is needed.

Delete-all removes the encrypted ledger, coaching configuration and pending capture queue and pauses capture. Android permission itself must be revoked in system settings; the app can open that settings page. External backups must be deleted separately. No analytics or advertising SDK is included.

This describes the source implementation, not a completed legal privacy policy for a public service. Add the operator's contact details, deployment-specific processors, retention, lawful requirements and store disclosures before public launch.
