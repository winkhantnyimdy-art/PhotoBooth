# PhotoBooth V3 — Checkpoint 5B Report

**Date:** 2026-10-21 *(supersedes the 2026-10-20 version — see "Correction of the earlier report")*
**Branch:** `photobooth-v3-android`
**Baseline commit:** `2164d83` — *Checkpoint 5 - Creative effects and frame experience*
**Code fixes:** `48c90e6` — *Checkpoint 5B: fix filter shelf clipping and frame/pattern chip contrast*
**Flutter:** 3.47.5 · Windows host · Android only

## Status

- [x] Filter shelf clipping resolved
- [x] Selected frame/pattern contrast resolved
- [x] Small-viewport (320 dp) regression resolved — tab captions and one-line hint finalized
- [x] `flutter analyze` — **No issues found! (ran in 7.8s)** (2026-10-21)
- [x] `flutter test` — **+530: All tests passed!** (2026-10-21, includes the 6 new focused tests)
- [x] `flutter build apk --debug` — exit 0, `build\app\outputs\flutter-apk\app-debug.apk` (202,834,705 bytes, built 2026-10-21 11:25:26 UTC+8)
- [x] Emulator screenshots re-captured from the final APK into `docs/v3/screenshots/checkpoint-5b/`
- [x] Prior acceptance evidence (`docs/v3/CHECKPOINT_5_ACCEPTANCE.md` + `docs/v3/screenshots/checkpoint-5-acceptance/`) committed so the measurements above are reproducible

## Root Causes and Fixes

### 1. Filter shelf clipping (release blocker)

**Root cause:** at the Checkpoint-5 baseline the editor tray height clamp allowed a tray too short for the actual content stack (header + strength slider + effect shelf + hint). On 320×640 and 360×800 viewports the lower shelf tiles and their labels fell behind the "Finish & Save" bar and was unreadable.

**Fix (in `lib/features/decorate/decorate_screen.dart`)**

- The tray height is floored to the measured content minimum:
  `final double trayHeight = (screen * 0.36).clamp(298.0, 340.0).toDouble();`
  — **the real floor is 298 dp** with a hard cap of 340 dp.
- The content was compacted to fit inside that floor instead of inflating the tray further:
  - section header row reduced to 24 dp and "Reset to Original" folded into the header row,
  - strength slider hosted in a 38 dp `SizedBox`,
  - effect shelf 94 dp,
  - two 2 dp (`S.xxs`) gaps between sections,
  - the hint folded to a single line: `"Original - simulated, not scanned film."` / `"<effect label> <percent>% - simulated, not scanned film."`
- Horizontal scrolling of the effect shelf is preserved; the tray never exceeds ~36 % of the screen on short viewports, keeping the photo preview above it visible.

**Correction of the earlier report:** the 2026-10-20 version claimed the clamp minimum was "raised to 320 dp"; the shipped value is **298 dp**. The original description of the tray clipping mechanism (tray shorter than the content stack pushing the shelf under the action bar) remains correct, but the documented floor was wrong.

### 2. Selected frame/pattern chip contrast (release blocker)

**Root cause:** the shared `_ChoicePill` used the same white/`silver` pair for the selected state as for the unselected state; once the dark ink was applied, the selected capsule rendered as a low-contrast "blank pill" with an unreadable label.

**Fix (centralized tokens in `lib/core/theme/app_colors.dart`)**

| Token | Value | Purpose |
| --- | --- | --- |
| `darkChipSelectedSurface` | `0xFFF2F2F4` | light fill for the selected state |
| `darkChipSelectedInk` | `0xFF16161A` | dark ink for the selected label |
| `darkChipDisabledSurface` | `0xFF26262C` | fill for disabled options |
| `darkChipDisabledInk` | `0xFFA6A6AD` | muted ink for disabled options |

`_ChoicePill` selects one of three states (disabled / selected / unselected) from a single source, applied uniformly to the Border (FrameStyle), Frame theme (FrameTheme) and Pattern (DecorativeStyle) pill rows.

Measured WCAG 2.1 contrast of the three states (computed from the exact token values):

| State | Surface / Ink | Contrast |
| --- | --- | --- |
| Selected | `#F2F2F4` / `#16161A` | **16.14 : 1** |
| Unselected | `#1C1C20` / `#FFFFFF` (`darkSurface` / `onDark`) | **16.99 : 1** |
| Disabled | `#26262C` / `#A6A6AD` | **6.22 : 1** |

All three clear 4.5 : 1; selected and disabled are also visually distinct (light fill vs. slightly lifted hollow fill), so a disabled option cannot be mistaken for an unselected one.

