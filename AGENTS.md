# PhotoBooth — Codex Project Instructions

## Autonomous execution
- Act as an implementation agent, not a planning-only assistant.
- After understanding a task, execute it using available tools.
- Do not ask for confirmation between ordinary implementation steps.
- Do not repeatedly summarize plans or announce what you will do next.
- If a command fails, diagnose it and try a safe alternative.
- Prefer precise patches or reliable file-writing methods over fragile multiline shell commands.
- Never overwrite an entire existing file without inspecting it first.
- Continue through the requested scope until complete or genuinely blocked.

## Current task
Complete the PhotoBooth Retro Film Pop redesign across Home, Camera, Review, Decorate, and Export.

Use design/PhotoBooth_Premium_Design as the visual reference.

Preserve working camera, capture, image processing, navigation, and export functionality.

Implement real photo filters, frames, stickers, text editing, and matching preview/export rendering.

## Verification
- Run flutter analyze.
- Run flutter test.
- Build the Android debug APK.
- Capture emulator screenshots when possible.
- Report actual results, not assumptions.

## Boundaries
- Do not push, publish, or deploy.
- Do not install system-wide software without permission.
- Do not discard existing work or unrelated changes.
- Do not modify Windows Terminal or Ollama settings.
- Stop only when finished or when genuinely blocked.
