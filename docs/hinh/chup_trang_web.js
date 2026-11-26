#!/usr/bin/env node
/*
 * Chụp trang web đánh giá sai số (web/evaluation.html) khi đang nhận bản tin thật, cho Hình 3.7, 4.2, 4.6.
 * Mở Chrome chạy ẩn và điều khiển qua DevTools Protocol bằng WebSocket có sẵn của Node 22+, không cần cài gói.
 *
 *   node docs/hinh/chup_trang_web.js --out docs/hinh/hinh-3-7-trang-web.png --wait 25
 *   node docs/hinh/chup_trang_web.js --out docs/hinh/hinh-4-2-ban-tin-timestamp.png --section h-live --wait 25
 *   node docs/hinh/chup_trang_web.js --out x.png --samples docs/thuc-nghiem/mau-dat.csv --section h-results \
 *        --eval "document.getElementById('chartIndicator').value='k'; document.getElementById('chartIndicator').dispatchEvent(new Event('change'))"
 *
 * Tùy chọn:
 *   --out <tệp png>      bắt buộc
 *   --wait <giây>        chờ trang nhận bản tin trước khi chụp (mặc định 20)
 *   --section <id>       chỉ chụp khối <section> chứa tiêu đề có id này (h-conn, h-live, h-samples, h-results, h-noise)
 *   --samples <csv>      nạp sẵn bảng mẫu từ tệp CSV xuất ở trang (giống bấm Nhập CSV)
 *   --eval <js>          chạy đoạn JavaScript trên trang trước khi chụp (sau khi chờ)
 *   --width <px>         chiều rộng trang (mặc định 1280)
 */
'use strict';

const { spawn } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const ROOT = path.resolve(__dirname, '..', '..');
const PAGE = 'file:///' + path.join(ROOT, 'web', 'evaluation.html').replace(/\\/g, '/');
const STORAGE_KEY = 'soil-eval-samples-v1'; // Giống STORAGE_KEY trong web/evaluation.html
const PORT = 9333;
const CHROME_PATHS = [
  'C:/Program Files/Google/Chrome/Application/chrome.exe',
  'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',
  '/usr/bin/google-chrome',
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
];

function parseArgs(argv) {
  const opts = { wait: 20, width: 1280 };
  for (let i = 0; i < argv.length; i += 2) {
    const key = argv[i].replace(/^--/, '');
    opts[key] = argv[i + 1];
  }
  if (!opts.out) throw new Error('Thiếu --out <tệp png>');
  opts.wait = Number(opts.wait);
  opts.width = Number(opts.width);
  return opts;
}

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function waitForTarget() {
  for (let i = 0; i < 50; i++) {
    try {
      const targets = await (await fetch(`http://127.0.0.1:${PORT}/json/list`)).json();
      const page = targets.find((t) => t.type === 'page');
      if (page) return page.webSocketDebuggerUrl;
    } catch (e) { /* Chrome chưa mở xong cổng gỡ lỗi */ }
    await sleep(200);
  }
  throw new Error('Không kết nối được Chrome chạy ẩn');
}

function cdpSession(url) {
  const ws = new WebSocket(url);
  let nextId = 1;
  const pending = new Map();
  const listeners = [];
  ws.onmessage = (event) => {
    const msg = JSON.parse(event.data);
    if (msg.id && pending.has(msg.id)) {
      const { resolve, reject } = pending.get(msg.id);
      pending.delete(msg.id);
      if (msg.error) reject(new Error(msg.error.message));
      else resolve(msg.result);
    } else if (msg.method) {
      listeners.forEach((fn) => fn(msg));
    }
  };
  const send = (method, params = {}) => new Promise((resolve, reject) => {
    const id = nextId++;
    pending.set(id, { resolve, reject });
    ws.send(JSON.stringify({ id, method, params }));
  });
  const once = (method) => new Promise((resolve) => {
    const fn = (msg) => {
      if (msg.method === method) {
        listeners.splice(listeners.indexOf(fn), 1);
        resolve(msg.params);
      }
    };
    listeners.push(fn);
  });
  return new Promise((resolve) => { ws.onopen = () => resolve({ send, once, close: () => ws.close() }); });
}

