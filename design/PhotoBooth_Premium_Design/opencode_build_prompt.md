# Paste into OpenCode — PhotoBooth premium reference-driven implementation

You are implementing the **approved A+C+F Retro Film Pop** design in the EXISTING Flutter PhotoBooth app. The attached `PhotoBooth_Premium_Design` folder is the design package.

1. Locate the project at `C:\Users\jpas\Downloads\PhotoBooth`. Inspect `git status --short`, `git log -5 --oneline`, source/tests, and current camera fix. Never reset or discard work. If unexpected dirty files exist, report them and preserve them.
2. Read `PhotoBooth_Premium_Design/screen_specs.md`, `design_tokens.json`, all five `screens/*_reference.png`, and `reference_full.png` **using actual image viewing**. If you cannot access images, stop and request access; do not claim to have seen them.
3. Create original, reusable art assets and a cohesive Flutter design system. The reference images are for visual guidance only; DO NOT embed screenshot crops or mockup portraits as application UI or sample photos. Confirm font/asset licenses.
4. Implement the five screens in order Home, Camera, Review, Decorate, Export. Preserve camera preview layout fix, capture lifecycle, original photo data, save/share, and existing decoration behavior. Add real filters and intensity only with testable parity between preview and export. Do not substitute overlays for real filters.
5. After each screen, launch the emulator, capture an actual screenshot, and compare composition against its corresponding reference. Log mismatches and fix material issues before proceeding. For camera/photographs compare UI chrome/geometry, not scene pixels.
6. Keep work scoped and commit in **separate small verified commits**. Do not let a large all-at-once rewrite hide regressions. Add focused tests for new filter rendering and sticker parity. Validate 320/375/390/430dp and text scaling.
7. Run `dart format .`, `flutter pub get`, `flutter analyze`, `flutter test`, `flutter build apk --debug`. All must pass before declaring completion. Report exact test counts, screenshot paths, deviations, dependencies, git commits, and git status.
8. Do not push, tag, deploy, publish, add cloud upload, or start unrelated checkpoints. If blocked by tool/rate limits, save a clear recovery handoff and stop; never claim completed work without evidence.

The owner is busy: make routine technical choices yourself, request input only for essential blockers or irreversible changes. No manual UI recreation tasks for the owner.
