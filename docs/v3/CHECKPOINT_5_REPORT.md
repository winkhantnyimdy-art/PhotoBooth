# Checkpoint 5 Report — Creative Experience

Branch: `photobooth-v3-android`
Baseline: `6086fe0` (Checkpoint 4B)

## Audit summary

- Effects: 15 presets already implemented in `PhotoEffect` with deterministic
  colour matrices, optional grain and bloom. `EffectRecipe.resolve` blends toward
  identity by intensity and composes manual adjustments. Preview and export use
  the same recipe, grain seed, and bloom sigma, so pixels match by construction.
- Frames: 8 `FrameTheme` identities plus 4 `FrameStyle` borders, painted by the
  same `FrameThemePainter` in preview and export. Themes already cover the
  requested Minimal White, dark film, pink, retro/vintage, and cream styles.
- Editing: horizontal filter shelf, intensity slider 0-100%, compare-on-hold,
  undo/redo, frame switching, and reset affordances already exist.
- Adjustments and frames are persisted in album sessions and restored on reopen.

## Changes in this checkpoint

- Added an explicit "Reset to Original" control in the Filters panel that
  restores Original with full strength, recorded in undo history.
- No rendering-pipeline rewrite; preview/export parity preserved.

## Verification

- `flutter analyze`: No issues found!
- `flutter test`: 524 passed, 0 failed
- `flutter build apk --debug`: success
- Screenshots: `docs/v3/screenshots/checkpoint-5/`

## Remaining limitations

- Emulator-only verification.
- No new effect or frame enum values were added, to preserve the documented
  15-effect engine and saved-session compatibility.
- Pre-existing untracked `tool/emu_pinch.ps1` left untouched.
