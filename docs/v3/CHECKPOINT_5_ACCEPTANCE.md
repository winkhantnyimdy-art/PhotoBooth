# Checkpoint 5 Acceptance — Retro Film Pop

Branch: `photobooth-v3-android`  
Commit: `2164d83` — *Checkpoint 5 - Creative effects and frame experience*  
Date: 2026-10-20  
Device: Android emulator `emulator-5554`, AVD `Medium_Phone`, 1080 × 2400  
Build: debug APK, no release signing changes

## Verdict

| Area | Result |
| --- | --- |
| 15-effect engine inventory | **Pass** — all 15 documented and implemented |
| Requested effect variants | **Pass** — Original, Classic Film, Dreamy, Vintage, Tokyo Night, Mono all render differently |
| Reset to Original | **Pass** — state restores to Original at 100%, reset affordance disappears |
| Undo / redo around reset | **Pass** — undo restores Dreamy, redo returns to Original |
| Frame selection | **Pass functionally** — Minimal White, Dark Film and Vintage Film apply visibly different paper, border and footer treatments |
| Export vs editor | **Pass structurally**; **partial** as a screenshot comparison — same composition and frame, but the preview is a scaled, rounded clip, so pixels are not identical |
| Filter-tray visual layout | **Fail** — effect shelf labels are clipped by the tool tray and the Finish & Save bar |
| Frame-theme chip contrast | **Fail** — selected chip is white-on-white; the selected label is unreadable |
| `flutter analyze` | **Pass** — no issues |
| `flutter test` | **Pass** — 524 tests passed |
| Android debug build | **Pass** |

The interactive behavior is working. Checkpoint 5 is **not visually clean** because of the layout/contrast defects above. No production code was changed during this audit.

## Check classification

| Check | Verification method | Result |
| --- | --- | --- |
| 15-effect inventory and processing rules | Code inspection of `photo_effect.dart`, `photo_filter.dart`, renderer and tests | Documented |
| Effect variants | Emulator screenshots, visual inspection, same-crop pixel distances | Pass |
| Reset to Original | Scripted `uiautomator` state assertion plus screenshot | Pass |
| Undo and redo around reset | Scripted `uiautomator` state assertions plus screenshots | Pass |
| Frame selection and three frames | Emulator screenshots and visual inspection | Pass functionally |
| Export vs editor composition | Visual side-by-side, difference image, MAE/correlation | Pass structurally; not pixel-identical |
| Filter-tray layout | Visual inspection and close-up crop | Fail |
| Frame/pattern selected-chip contrast | Visual inspection and close-up crop | Fail |
| `flutter analyze` | Automated command | Pass |
| `flutter test` | Automated command | Pass, 524 tests |
| Android debug build | Automated command | Pass |
| Real camera behaviour | Not exercised | Not verified |
| All 15 effects / all 8 frames on device | Not exercised | Not verified |

## Source image and capture method

The app has no gallery import. To keep one source constant across all variants, I captured **one four-photo session once** and never recaptured between effects or frames. Every effect and frame screenshot below therefore shows exactly the same four photos, in the same 4 CUT layout, at 100% strength, with the default Retro Pop frame until the frame section begins.

This is a frozen emulator session, not a reproducible file fixture. The emulator camera scene is the virtual scene, not a real camera. The existing deterministic `docs/v3/fixtures/reference-capture.jpg` was not loaded into the app; it is used by the engine comparison test tooling, not by the camera UI.

All captures were taken on the debug APK for `2164d83` already installed on the emulator. After capture, the same source tree was rebuilt successfully.

## Effect inventory — actual processing behavior

Every effect is a digital simulation: a 4 × 5 colour matrix, followed where indicated by a screen-blended bloom pass and/or deterministic procedural grain.

Shared rules from `lib/core/filters/photo_effect.dart` and `lib/core/filters/photo_filter.dart`:

