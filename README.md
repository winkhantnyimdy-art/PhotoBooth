# PhotoBooth

A mobile-first, Japanese/Korean-inspired photo booth app. Offline-first, no
account, no backend: photos stay on the device.

## Status

**Checkpoint 6 — visual redesign and UX polish.** The full capture flow works
end to end: choose a layout → Camera → Countdown/Auto Capture → Review/Retake →
Decorate → Save/Share.

## Product flow

Choose layout → Camera → Countdown/Auto Capture → Review/Retake →
Decorate → Save/Share

## Architecture

```
lib/
  app/            Root widget, theme wiring
  core/
    theme/        Centralized visual tokens (color, type, spacing, radius,
                  shadow, motion, theme)
  features/
    home/         Brand, layout selection, layout geometry source of truth
    camera/       Camera preview, countdown, multi-shot capture
    review/       Captured photos, retake / continue
    decorate/     Frame, style, stickers, date
    export/       Rendering, gallery save, share sheet
  shared/         Cross-feature reusable widgets
```

## Design tokens

Visual values live in `lib/core/theme/` and must be used from there rather
than hard-coded in widgets:

- `app_colors.dart` — cream canvas, pastel pink accents, charcoal text, status
  colours, surfaces and scrims
- `app_typography.dart` — type roles from `display` down to `overline`
- `app_spacing.dart` — spacing scale (`S.xxs` … `S.xxl`) plus the page gutter
  and minimum touch target
- `app_radius.dart` — rounded shape scale (`R.sm` … `R.xl`, `R.pill`)
- `app_shadows.dart` — soft, low-contrast elevation tokens
- `app_motion.dart` — duration/curve tokens that collapse to zero when the
  platform requests reduced motion
- `app_theme.dart` — Material 3 light theme built from the tokens above

`lib/shared/` provides the card/section primitives (`AppSurface`,
`SectionLabel`, `SoftPanel`) and `PressableScale` for press feedback.

## Layout geometry

`lib/features/home/layout_geometry.dart` is the single source of truth for how a
layout maps onto a strip. The Home card, Review grid, Decorate preview and the
exported PNG all derive their cells from it, so the arrangement a user picks is
exactly the arrangement that gets rendered. Photo cells are square by design,
which keeps captured photos from being stretched.

## Dependencies

`camera` for capture, `gal` for saving to the gallery, `share_plus` for the
share sheet, `path_provider` for staging files. No networking, no state
management package, no navigation library, no image or font assets.

## Platforms

- Android — created
- iOS — created (structure preserved; build verification requires macOS)

Web/PWA is intentionally not scaffolded.

## Getting started

```sh
flutter pub get
flutter run
```

## Verification

```sh
dart format .
flutter analyze
flutter test
```
