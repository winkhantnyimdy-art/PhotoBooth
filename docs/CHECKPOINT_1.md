# Checkpoint 1 — Camera and photo geometry

**Status: complete and verified.**

Commit: `50b1fff` · Backup: `C:\Users\jpas\Downloads\PhotoBooth_V2_BACKUP_20261012-153955`

---

## 1. The reported defect: narrow horizontal band with black areas

### Root cause

The stock `CameraPreview` widget derives its box from the **device**
orientation, not from the stream's own dimensions:

```dart
AspectRatio(
  aspectRatio: _isLandscape() ? value.aspectRatio : 1 / value.aspectRatio,
)
```

`CameraValue.aspectRatio` is `previewSize.width / previewSize.height`, and how
the video track is labelled differs by platform:

| Platform | Track dimensions | `aspectRatio` | Portrait flip | Resulting box |
| --- | --- | --- | --- | --- |
| Android / desktop | 1920×1080 (landscape) | 1.778 | 1 / 1.778 = 0.563 | tall — correct by luck |
| **iOS Safari** | **1080×1920 (portrait)** | **0.563** | 1 / 0.563 = **1.778** | **16:9 landscape band** |

On the iPhone 16e the flip produced a 16:9 box inside a portrait viewport, so
the box resolved to roughly 390×219 px with black above and below. This is
exactly the reported symptom, and it is why the defect only showed on Safari.

Two further contributors compounded it:

1. `PhotoStripGeometry.cellAspect` was hard-coded to `1.0` (square cells).
2. The strip renderer **stretched** each photo into the cell
   (`drawImageRect` from the full source rect to the cell rect), so a portrait
   camera frame was squashed into a square — the distorted faces.

### Fix

`lib/features/camera/camera_geometry.dart` (new) — pure, testable maths:

- `streamIsRotated` / `uprightQuarterTurns` — symmetric comparison of *stored*
  orientation vs *shooting* orientation. Landscape-native storage shot in
  portrait rotates a quarter turn; portrait-native storage needs none.
- `uprightAspect` — the upright aspect derived **only** from the frame's own
  dimensions. Landscape- and portrait-native storage of the same scene now
  resolve to an identical portrait aspect.
- `coverSize` — a source drawn at least as large as the viewport on both axes,
  flush on exactly one. This is what removes the letterbox bars.
- `cropWindow` — the centred window with the exported cell's aspect, used for
  the on-screen crop guide and as the single definition of "what is kept".
- `sourceRectForCrop` — maps that window back into captured-frame pixels.
- `coverRect` / `sourceRectForCover` — the shared cover-crop used by the
  renderer so an export is never stretched.

`lib/features/camera/photo_viewfinder.dart` (new) — `PhotoViewfinder` replaces
`CameraPreview` in the viewport. It pins the feed to the upright aspect
explicitly (so a surface with no intrinsic size cannot collapse), applies
`RotatedBox` for orientation, `Transform` mirroring for the front camera only,
and sizes the feed with `OverflowBox` at the cover size inside a `ClipRect`.

`ViewfinderCropGuide` draws the true crop window with rule-of-thirds and shades
the excluded area, so the user can see exactly what will be kept.

`PhotoStripRenderer` now decodes at native aspect (`targetWidth` only) and
cover-crops via `CameraGeometry.sourceRectForCover`. This is what un-squashed
faces.

---

## 2. Layouts

`lib/features/home/layout_model.dart`

| Layout | Label | Grid | Notes |
| --- | --- | --- | --- |
| `korean4` | 4 CUT | 1 × 4 | **default** (`kDefaultPhotoLayout`) |
| `grid4` | 2×2 | 2 × 2 | |
| `pair2` | 2 CUT | 1 × 2 | two-photo layout |
| `cut6` | 6 CUT | 2 × 3 | |
| `cut3` | 3 CUT | 1 × 3 | |

Every layout has a 3:4 portrait cell (`PhotoLayout.cellAspect`), so switching
mid-session never changes the shape of an individual photo.

`PhotoLayout.fitForPhotos(n)` returns the largest layout that can hold `n`
photos — the invariant used so no capture is ever dropped.

