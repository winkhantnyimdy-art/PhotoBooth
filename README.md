# PhotoBooth

A mobile-first, Japanese/Korean-inspired photo booth app. Offline-first, no
account, no backend: photos stay on the device.

## Status

**Checkpoint 0 — foundation only.** This repository currently contains the
Flutter application shell, the centralized theme, and empty feature
scaffolding. No camera, capture, decoration, or share functionality exists
yet.

## Product flow (target)

Choose layout → Camera → Countdown/Auto Capture → Review/Retake →
Decorate → Save/Share

## Architecture

```
lib/
  app/            Root widget, theme wiring
  core/
    theme/        Centralized visual tokens (color, radius, spacing, theme)
  features/
    home/         Initial screen with branding
    camera/       Stub — capture flow
    review/       Stub — retake / accept
    decorate/     Stub — filters, frames, stickers, text
    export/       Stub — save / share
  shared/         Cross-feature reusable widgets
```

## Design tokens

Visual values live in `lib/core/theme/` and must be used from there rather
than hard-coded in widgets:

- `app_colors.dart` — cream background, soft pink accent, charcoal text
- `app_radius.dart` — rounded shape scale (`R.sm` … `R.xl`, `R.pill`)
- `app_spacing.dart` — spacing scale (`S.xs` … `S.xxl`)
- `app_theme.dart` — Material 3 light theme built from the tokens above

## Dependencies

None beyond the Flutter SDK and `flutter_lints`. No camera package, no
networking, no state management, no navigation library.

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
