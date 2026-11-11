// Drives the built site's try page in headless Chrome: runs scripts, a failing
// script, a stubbed function, Stop, and a help search and read, all through
// the page's own controls and address. Exits 1 on the first failure.
// Usage: node test/wasm/page.mjs <site dir>   (CHROME names the browser)
import http from 'node:http';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawn } from 'node:child_process';
import { once } from 'node:events';

const site = path.resolve(process.argv[2] ?? 'out/site');
const types = { '.html': 'text/html', '.mjs': 'text/javascript', '.css': 'text/css',
                '.wasm': 'application/wasm' };

const server = http.createServer((req, res) => {
  const file = path.join(site, decodeURIComponent(new URL(req.url, 'http://x').pathname));
  if (!file.startsWith(site) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) {
    res.writeHead(404).end();
    return;
  }
  res.writeHead(200, { 'content-type': types[path.extname(file)] ?? 'application/octet-stream' });
  fs.createReadStream(file).pipe(res);
});
await new Promise((r) => server.listen(0, '127.0.0.1', r));
const base = `http://127.0.0.1:${server.address().port}/try.html`;

const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'chirp-page-'));
const chrome = spawn(process.env.CHROME ?? 'google-chrome',
  ['--headless=new', '--no-sandbox', '--disable-gpu', '--no-first-run',
   '--remote-debugging-port=0', `--user-data-dir=${profile}`, 'about:blank'],
  { stdio: ['ignore', 'ignore', 'pipe'] });
const browserWs = await new Promise((resolve, reject) => {
  let err = '';
  chrome.stderr.on('data', (d) => {
    err += d;
    const m = err.match(/DevTools listening on (ws:\S+)/);
    if (m) resolve(m[1]);
  });
  chrome.on('exit', (c) => reject(new Error(`chrome exited ${c}: ${err}`)));
});
const port = new URL(browserWs).port;
const target = (await (await fetch(`http://127.0.0.1:${port}/json/list`)).json())
  .find((t) => t.type === 'page');

