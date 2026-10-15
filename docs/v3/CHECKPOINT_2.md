# PhotoBooth V3 — Checkpoint 2: Review & Decorate rebuild

**Status:** Complete, committed locally. Awaiting owner visual approval.

---

## 1. Screens rebuilt

| Screen | Change |
| --- | --- |
| Review | Minimal Dark header, 2×2 photo grid for 4 CUT, no thumbnail strip, no polka dots / Retro stickers / bubble logo, white primary action |
| Decorate | Viewport-derived strip sizing, bounded toolbar (32% of screen), pinch-zoom with a Fit control, Minimal Dark tabs, white primary action |
| Camera | Bottom-right switch control contrast fixed; top-bar buttons given accessibility labels |
| App shell | `SystemUiOverlayStyle` for light status/navigation icons |

### Files changed

- `lib/app/app.dart` — `App.darkSystemBars` + `AnnotatedRegion` around `MaterialApp`
- `lib/features/review/review_screen.dart` — full rewrite
- `lib/features/decorate/decorate_screen.dart` — shell rebuild (build/topbar/preview/tray/tabbar/done)
- `lib/features/camera/camera_screen.dart` — control contrast + `_CircleButton` semantics
- `test/features/capture_flow_test.dart` — selection surface moved from thumbnails to grid cells
- `test/features/v3_review_decorate_test.dart` — new (32 tests)
- `tool/capture_checkpoint2_screenshots.ps1` — new

### Reusable components used

`MinimalIconButton`, `MinimalPrimaryButton`, `MinimalSectionHeading`, `PressableScale`,
plus the existing `PhotoStripGeometry` / `PhotoImage` / `PreviewDecode`.

---

## 2. Layout decisions

**Review.** A 4 CUT session exports a 1×4 column, which cannot be shown at a
useful size on a portrait phone. Review therefore presents the frames in a
balanced 2×2 grid while keeping the **exported 3:4 cell aspect** and
cover-cropping each photo exactly as the renderer does. Multi-column layouts
keep their own arrangement (6 CUT stays 2×3). Photo bytes are never touched.

**Decorate.** The preview is `Expanded` and sized by `AspectRatio` from the
live viewport; the toolbar is a bounded 32% of screen height. The strip is no
longer hard-coded and no longer fights a 5:6 flex split.

---

## 3. Verification

| Check | Result |
| --- | --- |
| `flutter analyze` | No issues found |
| `flutter test` | 448 passed (406 baseline + 42 new) |
| `flutter build apk --debug` | Built |
| Emulator | Medium_Phone, Android 17 |

### Screenshots (`docs/v3/screenshots/checkpoint-2/`)

- `camera-status-bar.png`
- `review.png`
- `review-after-retake.png`
- `decorate.png`
- `decorate-tools.png`

### Measured from the real screenshots

| Claim | Measurement |
| --- | --- |
| Review is a 2×2 grid | 2 columns × 461 px, 2 rows × 617 px |
| Review cells are undistorted | 461/617 = 0.747 vs exported 0.75 |
| Review grid is centred | top gap 396 px vs bottom gap 365 px |
| Decorate strip fills the preview | 80 × 437 dp, aspect 0.183 vs exported 0.186 |
| Decorate strip is larger than before | 80 dp wide vs ~59 dp pre-checkpoint |
| Status bar readable | 3 845 bright icon pixels on 81 685 dark pixels |
| Camera switch control readable | 54×55 px glyph, ~7.2:1 contrast |
| Screens are distinct | 58–80% of body pixels differ pairwise |

---

## 4. Limitations

- Emulator synthetic camera only; real image quality unverified.
- Pinch-zoom is verified by unit test and code path, not by hand on device.
- Export, Album and Settings still use Retro Pop styling.
- The 15-effect collection is not started.