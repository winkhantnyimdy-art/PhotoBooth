# PhotoBooth V3 — Checkpoint 0: Android-Only Rebuild Foundation

**Status:** Complete. Awaiting approval before implementation.  
**Branch:** `photobooth-v3-android` (created from `master` at `41bd295`)  
**Scope:** Audit, architecture plan, specifications, test strategy, risks, roadmap. No production UI or behaviour changed.

---

## 0. Git status and baseline

- Working tree was clean before this checkpoint.
- Branch created: `photobooth-v3-android`.
- Current head remains `41bd295 Checkpoint 6: Android branding and release prep`.
- No signing keys generated, no release artifacts modified, no push/publish/deploy.
- Baseline validation:
  - `flutter analyze` → **No issues found!**
  - `flutter test` → **All tests passed! (406 tests)**
- Emulator availability:
  - `flutter emulators` reports one Android AVD: `Medium_Phone` (Generic, Android platform, **not running**).
  - `flutter devices` currently shows Windows, Chrome, Edge only.
  - Hardware acceleration / AVD readiness still needs launch verification before screenshot capture.

---

## 1. Repository and architecture audit

### Runtime and project metadata

| Item | Value |
| --- | --- |
| Flutter | 3.47.5 (stable), Dart 3.13.4 |
| App name | `photo_booth` (package) / `PhotoBooth` (Android label) |
| Version | `1.0.0+1` |
| Application ID | `com.photobooth.photo_booth` |
| Android min/target/compile SDK | 24 / 36 / 36 |
| Supported test platform for baseline | Desktop Windows (Flutter test runner) |
| Declared production deps | `camera`, `gal`, `share_plus`, `path_provider`, `shared_preferences`, `audioplayers`, `idb_shim`, `web` |

### High-level feature map

```text
lib/
  app/                  Root MaterialApp, AlbumScope bootstrap
  core/
    art/                Shared CustomPainters: stickers, frames, decorations, logo
    filters/            Colour-matrix engine + film grain
    media/              Photo byte loading, preview decode, capabilities
    theme/              Design tokens
  features/
    home/               Layout definitions, geometry, HomeScreen
    camera/             Camera pipeline, session, preferences, sound
    review/             Captured-photo review + retake
    decorate/           Decoration model, frame themes, editor screen
    export/             Renderer, save, share, platform copy
    album/              Offline album store, sessions, migration
    settings/           Preferences and platform copy
  shared/               Surfaces, pressable primitives
```

### Pipeline and ownership

1. `HomeScreen` selects `PhotoLayout`.
2. `CameraScreen` captures `XFile` frames according to layout + session state.
3. `CapturedSession` carries photos into `ReviewScreen`.
4. Review continues into `DecorateScreen` with a `DecorationState`.
5. `ExportScreen` renders/saves/shares via `PhotoStripRenderer`.
6. Optional album persistence (`AlbumService` + `AlbumScope`) stores session + blobs.
7. `SettingsScreen` exposes camera preferences and platform-aware copy.

### Non-destructive edit architecture already present

- `DecorationState` holds configuration only, no rendered bytes.
- Photos remain `XFile`/bytes until export.
- Filter changes are represented by `PhotoFilterType`, `filterIntensity`, `PhotoAdjustments`.
- Stickers/text use normalized coordinates (`0..1`) and affine transforms.
- Undo/redo stores previous `DecorationState` snapshots, capped at 30.
- Album sessions persist `DecorationState` as JSON; re-open rehydrates via `decorationStateFromJson`.

---

## 2. Reusable component inventory

### Design tokens (`lib/core/theme/`)

- `AppColors`: warm cream paper, pop pink, dark workspace, danger/success.
- `AppText`: display/title/body/caption/overline/button/numeric/wordmark.
- `S`, `R`, `AppShadows`, `AppMotion`: spacing, radius, shadows, reduced-motion-aware durations.
- `AppTheme`: Material 3 light theme used by the app.

V3 caveat: token values currently diverge from the locked dark workspace palette in two places (`#151416` vs locked `#101012`; `#221F24` vs locked `#1C1C20`). Normalise after design approval rather than silently changing now.

### Shared UI primitives (`lib/shared/`)

- `AppSurface`, `SectionLabel`, `SoftPanel` (surfaces/sections).
- `PressableScale`.
- `RetroBrand` branding treatment.

