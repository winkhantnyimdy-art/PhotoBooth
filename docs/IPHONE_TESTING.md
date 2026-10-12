# Testing PhotoBooth on a physical iPhone (Windows PC, Wi-Fi, HTTPS)

iOS Safari will not grant camera access on a plain `http://` address, and the
app deliberately refuses to run the camera outside a secure context. Everything
below therefore uses a real HTTPS tunnel.

No domain purchase, no Apple Developer fee, no app store, no deploy, and the
tunnel is **not** left running unattended.

---

## 0. Prerequisites

| Requirement | Notes |
| --- | --- |
| Flutter 3.47+ | Already used by this project. |
| Node.js 18+ | Only needed for the local Playwright-style checks. |
| Phone and PC on the same Wi-Fi | Turn off mobile data on the iPhone, or it may leave via cellular. |
| `cloudflared` (optional, recommended) | Free, no account, gives a stable `https://*.trycloudflare.com` URL. Install with `winget install --id Cloudflare.cloudflared`. |
| `ngrok` (alternative) | Free tier is enough but requires an account and an auth token. |

> **Do not use `flutter run -d chrome --web-host` alone.** It serves over HTTP
> on your LAN, which iOS Safari treats as an insecure context: the camera will
> never start.

---

## 1. Build the release web bundle

```powershell
cd C:\Users\jpas\Downloads\PhotoBooth
flutter pub get
flutter build web --release
```

Output goes to `build\web`.

---

## 2. Serve the build over plain HTTP locally

The tunnel needs a local origin to forward to.

```powershell
# Terminal 1 - leave this running
cd C:\Users\jpas\Downloads\PhotoBooth\build\web
python -m http.server 8080 --bind 127.0.0.1
```

Confirm it is up:

```powershell
Invoke-WebRequest -Uri http://127.0.0.1:8080/index.html -UseBasicParsing | Select-Object StatusCode
```

---

## 3. Start the HTTPS tunnel

### Option A - cloudflared (recommended, no account)

```powershell
# Terminal 2 - leave this running
cloudflared tunnel --url http://127.0.0.1:8080
```

It prints something like:

```
INF |  https://random-words-1234.trycloudflare.com
```

Copy that URL. This is the only address you need on the iPhone.

### Option B - ngrok (free account required once)

```powershell
ngrok http 8080
```

Use the `https://...ngrok-free.app` URL it prints.

---

## 4. Open it on the iPhone

1. Put the iPhone and the PC on the **same Wi-Fi network**.
2. Open **Safari** (not Chrome, not an in-app browser - `getUserMedia` behaves
   differently there).
3. Type the tunnel URL exactly as printed, including `https://`.
4. Tap **Start Photo Booth**, pick a layout, and allow camera access when the
   permission prompt appears.

> **iOS permission prompt not appearing?**
> Go to `aA` (left of the address bar) -> **Website Settings** -> **Camera** ->
> **Ask** or **Allow**, then reload. If the camera was previously denied, iOS
> will not prompt again on its own.

---

## 5. Install as a PWA (optional but recommended)

After the app loads once in Safari:

1. Tap **Share** (square with an up arrow).
2. Choose **Add to Home Screen**.
3. Open it from the new Home Screen icon.

Installed mode runs full screen, respects the safe area via
`viewport-fit=cover` + `black-translucent`, and starts offline because the
service worker precaches the app shell.

---

## 6. What to check on the device

| Area | Expectation |
| --- | --- |
| Camera start | Live preview appears within a second or two of granting permission. |
| Permission denied | A readable "Camera access blocked" card with iPhone-specific instructions and a **Try again** button - not a raw error. |
| Insecure context | "Camera needs a secure connection" naming the `https://` requirement. |
| Multi-shot | Countdown 3-2-1, flash, and the `n of N` progress pill all animate for every shot. |
| Camera switch | The switch control is enabled only when the browser reports more than one video input. On iPhone this is front + back. |
| Review / Decorate / Export | Photos render; filters, frames, stickers, text and adjustments all apply live. |
| Export preview vs PNG | The strip on the Export screen must match the downloaded PNG. |
| **Download PNG** | Saves a real `.png` to **Files** (not Photos). The UI says so explicitly. |
| **Share** | Opens the iOS share sheet with the PNG attached; "Save Image" from there puts it in Photos. |
| Safe areas | Nothing clipped under the notch or the home indicator, in both Safari and installed mode. |
| Offline | After one successful load, switch to Airplane Mode and reopen from the Home Screen icon. |

---

## 7. Shut down cleanly

The tunnel is a public URL while it is running. Stop it when you are done:

1. `Ctrl+C` in the tunnel terminal (Terminal 2).
2. `Ctrl+C` in the static server terminal (Terminal 1).

Verify nothing is still listening:

```powershell
Get-Process cloudflared, ngrok, python -ErrorAction SilentlyContinue |
    Where-Object { $_.Id -ne $PID } |
    Stop-Process
```

---

## 8. Optional: repeat the whole flow headlessly on the PC

This repository ships a smoke test that drives the real build in headless Chrome
using a synthetic camera, so regressions can be caught without an iPhone.

```powershell
cd C:\Users\jpas\Downloads\PhotoBooth

# 1. Serve the release build
Start-Process python -ArgumentList "-m","http.server","8099","--bind","127.0.0.1" `
  -WorkingDirectory "C:\Users\jpas\Downloads\PhotoBooth\build\web" -WindowStyle Hidden

# 2. Optional: a colourful Y4M clip so captured photos are actually visible
python tool\make_fake_camera_clip.py

# 3. Run the full Home -> Camera -> Review -> Decorate -> Export flow
node tool\web_smoke_test.js

# 4. Repeat with the Web Share API disabled to exercise the download fallback
node tool\web_smoke_test.js --no-web-share --out=build/web_smoke_noshare

# 5. Stop the server
Get-Process python -ErrorAction SilentlyContinue | Stop-Process
```

Screenshots land in `build\web_smoke\`, and the exported PNG is written to
`build\web_smoke\downloads\`.

---

## Troubleshooting

| Symptom | Cause and fix |
| --- | --- |
| "This site can't be reached" | The local server or tunnel is down. Check Terminal 1 and 2 are still running. |
| Camera never prompts | Open via the `https://` tunnel URL, not `http://192.168.x.x`. On iOS, reset permission via `aA` -> Website Settings -> Camera. |
| Blank/black preview | The browser reports no video input. Close other apps and tabs using the camera, then reload. |
| Download does nothing | iOS Safari may show a "download" banner at the top; tap it. Alternatively use **Share** -> **Save Image**, which goes straight to Photos. |
| Page loads but camera is blank after switching cameras | Some iOS versions expose the front camera only while another app holds the rear one. Close camera apps and retry. |
| Install to Home Screen missing the icon | Safari requires a secure origin plus at least one visit. Confirm the URL is `https://` and reload once. |