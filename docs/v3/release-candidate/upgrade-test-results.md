## Upgrade test results (release-critical)
1. Published v1.0.0 artifact installed (versionCode 1, SHA-256 3A8662108A806BBE6F81A11B94107EE373929FDB86224279A64C37714CF3141F, signed with the same release keystore).
2. Representative data created: 1 session "Session 2026-10-22 11:54, 4 photos, 4 CUT".
3. Pre-upgrade state recorded: 1 album session.
4. V3 RC installed over v1.0.0 (install -r) -> Android accepted (Success).
5. Data survived: pre-existing session still listed post-upgrade.
6. Old session reopened in V3 editor ("Edit Session", layout 4 CUT) - legacy migration exercised.
7. New session created post-upgrade ("Session 2026-10-22 11:56") and saved; both coexist.
8. Export / Save to Photos / Save to album all still work post-upgrade.

RESULT: PASSED. No data loss, no signature mismatch, no versionCode rejection.
