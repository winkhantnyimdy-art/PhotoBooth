# Checkpoint 3 Report — 15-Effect Professional Film & Camera Effects Engine

Branch `photobooth-v3-android`, recovery baseline `4df30a3` (Checkpoint 2).
Everything below was re-verified in this session; nothing is assumed from a
previous run.

## What shipped

A real, pixel-level effects engine shared by the Decorate preview and the
export renderer, replacing the legacy colour-matrix-only filters:

- `lib/core/filters/photo_effect.dart` — the engine. 15 `PhotoEffect` recipes
  built from `EffectGrain` (deterministic film grain, three scales), `EffectBloom`
  (screen-space highlight lift), fades/curves and colour grading primitives.
  Intensity is a monotonic 0–100% scalar on every recipe; `PhotoEffect.original`
  is the identity.
- `lib/core/filters/effect_image.dart` — the shared preview painter. The shelf
  chips, the main preview and the export renderer all resolve the same
  `EffectRecipe`, so what you pick is what you export.
- `lib/features/export/photo_strip_renderer.dart` — export-side recipe
  resolution plus the bloom and grain passes at export resolution.
- `lib/core/filters/photo_filter.dart` — legacy `PhotoFilterType.toEffect()`
  migration; no user-facing behaviour lost.
- `lib/core/filters/film_grain.dart` — **deleted** (orphaned experiment
  superseded by `EffectGrain`/`EffectGrainOverlay`; zero remaining references).
- `lib/features/decorate/decorate_screen.dart` — Filters tab drives the engine:
  15-chip shelf (live graded thumbnails, hold-to-compare against the original),
  strength slider wired through `_changeEffect`/`_changeEffectIntensity` so
  effect and strength changes participate in undo/redo like every other edit,
  semantic labels (`'<name> effect'`, `'Effect strength'`), and a clear inert
  state on Original.

Zero new dependencies; `pubspec.yaml`/`pubspec.lock` unchanged.

## The strength slider defect (found and fixed this session)

Emulator pixel-scanning showed the strength slider painted nothing: its
semantics node existed and taps changed the value (100% → 33%), but the band it
occupied was flat panel background in every capture. The Checkpoint 2
`decorate.png` shows the same defect (a thumb sliver under the finish button) —
this was pre-existing, not a Checkpoint 3 regression.

Root cause: the Filters tab content is taller than the tray's internal scroll
viewport, and the strength slider sat exactly on the viewport cut beneath the
pinned Finish & Save bar — laid out, hittable through the visible sliver, but
with its track and thumb below the cut, so nothing painted. A widget test
pumping the screen at the emulator's 360×800 confirmed the rects: the finish
bar (`top` 760) overlapped the slider box (765–813), and hit tests below the
cut fell through to the panel background.

Fix (`decorate_screen.dart`):

1. The strength control now sits directly under the section header, above the
   shelf, so it is always visible without scrolling.
2. The tray height factor is `screen * 0.36` (clamp 212–340) instead of
   `0.32` (clamp 212–300); on the emulator this moves the viewport cut below
   the shelf labels. The photostrip is not shrunk.

Post-fix verification, same pixel-scan method on fresh captures:
- Grain @ 100%: full-width bright track band at the slider row.
- Grain @ 33%: fill ends at x≈414/1080 (33% of the track) with the thumb blob
  centred there.
- Original: visible inert track/grey thumb, header readout still 100%, a11y
  node reports `enabled=false`.

## Verification gates (actual results)

| Gate | Result |
| --- | --- |
| `flutter analyze` | `No issues found!` |
| `flutter test` | **516 passed, 0 failed** (Checkpoint 2 baseline: 478) |
| `flutter build apk --debug` | success, 202,834,705 bytes (~193.5 MiB); `applicationId` and signing config untouched |
| Emulator flow | Home → Camera → 4-CUT capture → Review (4 photos) → Decorate → shelf scroll → Grain → 100% → 33% → back to Original, with route/text assertions at every hop (`tool/capture_checkpoint3_effects.ps1`) |
| Comparison sheets | `tool/generate_effects_comparison.dart` rendered from the real pipeline; visually distinct grain/bloom/fade/crush (`effects-comparison*.png`, `effects-intensity.png`) |

New tests: `test/core/filters/photo_effect_test.dart` (35 engine tests: 15 ids,
identity, clamping, monotonic intensity, grain determinism/scale, bloom
screen-lift, preview/export agreement, undo/redo, legacy migration).
`review_decorate_test.dart` / `v3_review_decorate_test.dart` updated to the
15-effect vocabulary; two of their cases now pin the portrait surface
(1080×2400@3) because in the default 800×600 landscape test surface the tray is
too short to exercise this tab at all, and the tool-switching test asserts
selection through the Semantics `selected` flag rather than finder presence.

## Performance (emulator-5554, 1080×2400 @ 420 dpi; emulator numbers are upper bounds)

| Metric | Measured |
| --- | --- |
| Full decode of a 3024×4032 capture | 46 MB bitmap in ~50 ms |
| Capped preview decode (same capture) | 5 MB in ~70 ms |
| Four-shot strip bitmaps | 186 MB full vs **21 MB** capped |
| Finish & Save → rendered preview dialog | 3.6 s / 3.7 s (two samples, 0.5–0.7 s poll granularity) |
| Save to Photos → Ready! | 2.8 s |
| Total PSS after export | ~347 MB |

No retained Checkpoint 2 APK exists to diff the size against, so the absolute
figure above is the reference point.

## Artefacts

- `docs/v3/screenshots/checkpoint-3/` — comparison sheets
  (`effects-comparison.png`, `effects-comparison-secondary.png`,
  `effects-intensity.png`) and device captures (`effects-home/review/editor/
  selected/intensity/original.png`), all re-captured after the slider fix.
- `docs/v3/fixtures/reference-capture.jpg` — committed emulator frame the
  comparison sheets are generated from.
- `tool/generate_effects_comparison.dart` — regenerates the sheets.
- `tool/capture_checkpoint3_effects.ps1` — polled, route-verified emulator flow
  driver.

## Limitations

- No physical device: all evidence is from `emulator-5554` (AVD `Medium_Phone`).
  The virtual scene is green-dominated; the synthetic-probe sheet
  (`effects-comparison-secondary.png`) is the better judge of the grades.
- Export timing includes the dialog poll granularity; the true render is
  ~0.5–0.7 s faster than quoted.
- Grain determinism is seeded per-photo and per-recipe; it is deterministic
  across preview/export but not intended to be stable across app restarts.

Nothing has been pushed, merged, published or deployed. The owner's visual
approval of the captures is the remaining gate before Checkpoint 4.
