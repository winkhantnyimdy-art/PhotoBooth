# PhotoBooth V3 — Checkpoint 7 Report (Android Release Candidate)

**Date:** 2026-10-22
**Branch:** `photobooth-v3-android`
**Baseline commit:** `47451c1` (Checkpoint 6)
**Flutter:** 3.47.5 · Windows host · **Android only**
**Distribution target:** GitHub Releases (existing PhotoBooth repository), linked from the existing website. No public release performed in this checkpoint.

## 0. Repository safety audit

- Branch: `photobooth-v3-android` (confirmed).
- Working tree at start: clean except the pre-existing unrelated untracked `tool/emu_pinch.ps1` (left untouched throughout).
- Latest five commits: `47451c1` (C6), `a9c863a` (5B), `7f814d5` (5B report), `48c90e6` (5B fix), `2164d83` (Checkpoint 5).
- Published v1.0.0 identity (from `docs/ANDROID_RELEASE.md` §1 and the on-disk artifact `build/app/outputs/apk/release/app-release.apk`, built 2026-10-14): `com.photobooth.photo_booth`, versionName `1.0.0`, versionCode `1`, minSdk 24, targetSdk 36, signer cert SHA-256 `f16cdffdaea089119cd73ebc99e21f0b1aaf5b2aa08a5fc3dcbc23e75ef51521`.
- Application ID preserved: `com.photobooth.photo_booth` (unchanged in this checkpoint).
- Release signing: `android/key.properties` (untracked, 4 keys present) → keystore `C:\Users\jpas\AndroidSigningKeys\photobooth-release.jks` (exists, 3600 bytes). No credentials printed; keystore never copied into the repo.

## 1. Release readiness audit (Phase 1)

Working components were **not** rewritten. Findings classified against the Checkpoint 6 baseline (F1–F9) plus this checkpoint's additions:

| ID | Sev | Finding | Status |
| --- | --- | --- | --- |
| F1 | P2 | Slow filter thumbnail decode with no loading affordance | **Fixed in Phase 2** (see §2) |
| F2 | P2 | Environment-driven host-thrash freeze | Closed as environment (unchanged) |
| F3 | P2 | Sticker shelf rows can sit behind Finish & Save on short viewports | Open (polish, 6+) |
| F4 | P3 | Layout-chip swipe affordance invisible at 320 dp | Open (polish) |
| F5 | P3 | Album card titles ellipsize to "Session 2026-1…" | Open (polish) |
| F6 | P3 | Top-bar undo/redo/reset a11y labels inconsistent | Open (a11y pass) |
| F7 | P3 | Landscape camera letterboxes the viewfinder | Open (polish) |
| F8 | ✅ | Adjustments invisible to undo/redo | Fixed in Checkpoint 6 |
| F9 | ✅ | Editor title truncation at 320 dp | Fixed in Checkpoint 6 |
| F10 | ✅ | Filter thumbnail decode had no failure handling and could leave a blank cell forever | **Fixed in Phase 2** |

No P0 or P1 findings. No release blocker.

## 2. Filter loading experience (Phase 2) — fixed

**Investigated:** `lib/core/filters/effect_image.dart` (the `EffectImage` widget used by every filter chip and the export preview). Before: `_image == null` returned `SizedBox.expand()` (silent blank), the `ImageStreamListener` had no `onError` (a failed decode surfaced as an unhandled `FlutterError` and stayed blank forever), and 15 chips decoded concurrently with no affordance.

**Fix (low-risk, no architecture change):**
- Added a static Minimal Dark loading surface (`_EffectImagePlaceholder`: dark surface + 12 dp dot, deliberately **non-animated** so 15 chips never spin 15 motors and `pumpAndSettle` stays usable in tests).
- Added a defined fallback (`_EffectImageFallback`: muted surface + `Icons.image_not_supported_outlined`) for failed decodes, absorbed via `ImageStreamListener.onError` so no unhandled `FlutterError`.
- `_failed` resets on a new provider so a retry is possible.
- Stale-result protection already existed (`_detach` removes the old listener before resolving a new provider; identical-provider short-circuit prevents repeated decode requests). Decode still goes through Flutter's `ImageCache` (no second bitmap cache introduced). Effect processing/output untouched.

