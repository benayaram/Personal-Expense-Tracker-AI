# Optional private Gemini coaching server

Node 22 or later; no npm dependencies. Run tests with `node --test` in this directory. No real key is required for the mocked transport tests.

Configure these through your hosting secret manager, not chat or Git:

- `GEMINI_API_KEY`: your Gemini API key, limited to the required API where supported.
- `COACH_ACCESS_TOKEN`: a separate random access token of at least 32 characters. This is the token entered into the app.
- `GEMINI_MODEL`: defaults to `gemini-2.5-flash`; choose a model available to your project and verify its cost/availability.
- `HOST`: defaults to `127.0.0.1`; `PORT`: defaults to `8080`.

Start with `node index.mjs`. Put the server behind an HTTPS reverse proxy and configure its public HTTPS URL in the Android app. Do not expose the plain HTTP port to the Internet. The `/healthz` endpoint reports process health only; it does not validate your Gemini key or billing. The `POST /v1/coach` endpoint requires `Authorization: Bearer <COACH_ACCESS_TOKEN>` and application/json.

This is a private single-user service. It uses a shared access token, a 20-request/hour global in-memory quota, a 32KB body limit, a 20-second provider timeout and a 1,200-token output limit. Process restarts reset its quota. For a public multiuser app, first add user authentication, persistent per-user quotas, rotation/revocation, abuse protection, monitored deployment and a privacy/retention policy. Do not ship one shared server token in the APK.

The mobile app sends aggregates and your question after confirmation; no transaction merchants or raw notification text are sent. Goal names and free-text questions can still contain personal details. The server discards undeclared top-level/summary fields and never returns provider error bodies. Prompt instructions reduce inappropriate advice but cannot guarantee model correctness. All calculations displayed as accounting facts remain in deterministic application code.

Live Gemini validation requires a valid key, network permission to `generativelanguage.googleapis.com`, and an available model/project quota. Configure and smoke-test those in your deployment before advertising cloud AI as operational. The offline coach works without this service.
