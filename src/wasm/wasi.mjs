// A WASI preview1 host for chirp.wasm, small enough to read in one sitting.
// The try page's worker and the Node smoke test both run chirp through this
// file, so what CI checks is what the page runs. It has no filesystem: chirp
// gets its arguments, environment, a clock and stdin, stdout and stderr as
// byte streams; every other call fails cleanly, as on a machine with no files.
//
//   const code = run(module, { args, env, stdin, stdout, stderr });
//
// module is a compiled WebAssembly.Module, args excludes argv[0], env is an
// object, stdin a Uint8Array, stdout and stderr are called with each
// Uint8Array chirp writes. run returns chirp's exit code.

const SUCCESS = 0, EBADF = 8, ENOENT = 44, ENOSYS = 52, ESPIPE = 70;
const CHARACTER_DEVICE = 2;
const ALL_RIGHTS = 0xffffffffffffffffn;

class Exit {
  constructor(code) { this.code = code; }
}

function utf8z(s) { return new TextEncoder().encode(s + '\0'); }

export function run(module, { args = [], env = {}, stdin = new Uint8Array(0),
                              stdout = () => {}, stderr = () => {} } = {}) {
  let memory;
  let stdinAt = 0;
  const argv = ['chirp', ...args].map(utf8z);
  const envp = Object.entries(env).map(([k, v]) => utf8z(`${k}=${v}`));
  const view = () => new DataView(memory.buffer);
  const bytes = (ptr, len) => new Uint8Array(memory.buffer, ptr, len);
  const writers = { 1: stdout, 2: stderr };

  function strings(list, ptrs, buf) {
    const v = view();
    for (const s of list) {
      v.setUint32(ptrs, buf, true);
      bytes(buf, s.length).set(s);
      ptrs += 4;
      buf += s.length;
    }
    return SUCCESS;
  }
  function sizes(list, countPtr, sizePtr) {
    const v = view();
    v.setUint32(countPtr, list.length, true);
    v.setUint32(sizePtr, list.reduce((n, s) => n + s.length, 0), true);
    return SUCCESS;
  }
  function iovecs(iovs, n) {
    const v = view();
    return Array.from({ length: n }, (_, i) =>
      [v.getUint32(iovs + 8 * i, true), v.getUint32(iovs + 8 * i + 4, true)]);
  }
  function now(id) {
    // 0 is the realtime clock; the monotonic and CPU-time clocks share one.
    const ms = id === 0 ? Date.now() : performance.timeOrigin + performance.now();
    return BigInt(Math.round(ms * 1e6));
  }
  const stdio = (fd) => fd >= 0 && fd <= 2;

  const wasi = {
    args_get: (ptrs, buf) => strings(argv, ptrs, buf),
    args_sizes_get: (count, size) => sizes(argv, count, size),
    environ_get: (ptrs, buf) => strings(envp, ptrs, buf),
    environ_sizes_get: (count, size) => sizes(envp, count, size),
    clock_time_get(id, _precision, out) {
      view().setBigUint64(out, now(id), true);
      return SUCCESS;
    },
    fd_write(fd, iovs, n, written) {
      const w = writers[fd];
      if (!w) return EBADF;
      let total = 0;
      for (const [ptr, len] of iovecs(iovs, n)) {
        w(bytes(ptr, len).slice());
        total += len;
      }
      view().setUint32(written, total, true);
      return SUCCESS;
    },
    fd_read(fd, iovs, n, read) {
      if (fd !== 0) return EBADF;
      let total = 0;
      for (const [ptr, len] of iovecs(iovs, n)) {
        const chunk = stdin.subarray(stdinAt, stdinAt + len);
        bytes(ptr, chunk.length).set(chunk);
        stdinAt += chunk.length;
        total += chunk.length;
        if (chunk.length < len) break;
      }
      view().setUint32(read, total, true);
      return SUCCESS;
    },
    fd_fdstat_get(fd, out) {
      if (!stdio(fd)) return EBADF;
      const v = view();
      v.setUint8(out, CHARACTER_DEVICE);
      v.setUint16(out + 2, 0, true);
      v.setBigUint64(out + 8, ALL_RIGHTS, true);
      v.setBigUint64(out + 16, ALL_RIGHTS, true);
      return SUCCESS;
    },
    fd_filestat_get(fd, out) {
      if (!stdio(fd)) return EBADF;
      bytes(out, 64).fill(0);
      view().setUint8(out + 16, CHARACTER_DEVICE);
      return SUCCESS;
    },
    fd_fdstat_set_flags: (fd) => (stdio(fd) ? SUCCESS : EBADF),
    fd_seek: (fd) => (stdio(fd) ? ESPIPE : EBADF),
    fd_sync: (fd) => (stdio(fd) ? SUCCESS : EBADF),
    fd_close: (fd) => (stdio(fd) ? SUCCESS : EBADF),
    // No preopened directories: libc stops looking at the first EBADF, and
    // every path then fails with ENOENT before reaching the calls below.
    fd_prestat_get: () => EBADF,
    fd_prestat_dir_name: () => EBADF,
    fd_readdir: () => EBADF,
    fd_filestat_set_size: () => EBADF,
    path_open: () => ENOENT,
    path_filestat_get: () => ENOENT,
    path_filestat_set_times: () => ENOENT,
    path_create_directory: () => ENOENT,
    path_remove_directory: () => ENOENT,
    path_unlink_file: () => ENOENT,
    path_rename: () => ENOENT,
    path_link: () => ENOENT,
    path_readlink: () => ENOENT,
    // os/sleep: chirp has no event loop in wasm, so a sleep blocks. It runs
    // in a worker on the page, where blocking freezes nothing else.
    poll_oneoff(subs, events, n, count) {
      if (n !== 1) return ENOSYS;
      const v = view();
      if (v.getUint8(subs + 8) !== 0) return ENOSYS;          // clock subscriptions only
      const timeout = Number(v.getBigUint64(subs + 24, true)) / 1e6;
      const absolute = (v.getUint16(subs + 40, true) & 1) === 1;
      const until = absolute ? Number(now(v.getUint32(subs + 16, true))) / 1e6 : Date.now() + timeout;
      while (Date.now() < until) { /* block */ }
      bytes(events, 32).fill(0);
      v.setBigUint64(events, v.getBigUint64(subs, true), true); // userdata
      v.setUint32(count, 1, true);
      return SUCCESS;
    },
    proc_exit(code) { throw new Exit(code); },
  };

  const imports = { wasi_snapshot_preview1: new Proxy(wasi, {
    // A call this host does not know fails instead of failing to link, so a
    // newer chirp.wasm still loads.
    get: (t, name) => t[name] ?? (() => ENOSYS),
  }) };
  const instance = new WebAssembly.Instance(module, imports);
  memory = instance.exports.memory;
  try {
    instance.exports._start();
    return 0;
  } catch (e) {
    if (e instanceof Exit) return e.code;
    throw e;
  }
}