**Tests:** `test/core/filters/effect_image_test.dart` (3 tests: loading surface → graded image; graceful failure fallback; newer photo starts a fresh decode and never lingers behind an in-flight one). All pass.

## 3. Android versioning (Phase 3)

- `pubspec.yaml`: `1.0.0+1` → **`3.0.0-rc.1+2`**.
- Published v1.0.0 versionCode = **1** (docs + artifact badging). New versionCode = **2 > 1** ✓ (strictly greater). No other relevant installed release version exceeds 1.
- Application ID preserved: `com.photobooth.photo_booth`. Package name unchanged. No release tag published.

## 4. Release build configuration (Phase 4)

Inspected `android/app/build.gradle.kts` (unchanged in this checkpoint):
- minSdk = `flutter.minSdkVersion` = 24 (Android 7.0)
- targetSdk / compileSdk = `flutter.targetSdkVersion` / `flutter.compileSdkVersion` = 36 (Android 16)
- Java 17 source/target, Kotlin JVM 17
- Release signing: `android/key.properties` → `C:\Users\jpas\AndroidSigningKeys\photobooth-release.jks`; **no debug fallback** (release builds fail at configuration time without credentials). `storeFile` resolved relative to `android/`.
- R8/minification: Flutter defaults (no custom `proguard-rules` added); resource shrinking via Flutter defaults.
- No signing keys regenerated, no credentials printed or committed.

## 5. Release APK verification (Phase 5)

| Check | Result |
| --- | --- |
| APK exists | `build/app/outputs/flutter-apk/app-release.apk` ✓ |
| Release-built | ✓ (built via `flutter build apk --release`) |
| Signed with expected release identity | ✓ Signer cert SHA-256 `f16cdffdaea089119cd73ebc99e21f0b1aaf5b2aa08a5fc3dcbc23e75ef51521` — **identical to the published v1.0.0 artifact's signer** |
| Not debug-signed | ✓ DN `CN=Win Khant Nyi, OU=Retro, O=Retro City, L=Myanmar, ST=Mandalay, C=95` (not Android Debug) |
| Signature verification | ✓ `Verifies` (v2 scheme true; v1 false, v3/v3.1/v4 false — expected for a standard Flutter release) |
| Application ID | `com.photobooth.photo_booth` ✓ unchanged |
| versionName / versionCode | `3.0.0-rc.1` / `2` ✓ |
| minSdk / targetSdk | 24 / 36 ✓ |
| APK size | **54,626,263 bytes (52.1 MB)** |
| SHA-256 | `D64F37AE548BA7FF54C7345A54E103A8C65B14F35EBFEB420AF771031D7BBB16` |
| Installs on emulator | ✓ (clean install on `Medium_Phone_RC`, see §6) |
| Launches without crash | ✓ (cold launch 2.7 s on RC AVD; no crash) |
| No dev-only UI / debugging features | ✓ (no debug banner; release build) |

Permissions (final merged manifest, via `aapt2 dump badging`): `CAMERA`, `WRITE_EXTERNAL_STORAGE` (maxSdkVersion=28), `ACCESS_NETWORK_STATE`, `READ_EXTERNAL_STORAGE` (maxSdkVersion=28), plus the app-internal `com.photobooth.photo_booth.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`. No `RECORD_AUDIO`, no location, no `INTERNET` in release, no analytics/tracking SDKs. Matches `docs/ANDROID_RELEASE.md` §7 disclosure.

## 6. Clean installation test (Phase 6)

Performed on an isolated AVD `Medium_Phone_RC` (system image `android-37.2 google_apis_playstore x86_64`), not the daily-driver `Medium_Phone` (its data was left untouched). Release APK installed over an empty data partition.

