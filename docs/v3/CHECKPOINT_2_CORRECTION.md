# PhotoBooth V3 — Checkpoint 2 correction: Camera orientation, framing, editor cleanup

**Status:** Complete, committed locally. Awaiting owner visual approval.

---

## 1. Root causes

Three distinct defects, found by measurement rather than inspection.

### A. The preview was rotated 90° (double rotation)

`PhotoViewfinder` computed `CameraGeometry.uprightQuarterTurns()` from
`controller.value.previewSize` and wrapped the feed in `RotatedBox(1)`.

But on Android the `camera` plugin already returns an **upright** feed:

* `PreviewProxyApi` calls `builder.setTargetRotation(display.rotation)`.
* `buildPreview()` wraps the texture in `RotatedPreviewDelegate`, which exists
  purely to "rotate the camera preview to be upright according to the current
  user interface orientation". On Impeller it takes the
  `SurfaceTextureRotatedPreview` branch, whose correction in portrait is `0`
  because the `SurfaceProducer` already rotated the surface.

Runtime values captured on the emulator (API 37) proved the branch:

```
previewSize=Size(1280.0, 720.0)   aspectRatio=1.7778   sensorOrientation=270
```

So the app rotated an already-upright feed — turning the viewfinder sideways.

### B. Every exported photo was squashed

`CameraGeometry.sourceRectForCover` mapped the surviving destination rect back
into source pixels with `source / target`. That is only correct when the
source and target already share an aspect ratio. When they differ:

1. `coverRect` produces a **centred, overflowing** rect.
2. Intersecting it with the target collapses it back to the whole target.
3. Scaling the whole target by `source / target` returns **the entire source
   image**.

`drawImageRect` then stretched that full image into the cell. A 9:16 phone
capture (720×1280) was squeezed into the 3:4 export cell on every frame. The
correct mapping is `source / drawn` with `drawn`'s origin subtracted.

The existing test asserted `src.width / src.height ≈ source aspect` — which
returning the whole source satisfies trivially. It never checked that the
region matched the **target**, which is the invariant that matters for
`drawImageRect`. That assertion has been replaced with the correct one.

### C. The capture path was already correct

CameraX writes a 1280×720 JPEG with `EXIF Orientation = 8`. Flutter's decoder
honours EXIF, so `instantiateImageCodecFromBuffer` yields **720×1280 portrait**,
and both `PhotoImage` (`Image.file`) and `PhotoStripRenderer` go through that
decoder. Measured: capture axis vertical (upright), so A and B were the whole
story — no EXIF rewriting was needed and none was added.

### D. The "large preview with a small white rectangle"

`PhotoViewfinder` cover-fitted the feed onto a 3:4 *crop window* centred inside
a taller viewport, and `ViewfinderCropGuide` painted a white rounded rect plus a
34 % black scrim over everything outside it. The visible feed therefore showed
far more than survives the export, and the white box was the only cue for which
part mattered.

---

## 2. Changes

| File | Change |
| --- | --- |
| `lib/features/camera/camera_geometry.dart` | New `PreviewOrientation` policy (who owns rotation, and what aspect is presented). Fixed `sourceRectForCover` to scale by `source / drawn` and subtract `drawn`'s origin. |
| `lib/features/camera/photo_viewfinder.dart` | Applies **no** app rotation when the platform already rotates; presents the upright stream; cover-fills its box instead of a crop window; optional overlay retained. |
| `lib/features/camera/camera_screen.dart` | The viewfinder box is itself the exported cell aspect, so the framed rounded rect **is** the saved crop. Crop guide removed. |
| `lib/features/decorate/decorate_screen.dart` | Selected layout chip is a white outline on a dark fill instead of a solid white pill. |
| `test/camera/orientation_regression_test.dart` | New: 29 tests (rotation ownership, 0/90/180/270, mirroring, crop framing, export squash, viewport sizing). |
| `test/camera/camera_geometry_test.dart` | Cover-crop invariant corrected; viewfinder rotation expectations replaced with the corrected contract; non-Android fallback still covered. |
| `test/features/capture_flow_test.dart` | Flash now asserted against the preview frame (its actual parent) and the frame's 3:4 shape. |

---

## 3. Verification

| Check | Result |
| --- | --- |
| `flutter analyze` | No issues found |
| `flutter test` | 478 passed (469 → 478) |
| `flutter build apk --debug` | Built and installed |

### Measured on the emulator (Android 17, `Medium_Phone`)

| Stage | Before | After |
| --- | --- | --- |
| Live preview axis | HORIZONTAL → sideways | **VERTICAL → upright** |
| Live preview box aspect | 0.628 | **0.750** (= exported cell) |
| Review cells (4) | squashed | **0.748 each, all upright** |
| Decorate strip cells (4) | squashed | **all upright** |
| Camera / Review / Decorate pink pixels | — | **0 / 0 / confined to the strip** |

Retake → Review → Decorate was driven end-to-end on the device
(`tool/verify_retake_flow.ps1`): selecting photo 2, retaking it, and confirming
all four cells still exist afterwards.

---

## 4. Remaining limitations

- **No physical device was tested.** Orientation was verified against the
  emulator's synthetic scene only. A device with a different sensor
  orientation (90 vs 270) exercises the same code path but is unverified.
- Sensor-relative behaviour on real hardware (e.g. a device where CameraX
  crops to the surface aspect) was not observed.
- The emulator's virtual scene is a room with a horizontal light gradient; it
  has no printed "TOP" label or asymmetric marker, so the orientation evidence
  is a brightness-axis measurement rather than a readable landmark.
- Export, Album and Settings still use Retro Pop styling.
- The 15-effect collection is not started.