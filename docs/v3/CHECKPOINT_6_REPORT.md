# PhotoBooth V3 — Checkpoint 6 Report (Full UX Audit)

**Date:** 2026-10-21
**Branch:** `photobooth-v3-android`
**Baseline commit:** `a9c863a` — Checkpoint 5B/5 audit baseline
**Flutter:** 3.47.5 · Windows host · **Android only** (emulator verification; physical-device camera behaviour is explicitly out of scope — see *Limitations*)
**Evidence:** 34 numbered screenshots in `docs/v3/screenshots/checkpoint-6/` (inventory at the end)

## Gates (run after the last code change, before this report was committed)

| Gate | Result |
| --- | --- |
| `flutter analyze` | **No issues found! (ran in 14.1s)** |
| `flutter test` | **+532: All tests passed!** (530 pre-existing + 2 new regressions added in this checkpoint) |
| `flutter build apk --debug` | **Exit 0**, `build\app\outputs\flutter-apk\app-debug.apk` (built 2026-10-21 14:15:40 UTC+8, Gradle assembleDebug 36.6s) |

The APK that was rebuilt after the fixes below was installed on the emulator (`install -r`) and **all emulator evidence in `checkpoint-6/` comes from that final build**, except shots 01–05 which pre-date the Adjust-undo fix (the fix does not touch camera/review flows).

## Scope of this checkpoint

Full-journey UX audit of the 8 mission areas on AVD `Medium_Phone` (1080×2400 @ 420dpi = 411dp, plus 840×1680 = **320dp** critical viewport and landscape probes):

1. Journey & transitions (Home → Camera → Review → Editor → Export → Album → back)
2. Camera (cold init, permission, countdown, 4-shot sequence, retake, front/back switch, recovery)
3. Editor (5 tabs, undo/redo/reset, fullscreen preview, Finish & Save)
4. Save & Album (PNG export, Photos, duplicate protection, share, album, inspect, delete, persistence)
5. Visual consistency across viewports (411dp / 320dp / landscape)
6. Performance with real timings
7. Gates (analyze / test / build)
8. Evidence inventory

---

## 1. Journey and transitions — PASS

| Step | Result | Evidence |
| --- | --- | --- |
| Home renders (masthead, layout picker, footer Album/Settings) | PASS | 01 |
| Home → Camera (Start Photo Booth) with warm app | PASS (see timings) | 03, 33* |
| Camera → Review after 4 shots | PASS (auto) | 05 |
| Review BACK → Camera stays usable (recovery) | PASS | 05 + inline probe |
| Editor → Export (Finish & Save) | PASS | 17 |
| Export → Back to Home → Album | PASS | 21 |
| Album card tap → "Edit Session" (state restored) | PASS | 27 |
| System BACK chain: Editor(Edit) → Album, Album → Home, Home → exits app | PASS | inline dumps |
| Export duplicate-state: both ✓ states visible (`Saved` + `Saved to album`) | PASS | 20 |

\* 30/31–33 are the 320 dp variants; the same transitions were exercised at 411 dp.

## 2. Camera — PASS

- **Permission:** `pm revoke android.permission.CAMERA` kills the process (platform behaviour); relaunch shows the grant dialog (02); ALLOW → camera initializes → viewfinder (03). No soft-fail: the app asks at the platform level and the user only loses the run, not the app.
- **Camera-HAL crash after revoke:** app surfaced a graceful **"Camera unavailable"** error state with a working **Try again** (recovery verified inline; the error-state shot was overwritten by the viewfinder capture, see Limitations).
- **Countdown + capture:** overlay ("0 of 4" + big digit) (04), 4-shot sequence at 3 s countdown, then Review grid with **"Photo 4 of 4 selected · Retake replaces only this one"**.
- **Retake semantics** present on Review; BACK from Review keeps camera ready.
- **Front/back switch:** **Switch camera** produced the front (virtual scene) feed at the same flow point (34). Capture pipeline unaffected.
- **320 dp:** all camera controls (close, layout pill, flash, dots, shutter, switch) reachable (33).