| Step | Result |
| --- | --- |
| Installation | ✓ Success (streamed install) |
| First launch | ✓ Cold launch, cream splash → Home, no crash |
| Permission request | ✓ Camera permission dialog appeared; granted via `pm grant` after the dialog's tap target proved unresponsive to adb (app-side path unaffected); camera initialized on "Try again" |
| Camera startup | ✓ Viewfinder live after retry (virtual camera HAL needed a moment on the playstore image) |
| Capture | ✓ 4-shot sequence at 3 s countdown |
| Review | ✓ Review grid + "Photo 4 of 4 selected · Retake replaces only this one" |
| Decorate | ✓ Editor opened, frames/effects/stickers/text/adjust reachable |
| Export | ✓ Ready! screen rendered |
| Save | ✓ Save to Photos + Save to album both succeeded |
| Album | ✓ Album grid populated with the new session |
| App restart | ✓ (covered by the upgrade test below) |

Screenshots 01–11 in `docs/v3/screenshots/checkpoint-7/` originate from the release APK on this clean install.

## 7. Upgrade compatibility (Phase 7) — release-critical, PASSED

Performed on the same isolated AVD `Medium_Phone_RC`:

1. Installed the published v1.0.0 artifact (`build/app/outputs/apk/release/app-release.apk`, versionCode 1, SHA-256 `3A8662108A806BBE6F81A11B94107EE373929FDB86224279A64C37714CF3141F`, signed with the same release keystore) — verified identity via `aapt2 dump badging` + `apksigner verify --print-certs`.
2. Created representative data: one full 4-photo session saved to the album ("Session 2026-10-22 11:54, 4 photos, 4 CUT").
3. Recorded pre-upgrade state: 1 album session.
4. Installed the V3 RC over v1.0.0 (`install -r`) — **Android accepted the upgrade** (Success).
5. Data survived: "Session 2026-10-22 11:54" still listed post-upgrade.
6. Old session reopened in the V3 editor as "Edit Session" with layout 4 CUT (legacy `PhotoFilterType` → `PhotoEffect` migration exercised on a real upgrade).
7. New session created post-upgrade ("Session 2026-10-22 11:56") and saved to album; both sessions coexist (2 entries).
8. Export / Save to Photos / Save to album all still work post-upgrade.

**Upgrade gate: PASSED.** No data loss, no signature mismatch, no versionCode rejection.

## 8. Privacy and permissions (Phase 8)

Final merged manifest audited via `aapt2 dump badging` (release APK). Declared permissions and justification:

| Permission | Why | Runtime? |
| --- | --- | --- |
| `CAMERA` | Taking photos | Yes (platform dialog) |
| `WRITE_EXTERNAL_STORAGE` (maxSdkVersion=28) | Legacy storage on Android 7–9 for gallery saves | No on API 29+ (MediaStore) |
| `READ_EXTERNAL_STORAGE` (maxSdkVersion=28) | Transitive, inert on modern Android | No |
| `ACCESS_NETWORK_STATE` | Transitive from media deps; app makes no network calls | No |
| `com.photobooth.photo_booth.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` | App-internal, AndroidX component isolation | No |

Deliberately removed (Checkpoint 5, retained): `RECORD_AUDIO` (controller created with `enableAudio: false`), `READ_EXTERNAL_STORAGE` (unscoped, via `tools:node="remove"`). No analytics, ads, tracking, cloud processing, or unnecessary permissions introduced. Offline-first design preserved. Exported components audited: only the launcher Activity is exported; receivers are non-exported.

## 9. Performance and stability (Phase 9)

