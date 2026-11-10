// Runs chirp.wasm for the try page, off the page's thread so a long script
// does not freeze it and Stop can end it. Each request gets a fresh instance
// of the one compiled module, as each command line gets a fresh process.
import { run } from './wasi.mjs';

let module;

onmessage = ({ data }) => {
  if (data.module) {
    module = data.module;
    return;
  }
  const { id, args, stdin } = data;
  const decoders = { out: new TextDecoder(), err: new TextDecoder() };
  const stream = (name) => (bytes) =>
    postMessage({ id, stream: name, text: decoders[name].decode(bytes, { stream: true }) });
  const start = performance.now();
  let code;
  try {
    code = run(module, {
      args, stdin: new TextEncoder().encode(stdin),
      stdout: stream('out'), stderr: stream('err'),
    });
  } catch (e) {
    // A trap, such as running out of memory, ends the run like a crash.
    postMessage({ id, stream: 'err', text: `chirp.wasm stopped: ${e}\n` });
    code = 134;
  }
  postMessage({ id, code, ms: performance.now() - start });
};