- **Intensity:** the preset matrix is interpolated towards the identity matrix. At 0%, matrix, grain and bloom are all identity/zero, and the export is byte-identical to Original.
- **Grain:** scaled by intensity, fixed seed `0x5EED`, density and speck radius scale with the region size so thumbnails and exports look consistent.
- **Bloom:** scaled by intensity, screen blend; blur radius is a fraction of the region's short side, so the look survives resolution changes.
- **Manual adjustments:** composed after the effect matrix; they do not change the effect's grain or bloom amounts.

| # | Effect | Colour treatment at 100% | Grain | Bloom |
| --- | --- | --- | --- | --- |
| 1 | Original | Identity matrix | — | — |
| 2 | Soft | Contrast 0.88, brightness +0.045, saturation 0.94 | — | 0.30, radius 0.012 |
| 3 | Warm | Temperature +0.34, saturation 1.10, contrast 1.03 | — | — |
| 4 | Cool | Temperature −0.32, saturation 1.04, contrast 1.04 | — | — |
| 5 | 35mm | Temperature +0.20, contrast 0.94, brightness +0.03, saturation 0.90 | 0.35 | — |
| 6 | Vintage | Sepia 0.42, temperature +0.16, contrast 0.82, saturation 0.80 | 0.55 | — |
| 7 | Grain | Contrast 1.04, saturation 0.94 | 0.85 | — |
| 8 | Faded | Contrast 0.74, brightness +0.075, saturation 0.62 | — | — |
| 9 | Classic Film | Temperature +0.13, contrast 0.88, brightness +0.045, saturation 0.84 | 0.28 | — |
| 10 | Y2K Flash | Temperature −0.10, contrast 1.20, brightness +0.02, saturation 1.22 | — | 0.55, radius 0.018 |
| 11 | CCD | Channel bias R 1.04 / G 1.02 / B 0.95, contrast 1.16, saturation 1.30 | — | — |
| 12 | Tokyo Night | Shadow lift RGB (0.10, 0.16, 0.34) at 0.16; highlight tint RGB (1.00, 0.62, 0.92) at 0.20; temperature −0.16; saturation 1.12 | — | — |
| 13 | Mono | Contrast 1.06, saturation 0 | — | — |
| 14 | Noir | Contrast 1.55, brightness −0.06, saturation 0 | — | — |
| 15 | Dreamy | Pink tint 0.55, contrast 0.80, brightness +0.06, saturation 0.92 | — | 0.80, radius 0.030 |

No effect is a scanned film stock or a bitmap overlay. The grain and bloom are procedural.

## Requested checks

### Effect variants

| Requested check | Closest existing option | Screenshot | Visual result |
| --- | --- | --- | --- |
| Original | `PhotoEffect.original` | `01-original.png` | Baseline |
| Classic Film, or closest | `PhotoEffect.classicFilm` (exact) | `02-classic-film.png` | Warmer, softer, less saturated |
| Soft / dreamy | `PhotoEffect.dreamy` (strongest soft option) | `03-dreamy.png` | Obvious pink lift and bloom |
| Vintage | `PhotoEffect.vintage` (exact) | `04-vintage.png` | Lower contrast, sepia/warm treatment |
| Digital / cool | `PhotoEffect.tokyoNight` | `05-tokyo-night.png` | Cool teal shadow cast, muted highlights |
| Black & White | `PhotoEffect.mono` | `06-mono.png` | Fully desaturated grey |
| Reset after effect | `Reset to Original` in Filters | `07-reset-original.png` | Original selected, 100%, reset affordance gone |

`Cool`, `CCD`, `Soft` and `Noir` also exist. `Tokyo Night` was chosen as the digital/cool representative; `Mono` was chosen as the neutral black-and-white representative.

The same source crop was compared across the six effect screenshots. Mean absolute error against Original, in 0–255 channel units, over the 222 × 1194 preview crop:

| Effect | MAE vs Original | Pixels changed by more than 8/255 |
| --- | ---: | ---: |
| Classic Film | 13.63 | 61.5% |
| Dreamy | 44.00 | 93.9% |
| Vintage | 21.34 | 84.2% |
| Tokyo Night | 20.44 | 91.3% |
| Mono | 35.06 | 82.6% |