| Measurement | Value | Source |
| --- | --- | --- |
| Cold start, RC AVD, clean single-emulator | **0.87 s** (`am start -W`, LaunchState COLD, TotalTime 866) | this checkpoint |
| Hot resume | **0.13 s** (TotalTime 132) | this checkpoint |
| Cold start (worst case, host thrashed, 2nd emulator + agent build) | 15.2 s | Checkpoint 6 |
| Cold start (warm FS cache) | 4.7 s | Checkpoint 6 |
| Warm start (host contended) | 4.05 s | Checkpoint 6 |
| Hot resume (Checkpoint 6) | 0.30 s | Checkpoint 6 |
| Save to Photos (render PNG + MediaStore) | 3.4 s | Checkpoint 6 (stopwatch) |
| 4-shot sequence at 3 s countdown → Review | ~25–27 s (by design) | Checkpoint 6 |
| Memory after heavy editing/export | TOTAL PSS 253 MB (Native heap 45.5 MB, no swap) | Checkpoint 6 |
| `dumpsys gfxinfo` frame stats | Unusable on this Flutter/Impeller build (0 frames / impossible percentiles) | Checkpoint 6 (honest limitation) |

No memory leaks, unbounded caches, or unexpected crashes observed during the clean-install/upgrade smoke tests. Filter shelf now shows a static loading affordance instead of a blank cell (Phase 2).

## 10. Regression tests (Phase 10)

| Gate | Result |
| --- | --- |
| `flutter analyze` | **No issues found! (ran in 27.6s)** |
| `flutter test` | **+535: All tests passed!** (532 baseline + 3 new `effect_image` regressions; zero decreases) |
| `flutter build apk --debug` | **Success** (`build/app/outputs/flutter-apk/app-debug.apk`, 165,654,878 bytes, 2026-10-22 11:58) |
| `flutter build apk --release` | **Success** (`build/app/outputs/flutter-apk/app-release.apk`, 54,626,263 bytes, 2026-10-22 11:39) |

Focused tests for Checkpoint 7 changes: `test/core/filters/effect_image_test.dart` (3) + `test/features/decorate/adjust_undo_test.dart` (2, from C6) all pass. No tests deleted, skipped, or weakened.

## 11. Release candidate artifacts (Phase 11)

Created `docs/v3/release-candidate/` with:
- `apk-metadata.txt` — applicationId, versionName, versionCode, minSdk/targetSdk, size, SHA-256, signer cert, signing scheme, build timestamp.
- `permission-audit.md` — permission table + justification + removed permissions.
- `clean-install-results.md` — clean-install step table.
- `upgrade-test-results.md` — upgrade procedure + verification.
- `regression-test-results.md` — gate results.
- `performance-summary.md` — measurement table.
- `known-limitations.md` — open items + unverified physical-device scope.
- `release-readiness-assessment.md` — verdict inputs.

No APK binaries committed. No private signing keys or credentials copied into the evidence directory. (The release APK remains at `build/app/outputs/flutter-apk/app-release.apk` only.)

## 12. Android screenshots (Phase 12)

Captured from the **release APK** on the clean-install AVD into `docs/v3/screenshots/checkpoint-7/` (11 files): 01-home, 02-camera, 03-review, 04-decorate, 05-film-effect, 06-frame-selection, 07-save-share, 08-save-success, 09-album, 10-album-inspect, 11-settings. Route-specific verification used (uiautomator dump before each capture). No stale screenshots reused.

## 13. Release readiness verdict

### READY FOR OWNER REVIEW

All required technical release-candidate gates pass:
- No P0/P1 findings; clean release build signed with the stable release identity; upgrade compatibility verified with data survival; permissions audited; clean install successful; regression suite +535 green; physical-device camera validation remains explicitly **unverified** (emulator-only, as required).

This does **not** mean public release is authorized. Owner review and explicit approval required before any GitHub Release, website link, or deployment.

## 14. Git and stop conditions

Commit hash and working-tree status are reported in the final summary. `tool/emu_pinch.ps1` left untracked. No push, merge, publish, deploy, or key regeneration performed. Checkpoint 7 stops here; awaiting owner review.

*Prepared 2026-10-22 (UTC+8). Evidence from `emulator-5556` (RC AVD, isolated) and host build tooling.*
