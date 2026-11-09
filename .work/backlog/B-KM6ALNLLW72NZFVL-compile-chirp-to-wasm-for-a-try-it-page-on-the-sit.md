---
created: 2026-11-10
---

# B-KM6ALNLLW72NZFVL Compile chirp to wasm for a try-it page on the site

## Why
A browser page that runs chirp would let people try it before downloading. It would also give the site the full help (every topic, section and module and Janet core docstring) with the same baked-in entries and FTS5 search as `chirp --help query`, so the site needs no second search engine and no exported database that can drift. Deferred as too soon.

## Notes
A spike (Janet only, not chirp) showed it is feasible with the pinned zig 0.15.2:
- Janet 1.43's `janet.c` builds for `wasm32-wasi` and runs under Node's WASI (V8): print, try/error, PEG, fibers and the core env work; startup about 17 ms, 3.5 MB unstripped.
- setjmp/longjmp needs wasm exception handling (`-mllvm -wasm-enable-sjlj -mexception-handling`), which current Chrome, Firefox and Safari support. zig ships the headers but not wasi-libc's ~30-line `__wasm_setjmp` runtime (libc-top-half setjmp `rt.c`); take that from a pinned wasi-libc commit.
- Janet needed shims for `dup`, `tzset`, `timegm` declaration, `CLOCK_PROCESS_CPUTIME_ID`, `siginfo_t` and `tmpfile`, with `JANET_NO_EV`, `NO_NET`, `NO_THREADS`, `NO_PROCESSES`, `NO_FFI`, `NO_DYNAMIC_MODULES`. Upstream these to Janet rather than patching (D-ZBIADZDYXYPWLX5L).

Open risks, to retire first in a spike:
- The chirp image names cfunctions such as `ev/*`, `net/*` and `os/spawn` that a wasm Janet lacks, so it would not unmarshal. Likely fix: build the wasm image with the wasm Janet itself under Node, so the registries match by construction, with a smaller module set.
- SQLite with FTS5, md4c, lexbor, pcre2 (no JIT), libyaml and miniz should compile; jsec/OpenSSL and osroots drop out, taking https, `--help serve`, self-update and skill install with them.

Shape if picked up: a `wasm32-wasi` target outside the release binaries, a small hand-written browser WASI shim (stdout, args, clocks, random, in-memory fs) rather than a third-party one, one fresh instance per Run of `chirp -e '<code>'` (a REPL would need blocking stdin), smoke checks under Node in CI, `pages.yml` copying the wasm into the site, and maybe "try it" buttons on the wasm-safe examples in `help/tasks.md`. The page must say plainly what does not work (subprocesses, network, threads, persistent files). Needs decision records for the target, its image build and its module set, and touches D-ME7B5XOAG245FN65 and D-T52C67MPJMJZQ5RK.

## Prior art: danja/janey
https://github.com/danja/janey (Janet 1.37 livecoding music in the browser, published on GitHub Pages) takes the same route independently: wasm32-wasi, wasm exception handling for setjmp, no Emscripten, the same `JANET_NO_*` set. Worth taking from it:
- A reactor module (`-mexec-model=reactor`) that exports `init`/`eval`/`alloc`/`free` and keeps one Janet env alive between evals. That gives a REPL-like page without blocking stdin, which is better than one instance per Run.
- Its hand-written WASI imports are about 50 lines: `fd_write` to stdout/stderr, `fd_fdstat_get`, `clock_time_get`, empty environ and a throwing `proc_exit`, with a Proxy answering ENOSYS (EBADF for `fd_prestat_get`) for everything else. That confirms our own shim is small.
- The same `engine.js` runs in the browser and in Node tests, so CI exercises the page's real glue.
- Smaller shims: a stub `sys/wait.h` (`WEXITSTATUS`) and an empty `spawn.h` instead of a `siginfo_t` typedef, and `-std=gnu99 -D_DEFAULT_SOURCE`, which declares `timegm`. Plus `JANET_NO_CRYPTORAND`. Janet 1.43 also needs a `dup` stub, which janey's 1.37 did not.
- Link flags: `--strip-all --gc-sections -z stack-size=1048576`. With our zig that took plain Janet from 3.5 MB to 1.27 MB (about 340 KB gzipped), starting in 10 ms.
- It links wasi-sdk 25's `-lsetjmp`. Using that would add a second toolchain; vendoring wasi-libc's `rt.c` keeps us on zig alone (D-I6U4X6Q5KJD2Y4SM).

It does not help with our biggest risk: it ships no marshalled image and no third-party natives. Its workflow uses unpinned actions and deploys on every push, which our pages flow already does better.