Every captured effect is measurably different from Original. The smallest difference is Classic Film, which is intentionally the subtlest of the requested options. On the green virtual scene, Vintage reads green-amber rather than brown sepia; that is the matrix's sepia/temperature treatment acting on a strongly green source, not a missing effect.

### Reset, undo and redo

1. Dreamy was selected at 100%.
2. `Reset to Original` was tapped. The resulting UI hierarchy reported `Original effect` selected and `No effect`, and the reset affordance disappeared (`07-reset-original.png`).
3. Undo was tapped. The hierarchy reported `Dreamy effect` selected and the reset affordance returned (`08-undo-restores-dreamy.png`).
4. Redo was tapped. The hierarchy reported `Original effect` selected and `No effect` again (`09-redo-restores-original.png`).

The state assertions were made from live `uiautomator` dumps, not inferred from screenshots. The selected-state evidence is preserved in `evidence-ui-states.txt`.

### Frames

The frame system has 8 themes and 4 underlying border styles:

| Theme | Identity |
| --- | --- |
| Retro Pop | Polka-dot pink scrapbook |
| Y2K Pop | Chrome, bubbles and starbursts |
| Vintage Film | Sepia rails and an orange date stamp |
| Cherry Blossom | Sakura petals on soft pink |
| Kawaii | Pastel scallops and tiny hearts |
| Minimal White | Quiet hairline and small caps |
| Dark Film | Black rail, amber marks, sprocket edge |
| Birthday | Bunting, confetti and a cake |

Captured frame screenshots:

| Screenshot | Frame |
| --- | --- |
| `10-frames-tab.png` | Frame selection UI, all theme pills visible |
| `11-frame-minimal-white.png` | Minimal White |
| `12-frame-dark-film.png` | Dark Film |
| `13-frame-vintage-film.png` | Vintage Film |
| `21-frame-contact-sheet.png` | Three frame previews side by side |

The frame previews are visibly different in paper, footer wordmark, border colour and sprocket/date treatment. Pairwise full-preview MAE is only 1.1–3.7/255 because most of the image is the same four photos; the changes are concentrated in the border and footer, which is expected.

### Export and save

The final composition used Original at 100% with the Vintage Film frame.

- `14-export-save-share.png` — Ready screen with the composed strip.
- `15-save-success.png` — Saved confirmation.
- `16-exported-strip.png` — the actual PNG pulled from MediaStore, **1200 × 6459**, RGBA.
- Device path: `/storage/emulated/0/Pictures/PhotoBooth_20261020_102614.png`.

The exported PNG and the editor screenshot show the same four photos, spacing, footer, wordmark and frame treatment.

### Preview/export pixel comparison

`17-preview-vs-export.png` places the editor preview crop next to the exported PNG resized to the same size. `18-preview-export-diff.png` is a 4× amplified difference image. `19-corner-compare.png` compares the top-left corner at 4× nearest-neighbour zoom.

Measured over the editor preview crop (222 × 1194) versus the 1200 × 6459 export resized with Lanczos:

| Measurement | Result |
| --- | --- |
| Full-crop mean absolute error | 20.03 / 255 |
| Full-crop grayscale Pearson correlation | 0.825 |
| 8-px-inset crop MAE / correlation | 18.13 / 0.850 |
| 12-px-inset crop MAE / correlation | 17.89 / 0.857 |

The difference image shows the residual concentrated at edges: the preview is a much smaller raster, is clipped to rounded corners, and has had different resampling applied. The frame artwork itself matches; `19-corner-compare.png` shows the same dashed border and paper, with the preview's rounded clipping covering part of the border.

This is therefore **not** a pixel-identical screenshot comparison. The automated suite verifies the shared `EffectRecipe`, bloom, grain and `FrameThemePainter` invariants and export determinism at a fixed resolution; it does not compare a captured preview screenshot to a PNG at the same scale.

## Automated verification

`flutter analyze`:

```text
No issues found! (ran in 13.3s)
```

`flutter test`:

```text
+524: All tests passed!
```

The suite includes effect and export coverage in:

