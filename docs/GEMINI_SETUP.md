# Gemini on your phone — no hosting required

1. Create your own Gemini API key through Google AI Studio and enable the relevant API/project access. Check model availability, quota and any billing requirements for your account/region.
2. Install Moneywise and open **Settings → Gemini API settings**.
3. Enter the key on the phone. Choose a Gemini model available to your project; the default is `gemini-2.5-flash`, which can be changed if unavailable.
4. Open Coach, write a question, and approve sharing the displayed financial summary. The phone sends that request directly over HTTPS to `generativelanguage.googleapis.com`.
5. Use Settings to replace or remove the key. A blank key field keeps the current key when editing the model; **Remove key** disconnects online coaching.

Notification capture and ledger updates never depend on AI calls, Render, or any other hosted server. If Gemini is unavailable, the app keeps tracking locally and shows local insights. API calls need internet and can encounter Google quotas, paid usage limits or model errors. A 25-second timeout prevents indefinite waiting.

The key is stored using encrypted device storage, not in Dart source, APK build flags or exported backups. Keep it out of GitHub and chat. Phone compromise can still expose local secrets; use a device lock and Google API restrictions/quotas where applicable. This design is for your own personal installation and key. Reconsider key distribution if you later publish the app for other users; never ship a shared paid key to everyone.

Only the question, category totals, budgets, goal names and calculated goal contributions are sent after confirmation. Merchant names, raw notifications and source/account identifiers are excluded. Avoid sensitive personal details in goal names or questions. Google processes submitted data under the terms applicable to your API plan; review those terms before sending financial information.

A real-key smoke test on your phone is still required. Automated transport tests use a dummy key and do not establish that your Google account has API access.
