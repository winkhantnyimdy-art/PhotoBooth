# PhotoBooth V3 — Checkpoint 3 plan: professional effects engine

**Status:** plan approved-by-self, implementation follows. Baseline `4df30a3`.

---

## 1. Audit of the existing pipeline

There is already **one** pipeline, and it is sound. It is extended, not replaced.

| Stage | Existing mechanism | Reusable? |
| --- | --- | --- |
| Presets | `PhotoFilterType` enum, 8 values, each a 4×5 `ColorMatrix` | yes, extended to 15 |
| Maths | `ColorMatrix` helpers (`saturation`, `contrast`, `brightness`, `temperature`, `pinkTint`, `multiply`, `lerp`) | yes, extended |
| Intensity | `ColorMatrix.lerp(identity, preset, t)` | yes, kept — guarantees 0 % ≡ Original |
| Preview | `ColorFiltered(colorFilter: ColorFilter.matrix(m))` in both the thumbnail and `_Composition` | yes |
| Export | `ui.Paint()..colorFilter = ui.ColorFilter.matrix(m)` in `_drawFramedImage` | yes |
| Grain | `FilmGrain.paint` (canvas) + `FilmGrainOverlay` (widget) | **needs fixing** |
| Adjustments | `PhotoAdjustments` (brightness/contrast/saturation/warmth) | yes |
| Undo/redo | `UndoRedoDecoration` snapshots whole `DecorationState` | yes |
| Persistence | `decorationStateToJson` / `FromJson` | needs a legacy key |
| Decode | `PreviewDecode` caps preview decodes; `PhotoImage`/`PhotoStripRenderer` share Flutter's EXIF-aware decoder | yes |

### Defects found in the existing pipeline

1. **Grain is not preview/export consistent.** Preview used `seed: 0`; export used
   `seed: exportWidth` (1200). The two produced different noise patterns.
2. **Grain is not scale-normalised.** Speck radius was `0.5–1.4 px` at every size,
   so a 64 px thumbnail and a 576 px export cell had visibly different grain.
3. **Grain specks are capped at 2600**, so a large export region is grainier per
   unit area than a small one.
4. **Only 8 presets, and several are near-duplicates** (`softGlow` vs
   `dreamyPink`; `classicBw` vs `filmGrain`).
5. **`ColorFilter` cannot blur**, so nothing resembling bloom or glow is possible
   in the current preview path.

---

## 2. Architecture

```
PhotoEffect (15 stable ids)
        │
        ▼
resolve(effect, intensity, adjustments) ──► EffectRecipe { matrix, grain, bloom }
        │                                        │
        ├─ preview: ColorFiltered + EffectGrainOverlay + BlendMask(bloom)
        └─ export : Paint.colorFilter + EffectGrain.paint + Paint(blendMode: screen)
```

One recipe, one order: **colour matrix → grain → bloom**, applied to the photo
cells only, then stickers, then text, then the footer. Frames and paper are
untouched by effects, exactly as today.

### Decisions

- **Extend, don't fork.** `buildMatrix` stays the single matrix entry point.
- **Stable identifiers.** Enum `.name` is the persisted id.
- **Legacy compatibility.** The old 8 `PhotoFilterType` values stay readable so
  albums saved by v1.0.0 still open.
- **No shaders, no new packages.** Bloom is a blurred second pass composited
  with `BlendMode.screen`, which is available on both `Canvas` and the widget
  tree. Screen blending only lifts midtones/highlights, which is the glow
  behaviour we want, and it needs no custom fragment program.
- **Honesty.** These are digital simulations built from a colour matrix,
  deterministic grain and bloom. They are not scanned film stock, and the UI
  says so.

---

## 3. Effect catalogue

| # | id | Family | Signature |
| --- | --- | --- | --- |
| 1 | `original` | Essential | identity, zero cost |
| 2 | `soft` | Essential | lifted contrast, highlight roll-off |
| 3 | `warm` | Essential | positive temperature, mild saturation lift |
| 4 | `cool` | Essential | negative temperature |
| 5 | `mm35` | Film | warm, gentle contrast, fine grain |
| 6 | `vintage` | Film | sepia-lean warm shadows, low contrast, grain |
| 7 | `grain` | Film | neutral tone, strong deterministic grain |
| 8 | `faded` | Film | raised blacks, reduced saturation |
| 9 | `classicFilm` | Film | balanced analogue curve, warm, light grain |
| 10 | `y2kFlash` | Digital | blown highlights, cool shadows, bloom |
| 11 | `ccd` | Digital | early-digital punch, slight cyan/green cast |
| 12 | `tokyoNight` | Digital | cool base, magenta/cyan separation |
| 13 | `mono` | Artistic | balanced luminance conversion |
| 14 | `noir` | Artistic | high-contrast luminance, crushed blacks |
| 15 | `dreamy` | Artistic | bloom, lifted blacks, pink-lifted shadows |

### Distinguishability strategy

The catalogue is not 15 tints of the same thing:

- **Mono/Noir** are the only fully desaturated pair, and Noir additionally
  inverts and crushes, so they are separable by contrast alone.
- **Grain** is the only preset whose dominant signature is noise.
- **Dreamy/Y2K Flash/Soft** are the only presets with a bloom layer.
- **Warm/Cool** are the only near-neutral presets (±temperature, no grain).
- **Tokyo Night** is the only one with a two-sided colour cast.
- Remaining film presets differ in tone-curve direction, not just hue.

This is enforced by a test that asserts **pairwise matrix distance**, so
"fifteen nearly identical overlays" cannot reappear silently.

---

## 4. Implementation order

1. `photo_effect.dart` — enum, recipe, resolve, legacy mapping.
2. `effect_layers.dart` — scale-normalised deterministic grain + bloom sigma.
3. `photo_filter.dart` — extra matrix helpers; `PhotoFilterType` → legacy.
4. `decoration_model.dart` / `album_session.dart` — type change + legacy JSON.
5. `decorate_screen.dart` — thumbnails, strength slider, bloom in `_Composition`.
6. `photo_strip_renderer.dart` — apply the recipe.
7. Tests, then comparison sheets, then emulator capture.