async function evaluate(cdp, expression) {
  const result = await cdp.send('Runtime.evaluate', { expression, awaitPromise: true, returnByValue: true });
  if (result.exceptionDetails) throw new Error(`Lỗi JavaScript trên trang: ${result.exceptionDetails.text}`);
  return result.result.value;
}

async function navigate(cdp, url) {
  const loaded = cdp.once('Page.loadEventFired');
  await cdp.send('Page.navigate', { url });
  await loaded;
}

async function main() {
  const opts = parseArgs(process.argv.slice(2));
  const chrome = CHROME_PATHS.find((p) => fs.existsSync(p));
  if (!chrome) throw new Error('Không tìm thấy Chrome hoặc Edge');
  const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'chup-trang-web-'));
  const proc = spawn(chrome, ['--headless=new', `--remote-debugging-port=${PORT}`, `--user-data-dir=${profile}`,
    '--hide-scrollbars', `--window-size=${opts.width},900`, 'about:blank'], { stdio: 'ignore' });
  try {
    const cdp = await cdpSession(await waitForTarget());
    await cdp.send('Page.enable');
    await cdp.send('Runtime.enable');
    await cdp.send('Emulation.setDeviceMetricsOverride',
      { width: opts.width, height: 900, deviceScaleFactor: 2, mobile: false });
    await navigate(cdp, PAGE);
    if (opts.samples) {
      const text = fs.readFileSync(opts.samples, 'utf8');
      await evaluate(cdp, `localStorage.setItem(${JSON.stringify(STORAGE_KEY)},
        JSON.stringify(SoilMetrics.fromCsv(${JSON.stringify(text)})))`);
      await navigate(cdp, PAGE);
    }
    await sleep(opts.wait * 1000);
    if (opts.eval) {
      await evaluate(cdp, opts.eval);
      await sleep(1000);
    }
    const box = await evaluate(cdp, `(() => {
      const heading = ${opts.section ? `document.getElementById(${JSON.stringify(opts.section)})` : 'null'};
      const el = heading ? heading.closest('section') : document.documentElement;
      if (!el) return null;
      el.scrollIntoView();
      const r = el.getBoundingClientRect();
      return { x: r.left + window.scrollX, y: r.top + window.scrollY, width: r.width,
               height: heading ? r.height : document.documentElement.scrollHeight };
    })()`);
    if (!box) throw new Error(`Không thấy khối có tiêu đề #${opts.section}`);
    const pad = opts.section ? 12 : 0;
    const shot = await cdp.send('Page.captureScreenshot', {
      format: 'png',
      captureBeyondViewport: true,
      clip: { x: Math.max(box.x - pad, 0), y: Math.max(box.y - pad, 0), width: box.width + 2 * pad,
        height: box.height + 2 * pad, scale: 1 },
    });
    fs.mkdirSync(path.dirname(path.resolve(opts.out)), { recursive: true });
    fs.writeFileSync(opts.out, Buffer.from(shot.data, 'base64'));
    const status = await evaluate(cdp, `document.getElementById('liveMeta') ? document.getElementById('liveMeta').textContent : ''`);
    console.log(`Đã chụp ${opts.out} (${Math.round(box.width)} × ${Math.round(box.height)} px CSS). Trạng thái: ${status}`);
    await cdp.send('Browser.close').catch(() => {});
    cdp.close();
  } finally {
    proc.kill();
    await sleep(500);
    fs.rmSync(profile, { recursive: true, force: true, maxRetries: 5, retryDelay: 200 });
  }
}

main().catch((err) => {
  console.error(err.message);
  process.exit(1);
});