### Core rendering and art (`lib/core/art/`)

- `StickerArtwork`: single source of truth for all sticker painting in preview and PNG export.
- `FrameThemePainter` + `FrameThemeSpec`: theme-aware paper, border, accents, wordmark.
- `TextOverlayRenderer`: text painting parity between Decorate and export.
- `FrameDecorations`: frame rail and polish details.
- Deco shapes, scatter, tape, speech bubble, checkerboard, retro stickers.

### Filters and image processing (`lib/core/filters/`)

- `PhotoFilterType` + `ColorMatrix`.
- `PhotoAdjustments`.
- `buildMatrix(filter, intensity, adjustments)`: single matrix entry point.
- `isIdentityMatrix`: skips filter export when identity.
- `FilmGrain` / `FilmGrainOverlay`: procedural seeded grain for preview/export.
- `ui.ColorFilter` wrapper `buildColorFilter`.

### Camera (`lib/features/camera/`)

- `CameraGeometry`: cover crop, crop window, orientation handling.
- `PhotoViewfinder`: actual camera preview replacing stock `CameraPreview`.
- `SessionRunner` / `SessionState`: multi-shot lifecycle.
- `CapturedSession`.
- `CameraPreferences` + `PreferencesService`.
- `SelfieMirroring`.
- `Timing`, `ShutterSoundService`.
- Platform-aware camera errors (`CameraUnavailableReason`).

### Data and export

- `PhotoLayout` / `layout_geometry.dart`: single source of photo-cell geometry for Home, Review, Decorate, export.
- `PhotoStripRenderer`: deterministic PNG, cover crop, matrix + grain + sticker + text parity.
- `ExportService` contract/io/web + platform copy.
- `FrameTheme`, `DecorationState`, `UndoRedoDecoration`.
- Album stack: `AlbumService` contract/io/web, `AlbumScope`, `AlbumStore` io/web, schema-versioned `AlbumRecord`, `AlbumSession`, legacy migration.

---

## 3. Technical debt and risks

1. **Filter collection mismatch:** current enum has 8 presets (`Original`, `Soft Glow`, `Retro Film`, `Vivid Pop`, `Cool Blue`, `Dreamy Pink`, `Film Grain`, `Classic B&W`). Locked V3 requirements ask 15 (`Original`, `Soft`, `Warm`, `Cool`, `35mm`, `Vintage`, `Grain`, `Faded`, `Y2K Flash`, `CCD`, `Tokyo Night`, `Mono`, `Noir`, `Dreamy`, `Classic Film`). The matrix primitives exist, but presets and tests must be migrated carefully.
2. **Enum-driven declarations:** filters and stickers are enums, so adding entries touches every `switch` and tests. Acceptable for V3 initially; consider a small registry/plugin model only if the design demands hot-loading.
3. **Dark palette drift:** existing dark workspace uses `#151416`/`#221F24`; locked product direction says `#101012`/`#1C1C20`. Must decide before visual implementation.
4. **Cross-platform residue:** web album, browser capability, and `idb_shim` code remain. Android-only V3 should preserve until migrated, then delete.
5. **Large widgets:** `decorate_screen.dart` (2334 lines), `camera_screen.dart` (1104 lines), `export` renderer (large), `album_screen.dart` (627 lines). Splitting is required but must avoid behavioural regression.
6. **No golden/visual baseline tests:** 406 tests are unit/widget/flow-oriented. Visual fidelity must be captured via emulator screenshots and human/structural assertion.
7. **Asset gap:** all art is generated through CustomPainter. This is good for parity but means every V3 art requirement must be implemented intentionally rather than imported.
8. **Filter limitations:** colour matrices cannot represent LUTs, halation, vignetting, chromatic aberration, or film-border/fake timestamp unless augmented. Matrix + overlays can cover the locked list but may need additional custom painters.
9. **Release safety:** signing key remains untracked and user-only; no debug fallback; version `1.0.0+1` must not be accidentally bumped during audit.
10. **Potential test brittleness:** existing tests assert `PhotoFilterType.values.length == 8`. V3 filter migration must update this assertion deliberately, never delete it.
11. **Image pipeline performance:** premium multi-filter thumbnails and export at retina scale must be checked on device, especially grain density.
12. **Dark/light theme mismatch:** `AppTheme` currently light-only cream theme even though workspace screens paint dark custom surfaces. V3 may require a coherent dark theme or screen-level dark styling.

