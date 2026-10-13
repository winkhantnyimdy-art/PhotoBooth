# PhotoBooth — Android Release Readiness (Checkpoint 5)

Distribution plan: native Android app, sideloaded through the existing BJT
Trainer website. No Play Store upload, no accounts, no subscriptions, no cloud.

## Audit findings fixed in this checkpoint

| # | Issue | Severity | Fix |
| --- | --- | --- | --- |
| 1 | `AlbumScope` was mounted at `home:`, below `MaterialApp`, so no pushed route (Album, Export, Settings) could resolve the album. `AlbumScreen` push crashed with "No AlbumScope", Export hid "Save to Album", Settings showed fallback copy. The code contradicted its own doc comment. Pre-existing since the album was introduced; reproduced on the pristine baseline build. | **Release blocker** | Hoisted `AlbumScope` above `MaterialApp` in `lib/app/app.dart`, as the comment always prescribed. Verified on emulator: Album opens, "Save to album" saves 4 photos + record, session survives force-stop, reopen edits. Regression test `pushed routes reach the same album instance` (fails on old code, passes on new). |
| 2 | Selfie-mirroring default hard-coded to the web behaviour (`true`), so on Android selfies stored unmirrored while the preview showed mirrored. | **Release blocker** | Default is now `kIsWeb` (`lib/features/camera/selfie_mirroring.dart`). Regression test added. |
| 3 | Camera controller created with `enableAudio: true` (plugin default), so Android requested the microphone for a photo-only app. | Privacy/permission | Pass `enableAudio: false` (`lib/features/camera/camera_screen.dart`) and removed `RECORD_AUDIO` from the merged manifest. Emulator permission dialog now asks camera only. |
| 4 | `READ_EXTERNAL_STORAGE` (unscoped) merged in from transitive deps; app never reads shared media. | Privacy/permission | `tools:node="remove"` in `AndroidManifest.xml`. `aapt2` confirms only an API ≤28 implied entry remains. |
| 5 | Camera denial surfaced generic "Camera unavailable / try again" with no pointer to Settings. | UX | Native `CameraAccessDenied`/`cameraNotFound` mapping (`browser_capabilities_stub.dart`). Verified on emulator: "Camera permission needed" + Settings guidance + Try again. |
| 6 | `flipPhotoIfNeeded` threw on unreadable bytes instead of keeping the original (its own contract). | Robustness | try/catch fallback on both IO and web paths. Regression test added. |
| 7 | Album/Settings/empty-session copy blamed "the browser" on native. | UX | `kIsWeb`-gated copy; verified on emulator ("Uninstalling the app will erase the album.", "Not measurable on this device"). |

No redesign, no new features, no accounts/cloud. Retro Film Pop design untouched.

## 1. Version and application ID review

| Item | Value | Notes |
| --- | --- | --- |
| `applicationId` | `com.photobooth.photo_booth` | Default template ID. Kept deliberately: changing it orphans existing installs (Android treats it as a different app). Revisit only with a migration plan. |
| `versionName` / `versionCode` | `1.0.0` / `1` (`pubspec.yaml`) | First release. Bump both together for every website release; updates require a higher `versionCode` with the same `applicationId`. |
| `minSdk` | 24 (Android 7.0, Flutter default) | Verified in the merged manifest. Covers ~all active devices; CameraX and MediaStore code paths used here work back to API 24. |
| `targetSdk` / `compileSdk` | 36 (Android 16, Flutter default) | Verified in the merged manifest of the Checkpoint 5 debug build. |
| Display name | `PhotoBooth` | Set in `android:app:label`. |
| Camera feature | `android.hardware.camera.any`, no `required="false"` | Correct: the app cannot function without any camera. |

## 2. App icon and splash screen review

- **Splash:** themed. `launch_background.xml` paints the warm cream
  (`#FFFFF8F1`, mirrors `AppColors.background`) and `colors.xml` defines it in
  one place. No white flash on cold launch. No change needed.
- **App icon:** still the Flutter template default (`mipmap-*` untouched since
  project creation). **Replace before any public release** with a branded
  PhotoBooth icon set (hdpi through xxxhdpi, plus adaptive-icon foreground /
  background for API 26+). This is the one known visual gap; everything else in
  the Retro Film Pop design renders from Dart code and is unaffected.

## 3. Release signing requirements

The `release` build type in `android/app/build.gradle.kts` currently signs
with the **debug** keys (`signingConfigs.getByName("debug")`) so
`flutter run --release` works. That is fine for testing and must change before
distributing from the website:

1. Generate a private keystore once, on a secure machine:
   `keytool -genkeypair -v -keystore photobooth-release.jks -alias photobooth -keyalg RSA -keysize 2048 -validity 10000`
2. Create `android/key.properties` (NOT in Git — `android/.gitignore` already
   excludes it; verify before committing):
   `storeFile`, `storePassword`, `keyAlias`, `keyPassword`.