### 3. Small-viewport tab bar (found while testing 320 dp)

At 320 dp the five equal tool tabs left ~44 dp for a caption after the 17 dp icon, so "Stickers" and "Frames" ellipsized. `_buildTabBar` now uses a compact style when `MediaQuery.sizeOf(context).width < 360`: icon 15 dp, gap 2 dp, label 10.5 dp, and the caption is wrapped in a `FittedBox(fit: BoxFit.scaleDown)` instead of `ellipsis`, so captions shrink instead of truncating. On ≥360 dp widths nothing changes (icon 17, gap 4, label 11.5).

## Modified Files

1. `lib/core/theme/app_colors.dart`
   - Added the centralized chip color constants (selected / disabled).
2. `lib/features/decorate/decorate_screen.dart`
   - Floored the editor tray height at the measured content minimum (298 dp/cap 340 dp).
   - Compacted the Filters section (24 dp header with inline Reset, 38 dp slider, 94 dp shelf, 2 dp gaps, one-line hint).
   - Applied the centralized chip colors through `_ChoicePill`.
   - Added the responsive compact tab-bar style for widths < 360 dp.
3. `test/features/decorate/filter_tray_layout_test.dart` (new)
   - 6 focused regression tests: label visibility above Finish & Save, horizontal shelf scrolling, action-bar non-overlap, shelf visible at a 320×640 viewport, selected chip contrast, disabled chip muted state.

## Emulator Evidence (`docs/v3/screenshots/checkpoint-5b/`)

Captured 2026-10-21 on a freshly booted AVD `Medium_Phone` (`emulator-5556`, 1080×2400, density 420) via `uiautomator` taps and `screencap`, using an isolated ADB server session (port 5039) so concurrent agent sessions using a shared ADB server could not race it. All six were taken from the final APK build listed above.

| File | Captured state |
| --- | --- |
| `01-filter-shelf-before-scroll.png` | Filters tray at the shelf start; Original/Soft/Warm/Cool labels clear of Finish & Save |
| `02-filter-shelf-after-scroll.png` | Shelf scrolled to the end; CCD / Tokyo Night / Mono / Noir / Dream visible |
| `03-frame-selector.png` | Frame themes row with Vintage Film selected — light fill, dark ink readable |
| `04-pattern-selector.png` | Pattern row with Hearts selected — same state rules |
| `05-editor-finish-save.png` | Full editor with Warm + Vintage Film + Hearts applied; Finish & Save sits below the shelf |
| `06-editor-small-viewport.png` | **Re-captured from the final APK at 840×1680 (320×640 dp)** with the compact tab style; all five tab labels render, shelf labels clear, one-line hint |

Before-state close-ups from the audit are in `docs/v3/screenshots/checkpoint-5-acceptance/` (`22-filter-tray-clipping.png`, `23-frame-theme-pill-contrast.png`).

## Preview / Export Parity (unchanged behavior, clarified)

The Checkpoint 5 acceptance audit measured the editor preview against the exported PNG: best alignment offset **(0, 0)** — there is no crop/misalignment — full-crop MAE **20.03/255**, 12-px-inset MAE **17.89/255** with grayscale Pearson **0.857**, export resolution **1200×6459**. The residual is concentrated at edges and comes from the preview being a much smaller resampled, rounded-corner raster — i.e. resampling/anti-aliasing/scaling differences, not a composition or export bug. No export-engine change was made in Checkpoint 5B.

## Not Changed / Preserved

- The 15-effect engine (`PhotoEffect`/`PhotoFilter`), strength control, undo/redo, Reset to Original.
- All 8 `FrameTheme` identities and 4 `FrameStyle` borders; pattern selector.
- Stickers and text editing; navigation; export/save/share paths including MediaStore album storage.
- Published v1.0.0 history, release signing, no deploy/publish step.
- Untracked `tool/emu_pinch.ps1` was left untouched and is not committed.

## Remaining Limitations

- At 320 dp the review/editor session title truncates ("Edit Sess…"), as seen in `06-editor-small-viewport.png`. The tab bar and tray were the in-scope defects; the title was left as-is because equal appbar space is already given to the undo/redo/reset/expand controls.
- The acceptance audit's frozen emulator session is not a reproducible file fixture; `docs/v3/fixtures/reference-capture.jpg` remains test-tooling only (no gallery import in the app).
- Only the debug APK was built; no release build or signing changes.
- Effects/frames beyond the inspected subset are covered by engine tests (`test/core/filters/photo_effect_test.dart`, `test/features/export/photo_strip_filter_test.dart`) but were not all visually inspected on the emulator.
