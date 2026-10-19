# Checkpoint 4 Report — Minimal Dark Polish (Save & Share, Album, Settings, Editor)

Branch `photobooth-v3-android`, baseline `0229430` (Checkpoint 3 is frozen there).
Everything below was re-verified in this session; nothing is assumed from a
previous run.

## What shipped

### Save & Share (Export) — `lib/features/export/export_screen.dart`

- The preview now claims all available height between the header and the
  actions via `Center(AspectRatio)` instead of a fixed-height box: a tall
  4 CUT ribbon scales to the available height, a wide 1×4 strip to the
  available width — never cropped, never distorted.
- Duplicate gallery saves are impossible: once `_gallerySaved` is set the Save
  button turns into a disabled green `Saved` state (saving again short-circuits
  before any platform work). successful save shows a `Saved to Photos!`
  snackbar — no fake success, the disabled state is real.
- The header uses the shared `MinimalIconButton` (`Close and discard`,
  `Back to Home`); the ad-hoc `_CircleButton` was deleted from this screen and
  from Settings.
- Short screens: the subtitle stays and the strip still fits (see the compact
  layout test note below).
- Final polish this session: the global `OutlinedButton` theme paints white
  fills for the light paper surfaces, so on this dark screen the Share and
  Save-to-album pills set `backgroundColor: darkElevated` +
  `foregroundColor: onDark` explicitly (white-on-white labels found in the
  first emulator captures are fixed), and the retro pink/white checkerboard
  footer row is gone from the completion screen.

### Album — `lib/features/album/album_screen.dart`

- Clean dark grid (`childAspectRatio: 0.58`), thumbnails letterboxed with
  `BoxFit.contain` so no aspect ratio lies, per-card Inspect and Delete
  actions (`_CardActionButton`).
- Inspect renders the *real* strip: `loadSession` → `materialize` →
  `PhotoStripRenderer` — not the low-res thumbnail. The screen takes a
  `renderer` parameter so tests can inject a fixed renderer.
- Clear empty state (`No saved sessions yet`) with guidance, plus the honest
  storage footer (`Saved on this device only … Uninstalling wipes it`).
- The retro pink/white checkerboard footer row is removed (Minimal Dark).

### Settings — `lib/features/settings/settings_screen.dart`

- Consistent dark surfaces, 48dp targets, `MinimalIconButton` header.
- No accounts, analytics or cloud anywhere.
- The retro checkerboard footer row is removed (Minimal Dark).

### Editor polish — `lib/features/decorate/decorate_screen.dart`,
`lib/shared/strip_inspector.dart`

- Inspect is a header circle button (`Inspect the photostrip full screen`)
  instead of an always-present utility bar, so the tray keeps the pinned
  preview size contract at fit scale. The conditional `_buildFitBar()`
  (`if (_zoomScale > 1.01)`) surfaces `Reset preview zoom` / `Preview zoomed`
  only while actually zoomed.
- `StripInspector` listens to its `TransformationController` (added in
  `initState`, removed in `dispose`) instead of relying on
  `onInteractionUpdate`, so a programmatic Fit reset flips `_zoomed`
  correctly; the semantic label is attached with `Semantics(label, image:true)`.
- The zoomed preview state (pinch on device) is reachable for automated
  verification through a debug-only VM service extension (see Debug tooling);
  a real pinch drives the exact same controller.
- `No effect` readouts on Original (never "100%"), slider visible but inert;
  a real effect shows the percentage and an enabled slider.