---

## 4. Current test coverage (baseline)

- 31 test files / 406 passing tests.
- Strong coverage:
  - design system tokens.
  - layout geometry and camera geometry.
  - captured session runner and camera preferences.
  - selfie-mirroring and orientation.
  - filter matrix mathematics and identity/strength invariants.
  - decoration model, editing, layouts, frame options, visibility.
  - album persistence/reopen/migration/session.
  - review and decorate behaviours.
  - export screens/platform copy/responsiveness/rendering/filters.
  - Android branding.
  - capture flow and compact layout.
- Coverage gaps for V3:
  - new filter presets and adjustment stacking.
  - preview/export pixel parity at matrix and grain level.
  - sticker manipulation and renderer parity under rotation/scale.
  - text editing and export parity.
  - dark screen visual structure / accessibility.
  - 320/375/390/430 dp + text scale.
  - performance on emulator.

---

## 5. Emulator / device strategy

- Available baseline: `Medium_Phone` Android AVD.
- It was not running; launch it in the next implementation phase before any screenshot capture.
- Web/Chrome targets are intentionally out of scope for V3, although Flutter test still runs on Windows.
- Build verification required later: `flutter build apk --debug`.

---

## 6. V3 architecture plan

### 6.1 Platform strategy

- Android only. Keep `camera`, `camera` Android integration, `gal`, `share_plus`, `path_provider`.
- Remove web/iOS dependencies incrementally, only after replacements are verified.
- Preserve package, app ID, signing config, version until a deliberate release bump is approved.
- Continue offline-first: no backend, no accounts, no cloud.

### 6.2 Design system target

- Home: warm cream/paper surface (`#FFF7F0` / `#FFFDF8`) per design reference.
- Camera/Review/Decorate/Export: near-black immersive workspace.
- Proposed canonical dark workspace:
  - background `#101012` (locked direction; resolves current `#151416` drift)
  - surface `#1C1C20`
  - primary controls white
  - accent soft silver
- Camera shutter accent should remain bright pink only if the approved A+C+F design requires; lock final token names in the first implementation checkpoint.
- Touch targets minimum 48 dp (`S.touchTarget`).
- Portrait-first. Portrait widths to validate: 320, 375, 390, 430 dp + text scaling.

### 6.3 State flow

1. `HomeScreen` → select layout.
2. `CameraScreen` → capture/re-take.
3. `ReviewScreen` → approve/retake.
4. `DecorateScreen` (5 tabs: Filters, Frames, Stickers, Text, Adjust) → non-destructive configuration.
5. `ExportScreen` → shared renderer → Save (`gal`) / Share (`share_plus`) / optional album.

`DecorationState` remains the single transport model from Decorate to Export and persisted album sessions.

### 6.4 Renderer parity contract

For every V3 effect:

- Preview must apply the exact same transform math as export.
- Filter preview uses `buildColorFilter` via `ColorFiltered`; export uses identical `buildMatrix` via `Paint.colorFilter`.
- Grain `FilmGrain.paint` is used by both.
- Stickers use `StickerArtwork.paintSticker`.
- Text uses `TextOverlayRenderer.paint`.
- Geometry comes only from `PhotoStripGeometry`.

### 6.5 Non-destructive edit integrity

- Never mutate captured bytes.
- Filter/sticker/text changes only update `DecorationState`.
- Preview at exact export geometry.
- Export derives from state, photos, theme, stickers, text.
- Album persistence stores photos + state, not rendered export bytes.
- Before/after filter comparison can be implemented by temporarily selecting `PhotoFilterType.original` at intensity 0 for one side without modifying state.

---

## 7. Detailed screen specifications

### 7.1 Home

- Purpose: brand identity, layout selection, entry point.
- Surface: warm paper.
- Components:
  - bubble wordmark (original art).
  - layout cards with geometry previews (square photo cells).
  - primary CTA to start capture.
  - sparse hand-drawn cherries/hearts.
- Behaviour:
  - default layout remains `korean4` (`4 CUT`) unless data dictates otherwise.
  - selected layout drives all downstream screens.
