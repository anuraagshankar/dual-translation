const LANGS = { EN: 'English', ES: 'Spanish', CA: 'Catalan' };
const others = (src) => Object.keys(LANGS).filter((c) => c !== src);

const ICONS = {
  copy: '<rect x="8" y="8" width="12" height="13" rx="2"/><path d="M16 8V5a2 2 0 0 0-2-2H6a2 2 0 0 0-2 2v11a2 2 0 0 0 2 2h2"/>',
  check: '<path d="M5 12.5l4.5 4.5L19 7.5"/>',
  paste: '<rect x="5" y="4" width="14" height="17" rx="2"/><rect x="9" y="2.5" width="6" height="3.5" rx="1"/>',
  close: '<path d="M6 6l12 12M18 6L6 18"/>',
};
const svg = (name) => `<svg viewBox="0 0 24 24">${ICONS[name]}</svg>`;
document.querySelectorAll('[data-icon]').forEach((el) => (el.innerHTML = svg(el.dataset.icon)));

const input = document.getElementById('input');
const clearBtn = document.getElementById('clear');
const pasteBtn = document.getElementById('paste');
const srcActions = document.getElementById('src-actions');
const pasteError = document.getElementById('paste-error');
const srcLabel = document.getElementById('src-label');
const outs = [...document.querySelectorAll('.out')].map((el) => ({
  label: el.querySelector('.label'),
  text: el.querySelector('.text'),
}));

let source = 'EN';
try {
  source = localStorage.getItem('source') || source;
} catch {}
let texts = {}; // code -> text, for all three languages once a translation has come back
let seq = 0;
let timer;
const sizeClass = (s) => (s.length > 120 ? 's' : s.length > 40 ? 'm' : '');

function render() {
  const text = input.value.trim();
  srcLabel.textContent = LANGS[source];
  input.className = sizeClass(input.value);
  clearBtn.hidden = !input.value;
  pasteBtn.hidden = !!input.value;
  if (input.value) pasteError.hidden = true;
  srcActions.hidden = !input.value;

  others(source).forEach((code, i) => {
    const out = outs[i];
    const value = text ? texts[code] || '' : '';
    out.label.textContent = LANGS[code];
    out.text.textContent = value;
    out.text.className = `text ${sizeClass(value)}`;
  });

  document.querySelectorAll('.langs button').forEach((b) => {
    b.classList.toggle('on', b.dataset.src === source);
  });
}

function autosize() {
  input.style.height = 'auto';
  input.style.height = input.scrollHeight + 'px';
}

async function api(text, target, src) {
  const res = await fetch('/api/translate', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ text, target, source: src }),
  });
  const data = await res.json();
  if (!res.ok) throw new Error(data.error);
  document.getElementById('mode').textContent = data.mock ? 'Mock mode: no DEEPL_API_KEY' : '';
  return data.text;
}

async function translate() {
  const text = input.value.trim();
  const id = ++seq;
  if (!text) return render();

  outs.forEach((o) => o.text.classList.add('stale'));
  try {
    const src = source;
    const targets = others(src);
    const rs = await Promise.all(targets.map((t) => api(text, t, src)));
    if (id !== seq) return;
    texts = { [src]: text };
    targets.forEach((t, i) => (texts[t] = rs[i]));
    render();
  } catch (e) {
    if (id !== seq) return;
    outs.forEach((o) => {
      o.text.className = 'text error';
      o.text.textContent = `Couldn't translate. ${e.message}`;
    });
  }
}

input.addEventListener('input', () => {
  autosize();
  clearTimeout(timer);
  if (!input.value.trim()) {
    seq++;
    texts = {};
    return render();
  }
  render();
  timer = setTimeout(translate, 300);
});

clearBtn.addEventListener('click', () => {
  input.value = '';
  input.dispatchEvent(new Event('input'));
  input.focus();
});

function setSource(code) {
  if (code === source) return;
  const text = input.value.trim();
  const translated = text && texts[source] === text;
  source = code;
  try {
    localStorage.setItem('source', code);
  } catch {}
  if (translated) {
    // Already have all three: just show this language's text as the input, no API call.
    input.value = texts[code];
    autosize();
    render();
  } else {
    texts = {};
    render();
    clearTimeout(timer);
    if (text) translate();
  }
}

// Browsers only let a page read the clipboard with permission, so say why when it fails.
async function readClipboard() {
  try {
    return await navigator.clipboard.readText();
  } catch (e) {
    pasteError.textContent = `The browser blocked reading the clipboard (${e.name}: ${e.message})`;
    pasteError.hidden = false;
    console.error('clipboard.readText failed', e);
    return '';
  }
}

pasteBtn.addEventListener('click', async () => {
  input.value = await readClipboard();
  input.dispatchEvent(new Event('input'));
  input.focus();
});

document.querySelector('.langs').addEventListener('click', (e) => {
  const b = e.target.closest('button');
  if (b) setSource(b.dataset.src);
});

document.querySelectorAll('.copy').forEach((btn) => {
  btn.addEventListener('click', async () => {
    const out = btn.closest('.out');
    const value = out ? out.querySelector('.text').textContent : input.value;
    if (!value) return;
    await navigator.clipboard.writeText(value);
    btn.innerHTML = svg('check');
    setTimeout(() => (btn.innerHTML = svg('copy')), 1200);
  });
});

// Widget: pill opens with the last-used language, tiles open with that language, paste opens with the clipboard.
document.getElementById('home').addEventListener('click', async (e) => {
  const el = e.target.closest('[data-open]');
  if (!el) return;
  const action = el.dataset.open;
  input.value = '';
  texts = {};
  if (LANGS[action]) setSource(action);
  if (action === 'paste') input.value = await readClipboard();
  location.hash = 'app';
  input.dispatchEvent(new Event('input'));
});

// Views
function route() {
  const view = location.hash === '#app' ? 'app' : 'home';
  document.getElementById('home').hidden = view !== 'home';
  document.getElementById('app').hidden = view !== 'app';
  document.querySelectorAll('.proto a').forEach((a) => a.classList.toggle('on', a.hash === '#' + view));
  if (view === 'app') {
    autosize();
    input.focus();
  }
}
addEventListener('hashchange', route);
route();
render();
