# Version 1.0.1 validation

- Static analysis: no issues.
- Flutter tests: 30 passed, none skipped.
- Android debug APK build: passed; version 1.0.1 (2).
- APK signature: verified with debug certificate (not Google approval).
- Packaged manifest: no notification listener, notification binding permission, SMS, contacts, call logs, accessibility or overlay permissions. Declared uses-permissions are INTERNET and an app-internal signature permission.
- Automatic capture implementation and access settings removed; transactions are entered manually.
- APK SHA256: `72b9b2cdd59a3bd7e15cb309df063faac6f1d68152417137d3efdbd0fc6b5dcd`.
- Download ZIP: `Moneywise-Manual-1.0.1.zip`, 75,372,360 bytes; enclosed APK checksum verified unchanged.
- Play Protect assessment and installation on the owner's phone: not verified. Keep Play Protect enabled; do not override another block.
- Live Gemini and production signing: not verified/configured. This remains an evaluation build. No zero-risk or zero-bug guarantee is claimed.

Older notification-parser test results apply to the earlier build only; that feature and its native test sources were removed from this version.