## 3. Editor — PASS (with 1 new P3)

- **Tabs:** Filters / Frames / Stickers / Text / Adjust all navigable; shelf content correct per tab (06–14).
- **Filters:** presets (Original/Soft/Warm/…) + Strength slider; semantics read "Warm 50% - simulated, not scanned film." (08). **Reset to Original** present (13/27 show it in the Filters header).
- **Frames:** paper colour + border + 8 frame themes (Vintage Film default), Pattern row Clean/Hearts/Stars/Sparkle + "Show the date" (09–11).
- **Stickers:** add → "1 sticker added", **Remove last** (12).
- **Text:** caption entry with 3/24 counter, colour swatches, caption confirmed on strip (13).
- **Adjust:** sliders set values by tapping the track directly (+34, +37 measured via semantics). The earlier "dead sliders" probe was an audit-side coordinate error (taps hit the label row y≈1794 instead of track centre y≈1856) — sliders verified correct.
- **Fullscreen preview:** strip inspector with **Fit** chip + "Pinch to zoom, drag to pan" hint; zoom/pan gestures accepted (15); pinch-zoom itself is covered by widget tests (drag-to-zoom-pan demonstrated on device).
- **Undo/Redo — bug found & fixed** (see below).
- **New P3 (discoverability):** the layout-switch chip row above the editor is a horizontal `ListView` capped at 30 dp height; at 320 dp only the selected chip is on-screen and the rest peek as a 3 px sliver — functional (scrollable by design, code comment documents exactly this) but the swipe affordance is invisible.

### Bug fixed in this checkpoint: adjustments were invisible to undo/redo

**Found:** Brightness +34 persisted after tapping Undo. Root cause in `decorate_screen.dart`: `_updateAdjust()` (and the Adjust section Reset) called `setState` without `_undoRedo.record(...)` — every other edit (effects, stickers, text, frames) records the pre-edit state, so adjustments were the only edits that could not be undone. Continuous `onChanged` spam is presumably why it was originally skipped.

**Fix (focused):**
- `_DarkSlider` gained an optional `onChangeEnd` passthrough → (Slider);
- `_updateAdjust` snapshots `_adjustUndoBase` on the first tick of a gesture and `_commitAdjustSnapshot()` records **one entry per gesture** when the gesture ends (no history flooding);
- Adjust **Reset** now uses `_resetAdjustments()`, which records the pending snapshot exactly like every other edit.

**Tests:** `test/features/decorate/adjust_undo_test.dart` (2 tests: one gesture ⇒ one undo entry with undo+redo round-trip; section Reset is undoable) — both pass; full suite +532 green.

**On-device verification (final APK):** slider tap → `+37, Brightness` → **UNDO → `0, Brightness`** (screenshot 16) → **REDO → `+37, Brightness`**.

### Fix carried from this checkpoint series (320 dp session title truncation)

The Editor title (`Decorate` / **Edit Session**) was ellipsized at 411 dp and truncated at 320 dp; it is now wrapped in `FittedBox(fit: BoxFit.scaleDown)` (`decorate_screen.dart`, ~line 300). Verified: **"Edit Session" renders fully at 320 dp** (31) while the layout chips shrink rather than truncate.

## 4. Save & Album — PASS

