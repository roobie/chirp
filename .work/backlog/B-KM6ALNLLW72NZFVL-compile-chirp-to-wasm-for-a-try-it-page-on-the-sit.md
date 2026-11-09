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
