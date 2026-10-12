# PhotoBooth Premium — Retro Film Pop: implementation blueprint

## Source of truth
`reference_full.png` is the **approved A + C + F composite**. `screens/` contains five crops from that exact image. These are **visual references, not executable layouts**; cropping preserves mockup device chrome. `assets/` contains reference crops, **not ready-to-ship transparent stickers**.

## Visual hierarchy
- Home: cream/paper surface, distinctive pink outlined bubble wordmark, layered photo-collage previews, sparse hand-drawn cherries/hearts, pink rounded CTA, compact layout cards. Preserve actual existing layouts rather than blindly copying the mockup's illustrative 4/6/9 options.
- Camera: full working camera texture on near-black, compact top controls, bright pink circular shutter, thumbnail/progress. Keep preview nonzero height, letterbox correctly. No fake portrait background.
- Review: near-black framing, centered multi-shot grid, compact Retake/Next actions. No overlays that obscure actual shots.
- Decorate: near-black editor, preview above compact 5-tab tool tray: Filters, Frames, Stickers, Text, Adjust. Genuine pixel/color filter previews and intensity, not decorative-only effects. Controls reachable on small screens; export uses matching sticker geometry/artwork.
- Export: near-black gallery-style display, visible photo print, prominent pink Save and dark Share, no unverified HD/watermark claims. Keep existing saving and sharing robust.

## Original artwork requirements
Create original reusable assets (SVG/CustomPainter/raster as appropriate) for pink bubble wordmark, cherries, bows, bunny, hand-drawn hearts, stars, photo-paper and film-edge patterns, tape, handwriting badges. Reuse a single source of sticker paths for preview and PNG renderer; avoid generic icon substitutions. All assets should be original or appropriately licensed. The reference crop images themselves are **not** assets to place as UI screenshots.

## Filters
Presets: Original, Soft Glow, Retro Film, Vivid Pop, Cool Blue, Dreamy Pink, Film Grain, Classic B&W. Support strength 0–100, instant preview, and equivalent final PNG processing; test that strength 0 equals Original and outputs are deterministic for fixed inputs. Avoid changing facial structure or claiming beauty correction.

## QA and acceptance
- Start by inspecting git status and preserving uncommitted work; known reported repair commit `d25452c` is context, not a guarantee of local HEAD.
- Build a side-by-side screenshot comparison for each of five screens at 390dp, then test 320/375/430dp and text scaling. Use emulator automation where feasible.
- Functional invariants: live camera preview, multi-shot, Retake, navigation, sticker editing, PNG export, Save, Share. Existing tests may need *legitimate* UI updates but never remove meaningful assertions.
- Distinguish mockup artwork from real photos. Never ship the sample portraits embedded in the concept as app assets.
- Automated pixel matching is not meaningful for live camera imagery; compare structure, color, component positions, and art. Record mismatches in a report.
- Gate each stage: baseline → art assets → one screen at a time → visual comparison → tests → local commit. No push/publish/deploy.

## Known limits
A generative concept has inconsistent geometry and illegible small type. Aim for close visual fidelity while preserving usable native controls, accessibility, and true functionality. No claim of exact pixel parity without measured evidence.
