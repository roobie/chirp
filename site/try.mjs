// The try page: compiles chirp.wasm once and runs it in a worker, for the
// script editor and for the help search. The address keeps what is shown, so
// a link opens the same thing: #code=<script> runs a script, #q=<words>
// searches the help and #read=<id> shows one entry.
const $ = (id) => document.getElementById(id);
const status = $('status');

const example = `# Bundled modules import by name, with nothing installed.
(import spork/json :as json)
(import pcre2)

(def data
  (json/decode \`{"name": "chirp", "tags": ["janet", "tls", "sqlite"]}\`))
(printf "%s has %d tags" (data "name") (length (data "tags")))

(each tag (data "tags")
  (def short (pcre2/match "^[a-z]{1,4}$" tag))
  (print "  " tag (if short "  (short)" "")))

(defn main [&]
  (print (json/encode @{"ok" true "via" "main"})))
`;

let module;
let worker;
let nextId = 0;
let current = null; // { id, onText, resolve }

function startWorker() {
  worker = new Worker(new URL('try-worker.mjs', import.meta.url), { type: 'module' });
  worker.onmessage = ({ data }) => {
    if (!current || data.id !== current.id) return;
    if (data.stream) {
      current.onText(data.stream, data.text);
    } else {
      const done = current;
      current = null;
      done.resolve({ code: data.code, ms: data.ms });
    }
  };
  worker.postMessage({ module });
}

// Runs chirp with args and stdin; onText gets each piece of output as it comes.
function chirp(args, stdin, onText) {
  return new Promise((resolve) => {
    current = { id: ++nextId, onText, resolve };
    worker.postMessage({ id: current.id, args, stdin });
  });
}

function stop() {
  if (!current) return;
  worker.terminate();
  const done = current;
  current = null;
  startWorker();
  done.resolve({ code: null, ms: 0 });
}

function busy(on) {
  for (const id of ['run', 'search', 'share']) $(id).disabled = on;
  $('stop').disabled = !on;
}

function appendTo(pre, stream, text) {
  const span = document.createElement('span');
  if (stream === 'err') span.className = 'error';
  span.textContent = text;
  pre.append(span);
}

function report(what, { code, ms }) {
  if (code === null) return `${what} stopped`;
  return `${what} exited ${code} in ${Math.round(ms)} ms`;
}

async function runScript() {
  const out = $('output');
  out.replaceChildren();
  out.hidden = false;
  out.removeAttribute('data-exit');
  busy(true);
  status.textContent = 'Running…';
  const result = await chirp(['-'], $('code').value, (s, t) => appendTo(out, s, t));
  if (!out.textContent) appendTo(out, 'out', '(no output)');
  out.dataset.exit = result.code ?? 'stopped';
  status.textContent = report('chirp -', result);
  busy(false);
}

// `chirp --help query` prints "id  title" lines, each followed by indented
// lines of matching text.
function parseResults(text) {
  const results = [];
  for (const line of text.split('\n')) {
    const m = line.match(/^(\S+)  (.*)$/);
    if (m) results.push({ id: m[1], title: m[2], snippet: '' });
    else if (results.length && line.trim()) results.at(-1).snippet += line.trim() + ' ';
  }
  return results;
}

async function capture(args) {
  const text = { out: '', err: '' };
  const result = await chirp(args, '', (s, t) => { text[s] += t; });
  return { ...result, ...text };
}

async function search(words) {
  $('q').value = words;
  busy(true);
  status.textContent = 'Searching…';
  const r = await capture(['--help', 'query', words]);
  const list = $('results');
  list.replaceChildren();
  const results = parseResults(r.out);
  for (const { id, title, snippet } of results) {
    const li = document.createElement('li');
    const a = document.createElement('a');
    a.href = `#read=${encodeURIComponent(id)}`;
    a.textContent = id;
    const small = document.createElement('small');
    small.textContent = snippet;
    li.append(a, ` ${title}`, document.createElement('br'), small);
    list.append(li);
  }
  if (!results.length) {
    const li = document.createElement('li');
    li.textContent = (r.err || r.out).trim() || 'No results.';
    list.append(li);
  }
  list.hidden = false;
  list.dataset.count = results.length;
  $('topic').hidden = true;
  status.textContent = report('chirp --help query', r);
  busy(false);
}

async function read(id) {
  busy(true);
  status.textContent = 'Reading…';
  const r = await capture(['--help', 'read', id]);
  const topic = $('topic');
  topic.replaceChildren();
  appendTo(topic, 'out', r.out);
  if (r.err) appendTo(topic, 'err', r.err);
  topic.hidden = false;
  topic.dataset.id = id;
  status.textContent = report('chirp --help read', r);
  busy(false);
  topic.scrollIntoView({ block: 'start' });
}

function fromHash() {
  const params = new URLSearchParams(location.hash.slice(1));
  if (params.has('code')) {
    $('code').value = params.get('code');
    return runScript();
  }
  if (params.has('q')) return search(params.get('q'));
  if (params.has('read')) return read(params.get('read'));
}

$('run-form').addEventListener('submit', (e) => { e.preventDefault(); runScript(); });
$('stop').addEventListener('click', stop);
$('share').addEventListener('click', async () => {
  const url = new URL(location.href);
  url.hash = new URLSearchParams({ code: $('code').value }).toString();
  history.replaceState(null, '', url);
  try {
    await navigator.clipboard.writeText(url.href);
    status.textContent = 'Link copied.';
  } catch {
    status.textContent = 'The link is in the address bar.';
  }
});
$('help-form').addEventListener('submit', (e) => {
  e.preventDefault();
  const words = $('q').value.trim();
  if (words) location.hash = new URLSearchParams({ q: words }).toString();
});
$('code').addEventListener('keydown', (e) => {
  if (e.key === 'Enter' && (e.ctrlKey || e.metaKey)) { e.preventDefault(); runScript(); }
});
addEventListener('hashchange', () => { if (!current) fromHash(); });

$('code').value = example;
try {
  const response = fetch('chirp.wasm');
  module = await WebAssembly.compileStreaming(response).catch(async () => {
    // A server that does not send application/wasm still serves the bytes.
    const r = await fetch('chirp.wasm');
    if (!r.ok) throw new Error(`chirp.wasm: HTTP ${r.status}`);
    return WebAssembly.compile(await r.arrayBuffer());
  });
  startWorker();
  const version = await capture(['--version']);
  status.textContent = `Ready: ${version.out.split(' (')[0]}. Ctrl+Enter runs the script.`;
  busy(false);
  await fromHash();
} catch (e) {
  status.textContent = `chirp could not load here: ${e.message}`;
  status.classList.add('error');
}