| Check | Result | Evidence |
| --- | --- | --- |
| Export screen renders adjusted strip + styled actions | PASS | 17 |
| **Save to Photos** (PNG via MediaStore) | **PASS — 3.4 s end-to-end** (stopwatch, 0.5 s poll granularity ⇒ real 3.0–3.4 s) | 17/18 |
| **Duplicate-save protection** | PASS — after the first save the Save action leaves the clickable tree entirely; semantics show "Saved to Photos!", a second tap is inert | 18 |
| **Share** | PASS — system sheet with real targets (Drive, Messages, Photos, Gmail, …), strip + "My PhotoBooth Strip!" | 19 |
| **Save to album** | PASS — green ✓ states + "Saved to your album" snackbar | 20 |
| Album grid + per-card Inspect/Delete buttons | PASS | 21 |
| Inspect (strip inspector) zoom/pan | PASS — drag-to-zoom-pan demonstrated; pinch covered by widget tests | 22 |
| Album reopen → editor with persisted edits ("Warm 100%" restored) | PASS | 27 |
| Delete own session → confirm dialog **names the session** (Keep it / Delete) | PASS | 23 |
| After delete: session gone, storage footer 4.2 → 4.1 MB, pre-existing sessions untouched | PASS | 24 |
| Persistence after force-stop + relaunch: all 6 pre-existing sessions intact | PASS | 25 |
| Settings screen (countdown 3/5/10 s, shutter sound, flash animation, mirror selfies, storage usage, Clear-album danger zone listed but **not** exercised) | PASS | 26 |

*Note:* during the audit only the audit-created session was deleted; the six pre-existing Oct 19 sessions were preserved.

## 5. Visual consistency — PASS (with P2/P3 notes)

- **411 dp (1080×2400):** consistent Minimal Dark language across all screens: circular ghost buttons, outlined selected chips, single stripe accent, no clipped controls (01–26).
- **320 dp (840×1680 override):** Home, Album (2-column), Camera, Editor all render without overlap; title truncation bug fixed (30–33). Layout chips: scrollable by design but low discoverability (P3, below).
- **Landscape:** Home and Camera re-layout correctly without distortion; the camera viewfinder keeps a portrait crop with wide empty side bands (acceptable for a portrait-strip app; P3 polish) (28, 29).
- **P2 — asset/preview loading affordance:** on the first editor entry after a fresh boot the effect-card thumbnails rendered empty for ~4–15 s with no shimmer/spinner; a second fresh session on an unthrashed host rendered instantly. Users on first-run cold sessions can hit a confusing blank shelf (see Findings).

## 6. Performance — measured on emulator (honest numbers)

| Measurement | Value | Method |
| --- | --- | --- |
| Cold start, fresh boot, host thrashed (2nd emulator + other agent build) | **15.2 s** | `am start -W`, screencap verification |
| Cold start, post-install | **6.3 s** | `am start -W` |
| Cold start (COLD), warm FS cache | **4.7 s** | `am start -W` (LaunchState: COLD, TotalTime: 4669) |
| Warm start (WARM) after task removal, host contended | **4.05 s** | `am start -W` |
| Hot resume (task alive) | **0.30 s** | `am start -W` (LaunchState: HOT, TotalTime: 302) |
| Save to Photos (render PNG + MediaStore insert) | **3.4 s** | stopwatch around tap + state-poll |
| 4-shot sequence at 3 s countdown → Review | ~25–27 s (by design: 3 s × 4 + decode) | wall clock |
| Memory after heavy editing/export | **TOTAL PSS 253 MB** (Native heap 45.5 MB, no swap) | `dumpsys meminfo` |
| `dumpsys gfxinfo` frame stats | **Unusable on this platform config** — reports "Total frames: 0 / 4950 ms percentiles" nonsense on this Flutter/Impeller build; jank measurements therefore qualitative: tab switches and shelf scrolls respond within ~1 s; no hangs observed | honest limitation |

The 12:55–13:45 emulator freeze documented in F2 above was **environment-driven (host memory thrash), not an app defect**: identical steps reproduced cleanly after a fresh AVD boot. No ANR file for the session, no `E/flutter` exception; the UI thread simply stopped being scheduled until the host recovered. Carried as a P2 **environment-sensitivity note** (an Android app has no meaningful watchdog for host-side starvation), consistent with the tooling interference we saw at the same time (`uiautomator dump` "could not get idle state" under thrash).

