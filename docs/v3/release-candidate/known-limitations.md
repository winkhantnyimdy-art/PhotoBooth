## Known limitations
- Physical-device camera validation NOT performed (emulator-only). Real-sensor framing/mirroring, low-end performance, API 24-9 storage behaviour, release signing on device remain open.
- dumpsys gfxinfo frame statistics non-functional on this Flutter/Impeller build.
- Pinch-zoom in the strip inspector covered by widget tests; drag-to-zoom-pan demonstrated on device.
- Open polish (P2/P3): sticker shelf overlap on short viewports (F3), layout-chip swipe affordance at 320dp (F4), album title ellipsis (F5), top-bar a11y labels (F6), landscape camera letterboxing (F7).
- Environment: clean-install RC AVD camera HAL needed a "Try again" retry before exposing a virtual camera.
