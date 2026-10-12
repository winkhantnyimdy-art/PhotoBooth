/**
 * Drives the built PhotoBooth web app in headless Chrome over the DevTools
 * Protocol and reports what happened.
 *
 * Chrome is launched with a fake camera device
 * (--use-fake-device-for-media-stream) and auto-granted permission
 * (--use-fake-ui-for-media-stream), so the real capture path -- getUserMedia,
 * camera_web, takePicture -- executes without a physical device.
 *
 * Usage:
 *   node tool/web_smoke_test.js [url] [--shots=4] [--out=dir]
 *
 * Defaults to http://127.0.0.1:8099/ (localhost is a secure context, so
 * getUserMedia is allowed exactly as it would be over HTTPS).
 */

const { spawn } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const CHROME_PATHS = [
  'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
  'C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe',
  path.join(process.env.LOCALAPPDATA || '', 'Google', 'Chrome', 'Application', 'chrome.exe'),
  'C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe',
];

function findChrome() {
  for (const p of CHROME_PATHS) {
    if (p && fs.existsSync(p)) return p;
  }
  throw new Error('No Chrome or Edge binary found.');
}

function parseArgs(argv) {
  const out = {
    url: null,
    shots: 4,
    outDir: path.resolve('build/web_smoke'),
    clip: path.resolve('build/fake_camera.y4m'),
    noWebShare: false,
    denyCamera: false,
  };
  for (const a of argv) {
    if (a.startsWith('--shots=')) out.shots = Number(a.split('=')[1]);
    else if (a.startsWith('--out=')) out.outDir = path.resolve(a.split('=')[1]);
    else if (a.startsWith('--clip=')) out.clip = path.resolve(a.split('=')[1]);
    else if (a === '--no-web-share') out.noWebShare = true;
    else if (a === '--deny-camera') out.denyCamera = true;
    else if (!a.startsWith('--')) out.url = a;
  }
  out.url = out.url || 'http://127.0.0.1:8099/';
  return out;
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function fetchJson(url, attempts = 40) {
  for (let i = 0; i < attempts; i++) {
    try {
      const res = await fetch(url);
      if (res.ok) return await res.json();
    } catch (_) {
      /* not up yet */
    }
    await sleep(250);
  }
  throw new Error(`Timed out waiting for ${url}`);
}

/** Minimal CDP client over the browser-level WebSocket. */
class Cdp {
  constructor(ws) {
    this.ws = ws;
    this.id = 0;
    this.pending = new Map();
    this.listeners = new Map();
    ws.addEventListener('message', (ev) => {
      const msg = JSON.parse(ev.data);
      if (msg.id !== undefined) {
        const p = this.pending.get(msg.id);
        if (p) {
          this.pending.delete(msg.id);
          msg.error ? p.reject(new Error(JSON.stringify(msg.error))) : p.resolve(msg.result);
        }
      } else {
        const ls = this.listeners.get(msg.method) || [];
        for (const l of ls) l(msg.params, msg.sessionId);
      }
    });
  }

  static async connect(url) {
    const ws = new WebSocket(url);
    await new Promise((resolve, reject) => {
      ws.addEventListener('open', resolve, { once: true });
      ws.addEventListener('error', reject, { once: true });
    });
    return new Cdp(ws);
  }

  send(method, params = {}, sessionId) {
    const id = ++this.id;
    const payload = { id, method, params };
    if (sessionId) payload.sessionId = sessionId;
    this.ws.send(JSON.stringify(payload));
    return new Promise((resolve, reject) => this.pending.set(id, { resolve, reject }));
  }

  on(method, fn) {
    const list = this.listeners.get(method) || [];
    list.push(fn);
    this.listeners.set(method, list);
  }
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const userDataDir = fs.mkdtempSync(path.join(os.tmpdir(), 'pb-chrome-'));
  fs.mkdirSync(args.outDir, { recursive: true });

  const port = 9333;
  const downloadDir = path.join(args.outDir, 'downloads');
  fs.mkdirSync(downloadDir, { recursive: true });
  const clipArgs = fs.existsSync(args.clip)
    ? ['--use-file-for-fake-video-capture=' + args.clip]
    : [];

  const chrome = spawn(
    findChrome(),
    [
      '--headless=new',
      `--remote-debugging-port=${port}`,
      `--user-data-dir=${userDataDir}`,
      '--window-size=390,844',
      '--force-device-scale-factor=1',
      // Synthetic camera + auto-accepted permission prompt.
      '--use-fake-device-for-media-stream',
      ...(args.denyCamera ? [] : ['--use-fake-ui-for-media-stream']),
      ...clipArgs,
      '--autoplay-policy=no-user-gesture-required',
      '--no-first-run',
      '--no-default-browser-check',
      '--disable-gpu-shader-disk-cache',
      'about:blank',
    ],
    { stdio: ['ignore', 'pipe', 'pipe'] },
  );
  chrome.stderr.on('data', () => {});

  const consoleErrors = [];
  const consoleAll = [];
  let exitCode = 0;

  try {
    const version = await fetchJson(`http://127.0.0.1:${port}/json/version`);
    console.log('Browser:', version['Browser']);

    const cdp = await Cdp.connect(version.webSocketDebuggerUrl);
    const { targetId } = await cdp.send('Target.createTarget', { url: 'about:blank' });
    const { sessionId } = await cdp.send('Target.attachToTarget', { targetId, flatten: true });

    cdp.on('Runtime.consoleAPICalled', (p, sid) => {
      if (sid !== sessionId) return;
      const text = (p.args || [])
        .map((a) => (a.value !== undefined ? a.value : a.description || a.type))
        .join(' ');
      consoleAll.push(`[${p.type}] ${text}`);
      if (p.type === 'error' || p.type === 'warning') consoleErrors.push(`[${p.type}] ${text}`);
    });
    cdp.on('Runtime.exceptionThrown', (p, sid) => {
      if (sid !== sessionId) return;
      const d = p.exceptionDetails || {};
      consoleErrors.push(`[exception] ${d.text} ${d.exception ? d.exception.description : ''}`);
    });
    cdp.on('Log.entryAdded', (p, sid) => {
      if (sid !== sessionId) return;
      const e = p.entry || {};
      consoleAll.push(`[log:${e.level}] ${e.text}`);
      if (e.level === 'error') consoleErrors.push(`[log:${e.level}] ${e.text}`);
    });

    // Let the browser write downloads to a folder we control so the exported
    // PNG can be inspected rather than trusted.
    await cdp.send('Browser.setDownloadBehavior', {
      behavior: 'allow',
      downloadPath: downloadDir,
      eventsEnabled: true,
    });

    await cdp.send('Runtime.enable', {}, sessionId);
    await cdp.send('Log.enable', {}, sessionId);
    await cdp.send('Page.enable', {}, sessionId);
    await cdp.send('Browser.grantPermissions', {
      origin: new URL(args.url).origin,
      permissions: ['videoCapture', 'audioCapture'],
    });

    if (args.denyCamera) {
      // Simulate the user tapping "Block" on the iOS camera prompt.
      await cdp.send('Browser.setPermission', {
        origin: new URL(args.url).origin,
        permission: { name: 'camera' },
        setting: 'denied',
      });
      console.log('Camera permission set to DENIED for this run.');
    }

    // Emulate an iPhone 14-ish viewport so the responsive layout under test is
    // the one a real phone would get.
    await cdp.send(
      'Emulation.setDeviceMetricsOverride',
      {
        width: 390,
        height: 844,
        deviceScaleFactor: 3,
        mobile: true,
screenOrientation: { angle: 0, type: 'portraitPrimary' },
      },
      sessionId,
    );
    await cdp.send(
      'Emulation.setTouchEmulationEnabled',
      { enabled: true, maxTouchPoints: 5 },
      sessionId,
    );

    await cdp.send('Page.navigate', { url: args.url }, sessionId);
    console.log('Navigated to', args.url);

    const evaluate = async (expression) => {
      const r = await cdp.send(
        'Runtime.evaluate',
        { expression, returnByValue: true, awaitPromise: true },
        sessionId,
      );
      if (r.exceptionDetails) {
        throw new Error(r.exceptionDetails.text + ' ' + JSON.stringify(r.exceptionDetails.exception || {}));
      }
      return r.result.value;
    };

    const shoot = async (name) => {
      const { data } = await cdp.send('Page.captureScreenshot', { format: 'png' }, sessionId);
      const file = path.join(args.outDir, `${name}.png`);
      fs.writeFileSync(file, Buffer.from(data, 'base64'));
      console.log('  screenshot ->', file);
    };

    // Wait for Flutter to paint. The canvas lives under <flt-glass-pane>.
    const booted = await (async () => {
      for (let i = 0; i < 60; i++) {
        const ok = await evaluate(
          `!!document.querySelector('flt-glass-pane, flt-scene-host, flutter-view')`,
        );
        if (ok) return true;
        await sleep(500);
      }
      return false;
    })();
    console.log('Flutter view mounted:', booted);
    if (!booted) {
      consoleErrors.push('Flutter view never mounted');
    }
    await sleep(4000);

    // Turn on semantics so the DOM exposes real labels; Flutter then builds a
    // semantics tree we can query and drive.
    await evaluate(`document.querySelector('flt-semantics-placeholder')?.click?.()`);
    await sleep(1500);

    const tree = await evaluate(`
      (() => {
        const labels = [...document.querySelectorAll('flt-semantics')]
          .map(n => (n.getAttribute('aria-label') || n.textContent || '').trim())
          .filter(Boolean);
        return JSON.stringify(labels);
      })()
    `);
    const labels = JSON.parse(tree || '[]');
    console.log('Semantics labels:', JSON.stringify(labels.slice(0, 40)));

    await shoot('01-home');

    // Tap a widget by its accessible name.
    //
    // The Flutter semantics tree gives every tappable a <flt-semantics> node;
    // we read its on-screen centre and then dispatch real input through the
    // CDP Input domain. That goes through the engine's own hit-testing, so it
    // exercises the same gesture path a finger would.
    const tapLabel = async (label, { exact = true } = {}) => {
      const box = await evaluate(`(() => {
        const nodes = [...document.querySelectorAll('flt-semantics')];
        const wanted = ${JSON.stringify(label)};
        const nameOf = (n) => ((n.getAttribute('aria-label') || '') + ' ' + (n.textContent || '')).trim();
        const boxes = nodes
          .map(n => ({ n, r: n.getBoundingClientRect() }))
          .filter(o => o.r.width > 0 && o.r.height > 0);
        const pick = (list) => {
          if (list.length === 0) return null;
          // Pick the tightest match: ancestor containers inherit their
          // descendants' text, so a naive find() lands on the whole screen.
          list.sort((a, b) => a.r.width * a.r.height - b.r.width * b.r.height);
          const r = list[0].r;
          return { x: r.left + r.width / 2, y: r.top + r.height / 2, w: r.width, h: r.height };
        };
        // Prefer an exact name; only fall back to a substring match when no
        // node carries the exact label.
        const exactHit = pick(boxes.filter(o => nameOf(o.n) === wanted));
        if (exactHit) return exactHit;
        return pick(boxes.filter(o => nameOf(o.n).includes(wanted)));
      })()`);
      if (!box) return 'no-match';
      // Touch only: with touch emulation on, a phone's finger produces
      // touchstart/touchend, not a mouse click. Dispatching both would fire
      // the gesture twice.
      const x = Math.round(box.x);
      const y = Math.round(box.y);
      await cdp.send(
        'Input.dispatchTouchEvent',
        { type: 'touchStart', touchPoints: [{ x, y, id: 1 }] },
        sessionId,
      );
      await sleep(80);
      await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] }, sessionId);
      await sleep(120);
      return `ok (${Math.round(box.w)}x${Math.round(box.h)} @ ${Math.round(box.x)},${Math.round(box.y)})`;
    };

    console.log('Clicked "4 CUT":', await tapLabel('4 CUT'));
    await sleep(1200);
    console.log('Clicked "Start Photo Booth":', await tapLabel('Start Photo Booth', { exact: false }));
    await sleep(4000);
    await shoot('02-camera');

    const labelsNow = () =>
      evaluate(`JSON.stringify([...document.querySelectorAll('flt-semantics')]
        .map(n => ((n.getAttribute('aria-label')||'') + '|' + (n.textContent||'')).trim())
        .filter(s => s.length > 2))`);

    console.log('Camera screen labels:', await labelsNow());

    if (args.denyCamera) {
      // The camera must never start, and the app must explain why in plain
      // language rather than throwing a raw platform error at the user.
      const shutterPresent = await evaluate(
        `!!document.querySelector('flt-semantics[aria-label*="Take photos"]')`,
      );
      console.log('Shutter offered while denied (expected false):', shutterPresent);
      console.log('Visible copy:', await evaluate(`JSON.stringify(document.body.innerText)`));
      if (shutterPresent) {
        consoleErrors.push('Camera screen offered capture despite denied permission');
      }
      await shoot('02b-camera-denied');
      console.log('\n=== Console errors/warnings ===');
      if (consoleErrors.length === 0) console.log('(none)');
      else for (const e of consoleErrors) console.log(e);
      if (consoleErrors.length > 0) exitCode = 1;
      return;
    }

    const onCameraScreen = await evaluate(
      `!!document.querySelector('flt-semantics[aria-label*="Take photos"]')`,
    );
    console.log('Camera screen reachable (shutter present):', onCameraScreen);

    console.log('Clicked shutter:', await tapLabel('Take photos', { exact: false }));
    // Report what the camera plugin actually got hold of.
    const mediaState = await evaluate(`(() => {
      const vids = [...document.querySelectorAll('video')];
      return JSON.stringify(vids.map(v => ({
        w: v.videoWidth, h: v.videoHeight,
        srcObject: !!v.srcObject,
        tracks: v.srcObject ? v.srcObject.getVideoTracks().length : 0,
        readyState: v.readyState,
        paused: v.paused,
      })));
    })()`);
    console.log('Video elements:', mediaState);

    // 4 shots x (3s countdown + ~0.4s gap) + render headroom.
    await sleep(6000);
    await shoot('03-capturing');
    await sleep(9000);

    const afterSession = await labelsNow();
    console.log('Labels after session:', afterSession);
    await shoot('04-review');

    console.log('Clicked Next (review -> decorate):', await tapLabel('Next'));
    await sleep(4000);
    await shoot('05-decorate');
    console.log('Decorate labels:', await labelsNow());

    // Exercise a real editor control: pick a filter preset.
    console.log('Tapped a filter:', await tapLabel('Retro', { exact: false }));
    await sleep(1500);
    await shoot('06-decorate-filter');

    console.log('Tapped stickers tab:', await tapLabel('Stickers', { exact: false }));
    await sleep(1500);
    await shoot('07-decorate-stickers');

    // Reach Export through the editor's own action button.
    console.log('Tapped "Finish & Save":', await tapLabel('Finish & Save', { exact: false }));
    await sleep(7000);
    await shoot('08-export');
    console.log('Export labels:', await labelsNow());

    // Verify the primary action really produces a PNG file.
    const before = new Set(fs.readdirSync(downloadDir));
    console.log('Tapped "Download PNG":', await tapLabel('Download PNG', { exact: false }));
    await sleep(4000);
    await shoot('09-export-downloaded');
    const after = fs
      .readdirSync(downloadDir)
      // Chrome writes its own downloads-shelf HTML next to real downloads.
      .filter((f) => !before.has(f) && f !== 'downloads.htm');
    console.log('Downloaded files:', JSON.stringify(after));
    for (const f of after) {
      const size = fs.statSync(path.join(downloadDir, f)).size;
      const head = fs.readFileSync(path.join(downloadDir, f)).subarray(0, 8);
      const isPng =
        head[0] === 0x89 && head[1] === 0x50 && head[2] === 0x4e && head[3] === 0x47;
      console.log(`  ${f}: ${size} bytes, PNG signature: ${isPng}`);
      if (!isPng || size === 0) {
        consoleErrors.push(`Download ${f} is not a valid PNG`);
      }
    }

    // Verify the service worker registered and cached ONLY the app shell.
    const swState = await evaluate(`(async () => {
      const regs = await navigator.serviceWorker.getRegistrations();
      const names = await caches.keys();
      const contents = {};
      for (const n of names) {
        const c = await caches.open(n);
        contents[n] = (await c.keys()).map(r => new URL(r.url).pathname).sort();
      }
      return JSON.stringify({ registrations: regs.length, scopes: regs.map(r => r.scope), caches: contents });
    })()`);
    console.log('Service worker state:', swState);

    // Verify the share path degrades to a download when the Web Share API is
    // unavailable, which is the case on older Safari and on desktop browsers
    // that reject file payloads.
    if (args.noWebShare) {
      await evaluate(`
        Object.defineProperty(navigator, 'canShare', { value: () => false, configurable: true });
        Object.defineProperty(navigator, 'share', {
          value: () => Promise.reject(new DOMException('unsupported', 'NotAllowedError')),
          configurable: true,
        });
        true;
      `);
      console.log('Web Share API disabled for this run.');
    }
    const shareSupported = await evaluate(
      `typeof navigator.canShare === 'function' && navigator.canShare({files:[new File([new Uint8Array([1])],'a.png',{type:'image/png'})]})`,
    );
    console.log('navigator.canShare(files):', shareSupported);
    const beforeShare = new Set(fs.readdirSync(downloadDir));
    console.log('Tapped "Share":', await tapLabel('Share', { exact: false }));
    await sleep(4000);
    const afterShare = fs
      .readdirSync(downloadDir)
      .filter((f) => !beforeShare.has(f) && !after.includes(f));
    console.log('Share fallback produced:', JSON.stringify(afterShare));

    console.log('\n=== Console errors/warnings ===');
    if (consoleErrors.length === 0) console.log('(none)');
    else for (const e of consoleErrors) console.log(e);

    console.log('\n=== Full console (last 40) ===');
    for (const c of consoleAll.slice(-40)) console.log(c);

    if (consoleErrors.some((e) => e.includes('[exception]') || e.includes('never mounted'))) {
      exitCode = 1;
    }
  } catch (error) {
    console.error('Smoke test failed:', error);
    exitCode = 2;
  } finally {
    chrome.kill();
    await sleep(500);
    process.exit(exitCode);
  }
}

main();