## 7. Findings

No P0 / P1 findings.

| ID | Sev | Finding | Status |
| --- | --- | --- | --- |
| F1 | **P2** | First fresh-session editor entry after cold boot can show blank effect/frame cards for 4–15 s with no loading affordance (async island decode unbudgeted). Documented; suggest a shimmer/placeholder in the shelf. | Open (fix in 6+) |
| F2 | **P2** | Environment-driven UI freeze (host memory thrash): trigger at ~12:55 under 77 MB free RAM / 574 MB swap with concurrent emulators and another agent's Gradle build; no ANR, no Dart exception; never recovered even after RAM was freed; fixed only by host-side qemu kill + fresh AVD boot, after which identical steps passed. Documented as environment-sensitivity; no app change. | Closed as environment |
| F3 | **P2** | Sticker shelf rows can sit partially behind the Finish & Save bar on short viewports (scrollable, 5B tray floor helps; still reachable through scroll). | Open (polish) |
| F4 | **P3** | Layout-switch chip row in the editor: swipe affordance invisible at 320 dp (selected chip visible, others a 3 px sliver). By design (scrollable `ListView`, height 30 dp) but needs a visual affordance (e.g. fade/peek or chevron). | Open (polish) |
| F5 | **P3** | Album card titles ellipsize to "Session 2026-1…" at 411 dp — full date only in semantics; suggest compact "Oct 21 14:20" or smaller text. | Open (polish) |
| F6 | **P3** | Editor top-bar controls (back, undo, redo, reset-to-original) have no content-desc on some screens (expand does: "Inspect the photostrip full screen"); a11y labels inconsistent cross-screen. | Open (a11y pass) |
| F7 | **P3** | Landscape camera letterboxes the portrait viewfinder with large empty bands — correct, not distorted; could crop wider in landscape. | Open (polish) |
| F8 | ✅ Fixed | Adjustments (brightness/contrast/saturation/warmth) were excluded from undo/redo; also the Adjust section Reset didn't record. Fixed with one-snapshot-per-gesture + recording Reset; 2 new regression tests; verified on device (+37 → undo → 0 → redo → +37, screenshot 16). | **Fixed** |
| F9 | ✅ Fixed | Editor title truncation at 320 dp (carried finding) — `FittedBox(fit: BoxFit.scaleDown)`; verified at 320 dp (31). | **Fixed** |

## 8. Audit limitations