- `test/core/filters/photo_effect_test.dart` — 15 stable identifiers; every non-Original effect changes pixels; 0% is pixel-identical to Original; Mono/Noir desaturation; Noir contrast; Warm/Cool direction; Faded black lift; deterministic grain; bloom; preview/export agreement; undo/redo state.
- `test/features/export/photo_strip_filter_test.dart` — all 15 exports distinguishable; strength 0 byte-identical to Original; deterministic grain; bloom highlights; manual adjustments; frame themes; captions; stickers/text survive an effect.
- `test/features/decorate/frame_options_test.dart` — frame options reflected in exported PNGs.

`flutter build apk --debug`:

```text
Built build\app\outputs\flutter-apk\app-debug.apk
```

- Exit code: 0
- APK: `build/app/outputs/flutter-apk/app-debug.apk`
- Size: 202,834,705 bytes
- Built: 2026-10-20 10:56:18
- Gradle emitted Java native-access warnings; they did not fail the build.

## Visual defects found

These are current UI behaviours at `2164d83`; none is caused by the screenshot tooling.

### 1. Filter shelf is clipped by the tray / Finish & Save bar — release blocker

With an effect selected, the Filters tray shows the header, strength slider, `Reset to Original`, and the effect shelf. The shelf's lower portion is cut off and the effect labels are hidden behind/under the Finish & Save region. Only about four and a half tiles are visible without scrolling, and the user cannot read which effect is selected.

`22-filter-tray-clipping.png` is a close-up of the defect from `03-dreamy.png`.

The interaction still works: I was able to scroll and select every requested effect by accessibility bounds. The failure is visual and discoverability-related, not a dead control.

### 2. Selected frame/pattern pill is white-on-white — release blocker

The selected Frame Theme chip is a solid white capsule with white text, so its label disappears. In `10-frames-tab.png` the selected Vintage Film chip is a blank white pill. The same applies to the selected Pattern pill. The selection is active — confirmed by the preview and the UI hierarchy — but the control is unreadable.

`23-frame-theme-pill-contrast.png` is a close-up of the frame-theme row from `10-frames-tab.png`.

### 3. Preview corners are rounded, export corners are square — minor parity note

The editor preview is clipped with rounded corners; the exported PNG has square corners. The frame artwork inside is the same. This accounts for part of the screenshot/export pixel difference and should be documented if exact preview/export appearance is expected.

## Not verified

- Real camera hardware, low light, autofocus, capture latency or device-specific camera behaviour. All captures use the emulator's virtual scene.
- All 15 effects and all 8 frames individually on the emulator. The requested six effects and three frames were inspected; the remaining effects/frames are covered by the engine tests but not visually inspected here.
- Sticker editing, text editing and drag/rotate gestures. Existing tests cover rendering, but these interactions were not exercised in this acceptance run.
- Long-session memory/performance and repeated export cycles beyond this one save.
- Pixel-identical preview/export equality. The comparison above is a resampled screenshot comparison, not a same-resolution pixel test.
- TalkBack/semantics behaviour of the new Reset control and the clipped shelf labels.
- A release build or release signing. Only the debug APK was built.

## Artifacts

All new screenshot/evidence files are under `docs/v3/screenshots/checkpoint-5-acceptance/`:

`01-original.png` — `02-classic-film.png` — `03-dreamy.png` — `04-vintage.png` — `05-tokyo-night.png` — `06-mono.png` — `07-reset-original.png` — `08-undo-restores-dreamy.png` — `09-redo-restores-original.png` — `10-frames-tab.png` — `11-frame-minimal-white.png` — `12-frame-dark-film.png` — `13-frame-vintage-film.png` — `14-export-save-share.png` — `15-save-success.png` — `16-exported-strip.png` — `17-preview-vs-export.png` — `18-preview-export-diff.png` — `19-corner-compare.png` — `20-effect-contact-sheet.png` — `21-frame-contact-sheet.png` — `22-filter-tray-clipping.png` — `23-frame-theme-pill-contrast.png` — `evidence-ui-states.txt`

## Repository state

No production code was changed. `git status` shows only the new acceptance report, the new acceptance directory, and the pre-existing untracked `tool/emu_pinch.ps1`, which was left untouched. The acceptance artifacts are not committed.