- Acceptance:
  - 320–430 dp stable, no overflow.
  - layout preview aspect equals exported cell aspect.
  - tests validate card geometry and selection.

### 7.2 Camera

- Surface: immersive dark.
- Required controls:
  - top: back, camera switch, preferences/flash/timer as needed.
  - centre preview nonzero height, letterboxed correctly.
  - bottom: shutter, thumbnail/progress, cancel/retake.
- Invariants:
  - live camera preview must not collapse or letterbox incorrectly.
  - multi-shot session.
  - front camera mirroring platform-aware default.
  - capture sound optional and non-blocking.
- Acceptance:
  - preview remains visible on all widths.
  - crop guide matches export cell geometry.
  - capture count updates visibly.

### 7.3 Review

- Surface: dark framing around photos.
- Layout: centered multi-shot grid from layout geometry.
- Controls: Retake (all/individual), Next.
- Behaviour:
  - individual retake launches Camera in retake mode and swaps one photo only.
  - no overlays obscure actual shots.
- Acceptance:
  - grid uses actual frames, not mock portraits.
  - retake preserves other photos and decoration.

### 7.4 Decorate

- Tabs: Filters, Frames, Stickers, Text, Adjust.
- Preview above compact persistent tray.
- Filters:
  - real color filter preview at intensity 0–100.
  - thumbnails (can be generated on the fly).
  - grain indicator.
- Frames:
  - existing 8 frame themes, paper colour + border + accents.
- Stickers:
  - 17 curated sticker types plus manipulation (move/scale/rotate).
- Text:
  - add/edit/move/scale/color.
- Adjust:
  - brightness, contrast, saturation, warmth sliders.
- Acceptance:
  - slider intensity updates live.
  - export uses identical rendering.
  - controls reachable on 320 dp.
  - undo/redo and reset function.

### 7.5 Export / Save & Share

- Surface: dark gallery-style.
- Prominent primary Save, secondary/ dark Share.
- Shows final photo print.
- Robust save/share errors and platform-aware copy.
- No unverified HD/watermark claims.
- Acceptance:
  - saving works via MediaStore/gallery.
  - share sheet works.
  - rendered output matches preview.
  - dark frame styles legible.

---

## 8. Effects engine design (interfaces and non-destructive state)

### 8.1 Filter preset interface (proposed V3)

Replace hard-coded 8-value enum with a versioned preset catalogue. Keep current implementation as the base engine.

```dart
sealed class FilterPreset {
  const FilterPreset(this.id, this.label);

  final String id;
  final String label;

  bool get hasGrain => false;
  List<double> get matrix; // full-strength 4x5 matrix

  Widget previewBuilder(...); // optional thumbnail
}
```

Catalogue (locked):

| ID | Display | Underlying engine notes |
| --- | --- | --- |
| `original` | Original | identity |
| `soft` | Soft | highlight lift + gentle blur overlay? matrix + optional bloom |
| `warm` | Warm | temperature positive, slight saturation |
| `cool` | Cool | temperature negative |
| `35mm` | 35mm | warm, slight contrast, subtle grain |
| `vintage` | Vintage | faded, sepia-ish, lowered contrast, vignette overlay |
| `grain` | Grain | contrast + seeded grain |
| `faded` | Faded | lifted blacks, reduced contrast, desaturation |
| `y2kFlash` | Y2K Flash | bright flash, cool/neutral, punchy contrast |
| `ccd` | CCD | harsh high contrast, slight blue/yellow |
| `tokyoNight` | Tokyo Night | cool blue + magenta neon lift |
| `mono` | Mono | grayscale |
| `noir` | Noir | high-contrast grayscale + vignette |
| `dreamy` | Dreamy | soft glow + pink tint + blur halo |
| `classicFilm` | Classic Film | warm, faded, grain, film border effect |

Implementation rule: each preset’s full matrix must be tested; intensity is always interpolated against identity using `ColorMatrix.lerp`; strength 0 must equal identity.

### 8.2 Adjustments (existing)

Keep `PhotoAdjustments`:

- `brightness`, `contrast`, `saturation`, `warmth` in `-1..1`.
- Neutral defaults.
- Compose after preset.

Possible V3 extras (leave optional): `vignette`, `halation`, `fade`, `sharpness`. Do not add until needed; complexity must remain testable.

### 8.3 Frame/filter state