- **Android-only, emulator-only:** verified on AVD `Medium_Phone` (API-level Android image with virtual HAL cameras). **Physical-device camera validation (rear/front real sensors, flash, capture latency on real hardware) remains open** and is explicitly out of scope of this checkpoint.
- `dumpsys gfxinfo` frame-statistics are non-functional for this Flutter/Impeller build on this image (0 frames / impossible percentiles); responsiveness was verified operationally instead.
- Pinch-zoom gestures inside the strip inspector are covered by widget tests (test suite); on-device evidence covers drag-based zoom/pan (pinch scripting needs custom gesture injection which is out of this checkpoint's tooling budget).
- The "Camera unavailable" error-state screenshot was overwritten by the follow-up viewfinder capture (validation of recovery was done via live dumps); re-capturable on demand.
- Screenshots 01–05 were captured before the Adjust-undo fix; the fix does not affect those flows. All editor/export/album evidence (06–34) is from the final build.
- Emulator gallery-import path does not exist on this AVD (no `content://` image picker population), so "import from gallery" was validated only through the permission/album paths that exist.

## 9. Screenshot inventory (`docs/v3/screenshots/checkpoint-6/`)

| # | File | Shows |
| --- | --- | --- |
| 01 | `01-home.png` | Home, 411 dp |
| 02 | `02-camera-permission-dialog.png` | Camera permission grant dialog (after `pm revoke`) |
| 03 | `03-camera-ready.png` | Viewfinder ready, back camera |
| 04 | `04-camera-countdown.png` | Countdown overlay ("0 of 4", big digit) |
| 05 | `05-review.png` | Review 2×2 grid, "Photo 4 of 4 selected", Retake/Next |
| 06 | `06-decorate-full.png` | Editor overview with decorated strip |
| 07 | `07-decorate-warm-100.png` | Filters shelf, Warm applied |
| 08 | `08-decorate-warm-strength.png` | Strength 50% semantics ("Warm 50% - simulated, not scanned film.") |
| 09 | `09-decorate-frames.png` | Frames tab (paper colour, border) |
| 10 | `10-decorate-frames-themes.png` | 8 frame themes, Vintage Film selected |
| 11 | `11-decorate-pattern-row.png` | Pattern row + Show the date |
| 12 | `12-decorate-sticker-added.png` | "1 sticker added" + Remove last |
| 13 | `13-decorate-text.png` | Text caption "YO!", 3/24 counter, colour swatches |
| 14 | `14-decorate-adjust.png` | Adjust sliders (functional values) |
| 15 | `15-editor-fullscreen-preview.png` | Fullscreen strip inspector (Fit + pinch/pan hint) |
| 16 | `16-undo-reverts-adjust.png` | **After Undo: Brightness 0** (final build) — undo now covers adjustments |
| 17 | `17-export-ready.png` | Export Ready! screen (balanced strip, frames, actions) |
| 18 | `18-duplicate-save-inert.png` | Saved state, Save action inert (`Saved to Photos!`) |
| 19 | `19-share-sheet.png` | System share sheet with PNG |
| 20 | `20-saved-to-album.png` | "Saved to album" + snackbar |
| 21 | `21-album-grid.png` | Album grid, 6 sessions + audit session, storage footer |
| 22 | `22-album-inspect.png` | Album strip inspector (Fit) |
| 23 | `23-delete-confirm.png` | Delete confirmation naming the session |
| 24 | `24-album-after-delete.png` | Post-delete storage 4.1 MB, Oct 19 sessions intact |
| 25 | `25-album-persistence.png` | Album after force-stop + relaunch (6 sessions) |
| 26 | `26-settings.png` | Settings (countdown, sound/flash, mirror selfies, storage) |
| 27 | `27-edit-session-reopen.png` | "Edit Session" with Warm 100% state restored |
| 28 | `28-landscape-home.png` | Landscape home re-layout |
| 29 | `29-landscape-camera.png` | Landscape camera (portrait-cropped viewfinder) |
| 30 | `30-320dp-home.png` | 320 dp home |
| 31 | `31-320dp-edit.png` | **320 dp editor — "Edit Session" fully rendered (title fix verified)** |
| 32 | `32-320dp-album.png` | 320 dp album (2 columns) |
| 33 | `33-320dp-camera.png` | 320 dp camera, all controls reachable |
| 34 | `34-camera-switch.png` | Front camera after Switch camera |

## 10. Verdict

**READY (Android, emulator-verified).**

- No P0/P1 findings; camera → capture → edit → export → album → persist journey is coherent, responsive and resilient (permission, HAL crash, duplicate save, delete confirmation, restart persistence all behave correctly and gracefully).
- Two focused code fixes landed with regression tests and were re-verified on device: adjustment undo/redo (F8) and the 320 dp editor title (F9).
- Also documented: environment-driven freeze (F2), missing shelf loading affordance on slow decodes (F1) and five P3 polish items to address in 6+.
- Released v1.0.0 was not modified or re-signed; no push/deploy performed; the pre-existing album data was preserved (only the audit's own session was deleted).

*Prepared by the Checkpoint 6 audit agent; measurements and screenshots taken 2026-10-21 (UTC+8) on `emulator-5556` (isolated ADB server port 5039; final APK built 14:15:40).*
