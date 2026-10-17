// Dev server for the web prototype: serves this folder and proxies /api/translate to DeepL
// (DeepL doesn't allow calls straight from the browser).
//
//   node web/server.js            -> http://localhost:5173
//
// API key: DEEPL_API_KEY env var, or a line `DEEPL_API_KEY=...` in web/.env.
// Without a key it runs in mock mode so the UI can still be iterated on.
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');

const DIR = __dirname;
const PORT = process.env.PORT || 5173;
const TYPES = { '.html': 'text/html; charset=utf-8', '.css': 'text/css', '.js': 'text/javascript' };

function loadKey() {
  if (process.env.DEEPL_API_KEY) return process.env.DEEPL_API_KEY.trim();
  try {
    const m = fs.readFileSync(path.join(DIR, '.env'), 'utf8').match(/^DEEPL_API_KEY=(.+)$/m);
    return m ? m[1].trim() : null;
  } catch {
    return null;
  }
}

const KEY = loadKey();
// Free-plan keys end in ":fx" and use a different host.
const API = KEY && KEY.endsWith(':fx') ? 'https://api-free.deepl.com' : 'https://api.deepl.com';

const CODES = ['EN', 'ES', 'CA'];

async function translate({ text, target, source }) {
  // Always send source_lang explicitly: never let DeepL auto-detect.
  if (!CODES.includes(source) || !CODES.includes(target) || source === target) {
    throw new Error(`Bad language pair: ${source} -> ${target}`);
  }
  if (!KEY) {
    await new Promise((r) => setTimeout(r, 150));
    return { text: `[${target}] ${text}`, mock: true };
  }
  const res = await fetch(`${API}/v2/translate`, {
    method: 'POST',
    headers: { Authorization: `DeepL-Auth-Key ${KEY}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      text: [text],
      target_lang: target === 'EN' ? 'EN-US' : target,
      source_lang: source,
    }),
  });
  if (!res.ok) throw new Error(`DeepL ${res.status}: ${await res.text()}`);
  return { text: (await res.json()).translations[0].text };
}

function send(res, status, type, body) {
  res.writeHead(status, { 'Content-Type': type, 'Cache-Control': 'no-store' });
  res.end(body);
}

http
  .createServer(async (req, res) => {
    if (req.method === 'POST' && req.url === '/api/translate') {
      let body = '';
      for await (const chunk of req) body += chunk;
      try {
        send(res, 200, 'application/json', JSON.stringify(await translate(JSON.parse(body))));
      } catch (e) {
        send(res, 502, 'application/json', JSON.stringify({ error: e.message }));
      }
      return;
    }

    const urlPath = req.url.split('?')[0];
    const file = path.join(DIR, urlPath === '/' ? 'index.html' : path.normalize(urlPath));
    const type = TYPES[path.extname(file)];
    if (!type || !file.startsWith(DIR + path.sep)) return send(res, 404, 'text/plain', 'Not found');
    fs.readFile(file, (err, data) =>
      err ? send(res, 404, 'text/plain', 'Not found') : send(res, 200, type, data)
    );
  })
  .listen(PORT, () => {
    console.log(`http://localhost:${PORT}  (${KEY ? 'DeepL' : 'mock mode, no DEEPL_API_KEY'})`);
  });