All four surfaces (Home card, Camera crop guide, Review grid, Decorate preview,
PNG export) read cells from `PhotoStripGeometry`, which reads the layout, so
they cannot drift apart.

---

## 3. Individual retakes

- `CameraScreen.retakeIndex`: when set, the screen captures exactly **one**
  frame (same countdown and flash) and pops it, instead of running a session
  and navigating to Review. The progress strip is replaced by a
  "Replacing shot N" chip and the header reads "Retake photo N".
- `ReviewScreen` is now stateful and owns the photo list. Photos are selectable
  from both the grid and the thumbnail strip, the caption announces the
  selection, and **Retake replaces only the selected slot**.
- `retakeCameraBuilder` is an injection seam so a test or host can supply a
  configured camera without the review screen knowing about camera plumbing.

Verified by `an individual retake replaces one photo and keeps the rest`: a
retake captures exactly one frame and all four slots remain populated.

---

## 4. Layout switching without losing photos

`_DecorateScreenState._layout` is separate from `DecorationState.layout`.
`_switchLayout` refuses any layout that cannot hold the captured photos, and
stickers/captions are stored in normalised strip coordinates so they carry
over untouched. The switcher is a horizontally scrollable chip row (a plain
`Row` overflowed by 180 px at 320 dp — caught by the existing small-screen
tests).

---

## 5. Export preview

The Korean 4-cut is geometrically ~5.3× taller than wide (four stacked 3:4
cells), so the previous fixed-size `AspectRatio` overflowed the Export screen
and the user could not see the whole strip. The preview is now
`FittedBox(BoxFit.contain)` inside a bounded box, so the composition is always
shown whole.

> **Design note for the owner.** A four-frame vertical stack of portrait cells
> is inherently a long, thin strip. That is geometrically unavoidable and is
> what a physical 4-cut strip looks like, but it means the default layout reads
> as a narrow strip on a phone. The **2×2 grid** produces a much more
> photo-like result and is one tap away in the Decorate layout switcher. I kept
> Korean 4-cut as the default because the specification requires it.

---

## 6. Tests

`flutter analyze` — no issues. `flutter test` — **205 passing** (was 161).

New: `test/camera/camera_geometry_test.dart` (28 tests) and
`test/features/decorate/decorate_layout_switch_test.dart` (6 tests).

Coverage added:

- landscape-native and portrait-native streams, square streams, missing sizes
- rotation decision and upright aspect, including the symmetry case
- full-bleed cover fit across 5 aspects × 3 viewports
- crop windows and camera→export crop alignment, staying inside the frame
- cover-crop never distorts (source sub-rect keeps the source aspect)
- front mirrored / back not mirrored; uninitialised controller paints dark
- both four-photo layouts, the two-photo layout, cell tiling without overlap
- `fitForPhotos` never drops a captured photo
- individual retake captures one frame and preserves the rest
- layout switching keeps photos and never overflows at 320 dp
- every layout's export canvas matches the shared geometry

Two existing tests **encoded the bug** and were updated to the corrected
behaviour:

- `the feed fills the viewport instead of collapsing` asserted
  `feed.width / feed.height == 1920/1080` — i.e. the 16:9 band. It now asserts
  the upright portrait aspect and cover semantics.
- geometry tests asserted square cells and a 2×1 `cut2`.

One real bug was found by a new test: `coverSize` had an **inverted comparison**,
which would have produced bars on the *other* axis. A second real bug —
`sourceRectForCrop` applying the centring offset with the wrong sign — was
caught by the crop-alignment test.

---

## 7. Visual verification

Headless Chrome (synthetic 640×480 camera), full flow
Home → Camera → 4-shot → Review → Decorate → Export → download:

- **Camera**: viewfinder is full-bleed edge to edge, no black bands, 3:4 crop
  guide with thirds visible. This is the direct confirmation of the fix.
- **Export**: whole strip visible, scaled to fit.
- Downloaded PNG: valid signature, 3.2 MB, no console errors or exceptions.

These are **desktop Chrome screenshots**. They do not constitute iPhone Safari
acceptance; physical iPhone verification is still required.