// Runs chirp.wasm under Node through the same WASI host as the try page, with
// this process's stdin, stdout and stderr. Run from a shell, the stdin is read
// whole first, so `chirp -` scripts work and the REPL does not.
// Usage: node src/wasm/run.mjs <chirp.wasm> [chirp args...]
import fs from 'node:fs';
import { run } from './wasi.mjs';

const [wasmPath, ...args] = process.argv.slice(2);
const module = new WebAssembly.Module(fs.readFileSync(wasmPath));
const stdin = process.stdin.isTTY ? new Uint8Array(0) : fs.readFileSync(0);
// A closed pipe, as under `| head`, ends the run quietly, like SIGPIPE would.
class Closed {}
const writer = (fd) => (b) => {
  try { fs.writeSync(fd, b); } catch (e) { if (e.code === 'EPIPE') throw new Closed(); throw e; }
};
try {
  process.exitCode = run(module, { args, stdin, stdout: writer(1), stderr: writer(2) });
} catch (e) {
  if (!(e instanceof Closed)) throw e;
}