const ws = new WebSocket(target.webSocketDebuggerUrl);
await new Promise((r) => ws.addEventListener('open', r, { once: true }));
let seq = 0;
const waiting = new Map();
ws.addEventListener('message', ({ data }) => {
  const msg = JSON.parse(data);
  if (waiting.has(msg.id)) { waiting.get(msg.id)(msg); waiting.delete(msg.id); }
});
const send = (method, params = {}) => new Promise((resolve) => {
  waiting.set(++seq, resolve);
  ws.send(JSON.stringify({ id: seq, method, params }));
});
async function evaluate(expression) {
  const r = await send('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true });
  if (r.result?.exceptionDetails) throw new Error(r.result.exceptionDetails.exception?.description);
  return r.result?.result?.value;
}
async function waitFor(expression, what, seconds = 30) {
  const until = Date.now() + seconds * 1000;
  for (;;) {
    const v = await evaluate(expression);
    if (v) return v;
    if (Date.now() > until) {
      const status = await evaluate("document.getElementById('status')?.textContent");
      throw new Error(`timed out waiting for ${what}; status: ${status}`);
    }
    await new Promise((r) => setTimeout(r, 100));
  }
}

let failed = 0;
async function check(name, fn) {
  try {
    await fn();
    console.log(`ok   ${name}`);
  } catch (e) {
    failed++;
    console.log(`FAIL ${name} - ${e.message}`);
  }
}
function expect(cond, detail) { if (!cond) throw new Error(detail); }

const ready = "!document.getElementById('run').disabled";
const output = "document.getElementById('output')";

async function open(hash) {
  await send('Page.navigate', { url: 'about:blank' });
  await send('Page.navigate', { url: `${base}${hash}` });
  await waitFor(`document.readyState === 'complete' && ${ready}`, 'the page to load');
}

async function runCode(code) {
  await open(`#${new URLSearchParams({ code })}`);
  await waitFor(`${output}.dataset.exit`, 'the run to end');
  return evaluate(`({ exit: ${output}.dataset.exit, text: ${output}.textContent,
                      err: [...${output}.querySelectorAll('.error')].map(e => e.textContent).join('') })`);
}

await check('the page loads chirp and names its version', async () => {
  await open('');
  const s = await evaluate("document.getElementById('status').textContent");
  expect(/^Ready: chirp \d/.test(s), s);
});

await check('the example script runs', async () => {
  await evaluate("document.getElementById('run').click()");
  await waitFor(`${output}.dataset.exit`, 'the run to end');
  const r = await evaluate(`({ exit: ${output}.dataset.exit, text: ${output}.textContent })`);
  expect(r.exit === '0' && r.text.includes('chirp has 3 tags') && r.text.includes('"via":"main"'), JSON.stringify(r));
});

await check('#code= runs a script with a bundled module', async () => {
  const r = await runCode('(import spork/json :as json) (print (json/encode [1 2]))');
  expect(r.exit === '0' && r.text === '[1,2]\n', JSON.stringify(r));
});

await check('an error goes to stderr with exit 1', async () => {
  const r = await runCode('(print "before") (error "boom")');
  expect(r.exit === '1' && r.text.startsWith('before\n') && r.err.includes('error: boom'), JSON.stringify(r));
});

await check('a stubbed function says it is unavailable', async () => {
  const r = await runCode('(os/spawn ["ls"])');
  expect(r.exit === '1' && r.err.includes('not available in this build of chirp'), JSON.stringify(r));
});

await check('Stop ends a script that never ends, and the next run works', async () => {
  await open('');
  await evaluate("document.getElementById('code').value = '(forever)'; document.getElementById('run').click()");
  await waitFor("!document.getElementById('stop').disabled", 'Stop to enable');
  await new Promise((r) => setTimeout(r, 300));
  await evaluate("document.getElementById('stop').click()");
  await waitFor(`${output}.dataset.exit === 'stopped'`, 'the run to stop');
  await evaluate("document.getElementById('code').value = '(print :again)'; document.getElementById('run').click()");
  await waitFor(`${output}.dataset.exit === '0'`, 'the next run');
  const text = await evaluate(`${output}.textContent`);
  expect(text === 'again\n', text);
});

await check('#q= searches the full help', async () => {
  await open('#q=read%20a%20csv');
  await waitFor("document.getElementById('results').dataset.count", 'results');
  const ids = await evaluate("[...document.querySelectorAll('#results a')].map(a => a.textContent)");
  expect(ids.includes('tasks/read-csv'), JSON.stringify(ids));
});

await check('a result opens the entry', async () => {
  await evaluate("document.querySelector('#results a').click()");
  await waitFor("document.getElementById('topic').dataset.id === 'tasks/read-csv'", 'the entry');
  const text = await evaluate("document.getElementById('topic').textContent");
  expect(text.includes('No CSV module is bundled'), text.slice(0, 200));
});

await check('#read= shows a core docstring', async () => {
  await open('#read=string/trim');
  await waitFor("document.getElementById('topic').dataset.id", 'the entry');
  const text = await evaluate("document.getElementById('topic').textContent");
  expect(text.includes('(string/trim str &opt bytes)'), text.slice(0, 200));
});

// Chrome keeps writing to its profile until it exits, so the profile can only
// be removed after the exit event. The startup handler above is already settled
// by now, so this exit is not reported as a startup failure.
async function stopChrome(graceSeconds = 10) {
  // An exit that already happened would never fire again.
  if (chrome.exitCode !== null || chrome.signalCode !== null) return;
  const exited = once(chrome, 'exit');
  chrome.kill();
  const force = setTimeout(() => {
    console.log(`chrome ignored SIGTERM for ${graceSeconds}s; sending SIGKILL`);
    chrome.kill('SIGKILL');
  }, graceSeconds * 1000);
  await exited;
  clearTimeout(force);
}

ws.close();
await stopChrome();
server.close();
fs.rmSync(profile, { recursive: true, force: true });
if (failed) {
  console.log(`${failed} page checks failed`);
  process.exit(1);
}
console.log('page checks ok');
