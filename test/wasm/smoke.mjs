// Smoke checks for chirp.wasm, run through src/wasm/wasi.mjs, the WASI host
// the try page uses. Given a native chirp of the same build, the help output
// must match it byte for byte. Exits 1 if any check fails.
// Usage: node test/wasm/smoke.mjs <chirp.wasm> [native chirp]
import fs from 'node:fs';
import { execFileSync } from 'node:child_process';
import { run } from '../../src/wasm/wasi.mjs';

const [wasmPath, native] = process.argv.slice(2);
const module = new WebAssembly.Module(fs.readFileSync(wasmPath));

function chirp(args, stdin = '') {
  const out = [], err = [];
  const code = run(module, { args, stdin: new TextEncoder().encode(stdin),
                             stdout: (b) => out.push(b), stderr: (b) => err.push(b) });
  const text = (bs) => Buffer.concat(bs).toString();
  return { code, out: text(out), err: text(err) };
}

let failed = 0;
function check(name, ok, detail) {
  if (!ok) failed++;
  console.log(`${ok ? 'ok  ' : 'FAIL'} ${name}${ok ? '' : ` - ${JSON.stringify(detail)}`}`);
}

let r = chirp(['--version']);
check('version', r.code === 0 && /^chirp \S+ \(unofficial build/.test(r.out), r);

r = chirp(['-e', '(import spork/json :as json) (print (json/encode (json/decode `{"a":[1,2]}`)))']);
check('a bundled module', r.code === 0 && r.out === '{"a":[1,2]}\n', r);

r = chirp(['-e', '(import sqlite3) (def db (sqlite3/open ":memory:")) ' +
                 '(sqlite3/eval db "create virtual table t using fts5(x)") ' +
                 '(sqlite3/eval db "insert into t values (\'hello wasm\')") ' +
                 '(print ((first (sqlite3/eval db "select x from t where t match \'wasm\'")) :x))']);
check('sqlite with fts5', r.code === 0 && r.out === 'hello wasm\n', r);

r = chirp(['-'], '(print "from stdin") (defn main [&] (print "main") (os/exit 3))');
check('a script on stdin, with main and an exit code', r.code === 3 && r.out === 'from stdin\nmain\n', r);

r = chirp(['-e', '(print "before") (error "boom")']);
check('an error exits 1 with a stack trace', r.code === 1 && r.out === 'before\n' && r.err.startsWith('error: boom\n'), r);

r = chirp(['-e', '(os/spawn ["ls"])']);
check('a stubbed core function raises', r.code === 1 && r.err.includes('not available in this build of chirp'), r);

r = chirp(['-e', '(import jsec/crypto) (crypto/digest :sha256 "x")']);
check('a stubbed native raises', r.code === 1 && r.err.includes('not available in this build of chirp'), r);

r = chirp(['-e', '(print (first (protect (slurp "README.md"))))']);
check('files are absent, not a crash', r.code === 0 && r.out.startsWith('false'), r);

r = chirp(['-e', '(def t (os/clock)) (os/sleep 0.05) (print (>= (- (os/clock) t) 0.04))']);
check('os/sleep sleeps', r.code === 0 && r.out === 'true\n', r);

r = chirp(['--help', 'query', 'sqlite']);
check('help query', r.code === 0 && r.out.startsWith('sqlite  SQLite\n'), r);

if (native) {
  for (const args of [['--help', 'query', 'sqlite'], ['--help', 'query', 'read a csv'],
                      ['--help', 'read', 'os/spawn'], ['--help', 'read', 'tasks']]) {
    const w = chirp(args);
    const n = execFileSync(native, args).toString();
    check(`same as native: ${args.join(' ')}`, w.code === 0 && w.out === n, { wasm: w.out.slice(0, 200), native: n.slice(0, 200) });
  }
}

if (failed) {
  console.log(`${failed} wasm smoke checks failed`);
  process.exit(1);
}
console.log('wasm smoke ok');