`DecorationState` already carries:
- `filter`
- `filterIntensity`
- `adjustments`
- `frameStyle`
- `frameTheme`
- `stickers`
- `texts`

V3 additions:
- filter catalogue version string for migration.
- maybe selected sub-effect parameters.
- lock font/color persistence in `TextPlacement`.
- sticker effect presets? not required.

### 8.4 Before/after comparison

- Add a preview-only toggle `showOriginal` that renders `ColorFiltered` with identity matrix over photos but does **not** mutate `DecorationState`.
- Camera preview comparison can be horizontal split if feasible; but primary Decorate compare is required first.

### 8.5 Preview/export consistency tests

- `buildMatrix` deterministic.
- matrix at intensity 0 equals identity for all presets.
- export applies identical matrix.
- grain active only when preset `hasGrain` or secondary grain explicitly enabled.
- export dimensions based only on layout.

---

## 9. Android testing strategy

- Static: `flutter analyze`, `dart format`.
- Unit:
  - filter catalogue count/labels/matrix determinism.
  - intensity 0 identity.
  - geometry cell aspect/cover crop.
- Widget/flow:
  - all existing 406 tests must remain passing after refactors.
  - new tests for decorate tabs, sliders, text edit, sticker interactions.
- Emulator:
  - launch `Medium_Phone`.
  - capture screenshots for Home/Camera/Review/Decorate/Export.
  - run debug APK install/start.
- Performance:
  - measure export duration and memory.
  - thumbnail generation.
- Accessibility:
  - minimum touch targets.
  - text scaling up to 1.3x.
- Device coverage:
  - widths 320/375/390/430 dp.
- Regression gates:
  - no change to app ID/version/signing.
  - album persistence round trip after edits.

---

## 10. Risk assessment

| Risk | Severity | Mitigation |
| --- | --- | --- |
| Breaking existing 406 tests during filter migration | High | Update assertions only with documented reason; keep geometry/filter invariants. |
| Filter preset drift between preview and export | High | Single `buildMatrix`; shared matrix applied both places; parity tests. |
| UI rewrite destabilizes camera lifecycle | High | Touch camera only when necessary; reuse `SessionRunner`; add regression tests. |
| Oversized widget refactor causes state loss | Medium | Split incrementally; no all-at-once rewrite. |
| Visual mismatch to design | Medium | Screenshot comparison loop; tokens first. |
| Emulator not available/broken | Medium | Verify early; use physical device if needed. |
| Large generated art stalls frames | Medium | Cap grain density; simplify first; test. |
| Web leftovers obscure Android path | Low | Leave working until dedicated cleanup checkpoint. |
| Dark palette change conflicts with theme art | Medium | Approval before final token normalisation. |
| Filter requirement implies effects beyond matrices | Medium | Implement matrix-compatible approximation first; document deviations. |

---

## 11. Checkpoint roadmap

1. **Checkpoint 0 (this document):** audit + plan. Complete pending approval.
2. **Checkpoint 1:** design-token normalisation + new FilterPreset abstraction + migrated catalogue + tests.
3. **Checkpoint 2:** Home screen visual redesign + layout card polish + theme/accessibility validation.
4. **Checkpoint 3:** Camera screen visual redesign while preserving camera lifecycle + crop guide.
5. **Checkpoint 4:** Review screen redesign + individual retake validation.
6. **Checkpoint 5:** Decorate screen: five compact tabs, real filters/intensity/adjust, sticker/text editing.
7. **Checkpoint 6:** Export visual + Save/Share reliability + preview/export parity tests.
8. **Checkpoint 7:** Album/Settings polish + Android-only cleanup.
9. **Checkpoint 8:** QA pass: analyze, tests, debug APK, emulator screenshots, performance/accessibility.
10. **Checkpoint 9:** local commit sequence, no push/publish.

### Acceptance criteria per stage gate

- Stage gate 0→1: manual approval.
- Each following gate requires `flutter analyze` and `flutter test` pass.
- Dark UI screenshots compared against premium reference.
- No regression of capture/export/album/save/share.

---

## 12. Boundaries honored

- No rebuild performed.
- No existing production functionality modified.
- No signing key changes.
- No release/publish/deploy.
- Emulator screenshot capture deferred until implementation phase.
- All current baseline results reported exactly: analyze clean; 406 tests passed.