3. Wire a `release` signing config in `android/app/build.gradle.kts` that reads
   `key.properties`.
4. **Back up the keystore and both passwords offline.** Losing them means the
   website can never ship an update users can install over the current app.
5. Never commit the `.jks`, `key.properties`, or passwords. Do not print them
   into build logs.

## 4. Release APK build procedure

```sh
flutter pub get
flutter analyze          # must report no issues
flutter test             # full suite must pass
flutter build apk --release
```

The signed APK lands at `build/app/outputs/flutter-apk/app-release.apk`.
Sanity-check it before uploading to the website:

```sh
aapt2 dump badging build/app/outputs/flutter-apk/app-release.apk | Select-String "package:|sdkVersion|uses-permission|application-label"
```

Expected: `applicationId com.photobooth.photo_booth`, the bumped
`versionCode`/`versionName`, label `PhotoBooth`, and only the permissions
listed in section 6. (Use the `aapt2` from the installed build-tools.)

## 5. APK installation and update checklist (website sideload)

- Host the APK over HTTPS on the BJT Trainer site with the version name and
  release notes next to the download link.
- First install: user enables "Install unknown apps" for their browser when
  Android prompts; no other setup.
- Updates: same `applicationId` + higher `versionCode` installs over the old
  app and **keeps the album** (app-private files survive updates).
- Warn users that **uninstalling deletes the album** — sessions are device-only
  by design (the app now says this in the Album footer and Settings).
- Keep at least one previous APK on the site during rollout so a bad release
  can be re-installed immediately.
- Do not modify the BJT Trainer app or website beyond adding the download
  entry point.

## 6. Privacy and permission disclosure notes

Suggested website copy: "PhotoBooth needs camera access to take photos.
Saved sessions stay on your device — no account, no cloud, no analytics.
‘Save to Photos’ writes the finished strip to your gallery; nothing is ever
uploaded."

Declared permissions (release manifest, verified via `aapt2 dump badging`):

- `CAMERA` — taking photos. Requested at runtime by the camera plugin.
- `WRITE_EXTERNAL_STORAGE` (`maxSdkVersion=28` only) — transitive from the
  camera plugin; inert on modern Android where gallery saves go through
  MediaStore. Never requested at runtime on API 29+.
- `ACCESS_NETWORK_STATE`, `INTERNET` (debug builds only for the latter) —
  transitive from media dependencies; the app itself makes no network calls.

Deliberately removed in Checkpoint 5 (`tools:node="remove"`):

- `RECORD_AUDIO` — the app never records video; the controller is created with
  `enableAudio: false` so the microphone is never requested.
- `READ_EXTERNAL_STORAGE` — the app never reads shared media; the album is
  app-private and shares go through a FileProvider.

Gallery saving (`gal` → MediaStore) needs no storage permission on Android
10+. On Android 7–9 the OS may grant the legacy storage permission at install;
no action needed from the user.

## 7. Android device testing checklist (physical devices, not emulator)

An emulator build proving out is explicitly not device acceptance. Emulator
verification actually performed in this checkpoint (Medium Phone, API 37):
cold launch, Home, camera open, two full 4-shot sessions to Review, system
back Review→Camera→Home, Review→Decorate→Export, "Save to album" + on-disk
files, force-stop → session still listed, reopen into Edit Session, "Save to
Photos" present in MediaStore, share sheet opens, camera-switch without crash,
permission-deny error copy, camera-only runtime permission set. Not verifiable
on the emulator: real-sensor framing/mirroring, low-end performance, API 24–29
storage behaviour, release signing.

Before release, verify on at least one modern (API 34+) and one older (API
24–29) physical device:

- [ ] Cold launch shows the cream splash, then Home with no errors.
- [ ] Camera opens; preview is full-bleed with the 3:4 crop guide.
- [ ] Front and rear capture; hold printed text up to the front camera and
      confirm the saved selfie reads correctly (mirrored by default).
- [ ] "Mirror selfies" off produces a natural-orientation selfie.
- [ ] Full 4-photo session completes to Review; individual Retake replaces one
      slot; Photo (retake from Decorate/Review) returns correctly.
- [ ] Filters, frames, stickers, and text all render in Decorate and match the
      Export preview and the saved PNG pixel-for-pixel in arrangement.
- [ ] "Save to Photos" lands in the gallery; "Share" opens the system sheet.
- [ ] "Save to album", force-stop the app, relaunch: session reopens editable
      with photos and decorations intact.
- [ ] Deny the camera permission: the error names the permission and points at
      system Settings; "Try again" recovers after granting.
- [ ] Android back button: guarded mid-session (confirm dialog), plain pop
      everywhere else.
- [ ] Rotate the phone mid-flow: no crash, no lost captures.
- [ ] Low-end device with 4 photos: editor stays responsive; export completes.
