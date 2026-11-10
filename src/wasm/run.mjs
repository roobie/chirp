// SPIKE (task wasm-spike): run a wasm32-wasi chirp under Node's WASI, the way
// a browser page would host it, and report timings on stderr.
// Usage: node src/wasm/run.mjs <chirp.wasm> [chirp args...]   (/tmp is preopened)
import { WASI } from 'node:wasi';
import fs from 'node:fs';

const [wasmPath, ...args] = process.argv.slice(2);
const wasi = new WASI({ version: 'preview1', args: ['chirp', ...args], env: {},
                        preopens: { '/tmp': '/tmp' }, returnOnExit: true });
const t0 = performance.now();
const mod = await WebAssembly.compile(fs.readFileSync(wasmPath));
const t1 = performance.now();
const rc = wasi.start(await WebAssembly.instantiate(mod, wasi.getImportObject()));
const t2 = performance.now();
console.error(`[exit ${rc}; compile ${(t1 - t0).toFixed(0)} ms, run ${(t2 - t1).toFixed(0)} ms]`);
process.exitCode = rc;