- New this session: centre-anchored programmatic zoom. The first zoomed
  capture showed the strip sliding half out of view (an uncompensated
  diagonal matrix scales around the child's top-left corner). The debug zoom
  helper now anchors the scale on the InteractiveViewer viewport centre —
  the same framing a mid-photo pinch produces.

## Debug tooling (committed, debug-only)

- `lib/main.dart` registers `ext.flutter.photoBooth.previewZoom`
  (`factor` = `2.2` or `1`) behind `kDebugMode`; it delegates to
  `scheduleEditorZoomForCurrentEditor` in `decorate_screen.dart`, which finds
  the live editor state and sets the same `TransformationController` a pinch
  drives. Reason: emulator input is single-pointer — `adb input` can't
  synthesize multitouch, `sendevent` is denied on production builds and the
  console `event send` never reaches the kernel (all verified empirically).
- `tool/capture_checkpoint4_ui.ps1` — the whole checkpoint flow
  (Home → Camera → 4-CUT capture → Review → Decorate → effects → zoom/fit →
  inspect → Export → gallery save → album save → Make Another → Album →
  inspection → Settings) with route/text assertions at every hop, hierarchy
  retries, and screencap pulls.
- `tool/vm_call_ext.py` — minimal VM-service websocket caller used to invoke
  the extension (plain HTTP GET works only for `getVM`, not for service
  extensions).

## Verification gates (actual results)

| Gate | Result |
| --- | --- |
| `flutter analyze` | `No issues found!` (run standalone on `lib` and over the package multiple times) |
| `flutter test` | **524 passed, 0 failed** (Checkpoint 3 baseline: 516) |
| `flutter build apk --debug` | success, 202,834,705 bytes; `applicationId` and signing config untouched |
| Emulator E2E | full flow above, exit code 0, assertions at every hop (`tool/capture_checkpoint4_ui.ps1`, final run on the committed tree) |

New tests (8):

- `test/shared/strip_inspector_test.dart` (3): fit reset flips the zoomed
  state via the controller listener, semantic label lands on the strip,
  dispose removes the listener.
- `test/features/v3_review_decorate_test.dart` (+3): Original shows
  `No effect` with a disabled slider (checked through the new
  `SemanticsNode.flagsCollection` — the old `hasFlag` API is deprecated),
  Inspect round-trip to the full-screen inspector and back, shelf chevron
  scrolls and the readouts retract correctly.
- `test/features/export/export_screen_test.dart` (+1): duplicate save is
  inert (button disabled, no second platform save, no premature success).
- `test/features/album/album_reopen_test.dart` (+1): album Inspect round-trip
  renders the real strip through the injected `_FixedStripRenderer`.
- `test/features/compact_layout_test.dart` (rewritten case): the flex layout
  keeps the subtitle and a usable strip on a short screen; asserts
  `Preview height > 100` and no premature `Saved as` success.

`dart format` applied to the new/majority-rewritten files only
(`strip_inspector.dart`, `strip_inspector_test.dart`, `main.dart`).
⚠ one formatting change landed in `main.dart`; tests were re-run afterwards
(524 pass).

## Screenshots (all from the final build, emulator-5554)

`docs/v3/screenshots/checkpoint-4/`:

| File | Shows |
| --- | --- |
| `01-save-share.png` | Ready! with the full-height strip print, pink Save, dark Share/Save-to-album pills (this session's dark-pill fix), Make Another |
| `08-save-success.png` | success state: disabled `Saved` button + `Saved to Photos!` snackbar |
| `02-album.png` | populated album grid with per-card Inspect/Delete and the storage footer, checker gone |
| `03-album-inspection.png` | full-screen Inspector on the album card — real rendered strip, Fit state, pinch/pan hint |
| `04-settings.png` | dark sections, pink accents, storage rows, danger Clear-album row, checker gone |
| `05-decorate-default.png` | editor default: Original selected, `No effect` readouts, inert slider, header Inspect |
| `06-decorate-zoomed.png` | zoomed (2.2×, centre-anchored) with the Fit bar + `Preview zoomed` |
| `07-decorate-filters.png` | Warm selected at 100%: ring on the chip, live readouts, enabled full-width slider, shelf chevron |
| `03-decorate-inspection.png` | editor Inspect full-screen (extra evidence for the same inspector) |

## Emulator evidence beyond the capture script

- Album save + canon of states were re-verified interactively: after
  `Save to album` the button flips to `Saved to album`, `Make Another`
  returns to Home, the album contains the session (`4 photos · 4 CUT`), the
  inspection opens the full strip (`Preview`, `Pinch to zoom, drag to pan`)
  and Settings opens (`Camera`, `Countdown`, `Storage`).
- A snackbar-race failure was diagnosed and fixed in the capture driver: the
  auto-dismissing post-save snackbar floats above the bottom bar for ~4 s and
  swallowed the Make Another tap (twice). The script now waits it out; the
  manual recovery also proved the same tap succeeds once the snackbar is
  gone.

### Sticker/undo E2E probe (partial, honest result)

On-device probe: Stickers tab opened (`STICKER SHELF`, shelf chips dumped),
`Heart sticker` chip tapped, decoration state cleared via the header Reset —
the strip region pixel-diff changed across the reset, proving a decoration
was actually added and reset works. Complete single-photo Retake and
undo/redo E2E taps stayed inconclusive under `adb input` (single-pointer
input, uiautomator drop-merge of the composition subtree; the Retake camera
would not advance from the selection state in this harness — the selection
state itself is captured live: `Photo 4 of 4 selected · Retake replaces only
this one`). Those flows are pinned by the widget suites (524 passing,
including dedicated sticker add/remove, text add/edit and undo/redo cases),
not by this emulator run — stated here as-is.

## Performance checkpoint (same environment as Checkpoint 3)

- Decorate → Finish & Save → Ready! (full export render + preview):
  ~4 s (includes the dialog poll granularity, same as CP3 measurement).
- No regressions observed in strip rendering or save latency; memory work
  from Checkpoint 3 (capped previews) is untouched.

## Limitations

- No physical device: all evidence comes from `emulator-5554`
  (AVD `Medium_Phone`, 1080×2400). Emulator-only, same as Checkpoint 3.
- No multitouch synthesis available on this emulator image; the zoomed-state
  evidence goes through the debug-only `previewZoom` extension documented
  above (the same `TransformationController` a pinch drives), not
  `adb input`.
- The completion screen's dark pills fix (`darkElevated` on
  `OutlinedButton`) is a screen-local override of the global light-paper
  button theme; a future theme refactor may want a dedicated dark-mode
  `OutlinedButtonTheme` instead.
- Album grids in the captures contain several sessions because each
  scripted E2E pass saved one — that is expected, not a bug.

Nothing has been pushed, merged, published or deployed. The owner's visual
approval of the captures is the remaining gate before Checkpoint 5.
