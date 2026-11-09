---
phase: execute
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - pi
created: 2026-11-10
success_criteria:
  - A wasm32-wasi chirp built by the repo's build (pinned zig, build host image) runs 'chirp -e (print 1)' under Node's WASI, or the spike records exactly why it cannot
  - '''chirp --help query sqlite'' prints the same ids as the native build under Node, or the blocker is recorded'
  - Evidence holds the wasm size (raw and gzip), start-up time for -e and --help query, and the list of modules and functions that are stubbed or dropped
  - The backlog item's successor (or a scrap decision) states go/no-go with the reasons; the native targets' builds are unchanged
---

# task/wasm-spike

## Purpose
Time-boxed spike (2 working days, hard stop) to retire the two biggest risks of compiling chirp to wasm for a try-it page: whether the real chirp image loads in a wasm32-wasi build made with the pinned zig, and whether SQLite FTS5 (so chirp --help query) works there. Answers go/no-go and numbers; no browser page, CI or release changes.

## Scope
In: a wasm32-wasi target driven by the repo's build, the natives that can compile for it, getting the image to load, a Node runner, measurements.
Out: the browser page and its WASI shim, a reactor API, CI, pages, release, upstreaming Janet shims, decision records beyond what the spike turns up.

## Context & constraints
Work happens on branch spike/wasm; the code may be thrown away. The native targets (D-I6U4X6Q5KJD2Y4SM, D-Q23RA2EVVN5LYCX7) must build as before. The image is written on the build host by a full-featured native Janet (tools/build/image.janet), so its cfunction references come from that Janet. Prior art: danja/janey (see Notes).

### Origin
Promoted from backlog: B-KM6ALNLLW72NZFVL Compile chirp to wasm for a try-it page on the site

### Why
A browser page that runs chirp would let people try it before downloading. It would also give the site the full help (every topic, section and module and Janet core docstring) with the same baked-in entries and FTS5 search as `chirp --help query`, so the site needs no second search engine and no exported database that can drift. Deferred as too soon.

### Notes
A spike (Janet only, not chirp) showed it is feasible with the pinned zig 0.15.2:
- Janet 1.43's `janet.c` builds for `wasm32-wasi` and runs under Node's WASI (V8): print, try/error, PEG, fibers and the core env work; startup about 17 ms, 3.5 MB unstripped.
- setjmp/longjmp needs wasm exception handling (`-mllvm -wasm-enable-sjlj -mexception-handling`), which current Chrome, Firefox and Safari support. zig ships the headers but not wasi-libc's ~30-line `__wasm_setjmp` runtime (libc-top-half setjmp `rt.c`); take that from a pinned wasi-libc commit.
- Janet needed shims for `dup`, `tzset`, `timegm` declaration, `CLOCK_PROCESS_CPUTIME_ID`, `siginfo_t` and `tmpfile`, with `JANET_NO_EV`, `NO_NET`, `NO_THREADS`, `NO_PROCESSES`, `NO_FFI`, `NO_DYNAMIC_MODULES`. Upstream these to Janet rather than patching (D-ZBIADZDYXYPWLX5L).

Open risks, to retire first in a spike:
- The chirp image names cfunctions such as `ev/*`, `net/*` and `os/spawn` that a wasm Janet lacks, so it would not unmarshal. Likely fix: build the wasm image with the wasm Janet itself under Node, so the registries match by construction, with a smaller module set.
- SQLite with FTS5, md4c, lexbor, pcre2 (no JIT), libyaml and miniz should compile; jsec/OpenSSL and osroots drop out, taking https, `--help serve`, self-update and skill install with them.

Shape if picked up: a `wasm32-wasi` target outside the release binaries, a small hand-written browser WASI shim (stdout, args, clocks, random, in-memory fs) rather than a third-party one, one fresh instance per Run of `chirp -e '<code>'` (a REPL would need blocking stdin), smoke checks under Node in CI, `pages.yml` copying the wasm into the site, and maybe "try it" buttons on the wasm-safe examples in `help/tasks.md`. The page must say plainly what does not work (subprocesses, network, threads, persistent files). Needs decision records for the target, its image build and its module set, and touches D-ME7B5XOAG245FN65 and D-T52C67MPJMJZQ5RK.

### Prior art: danja/janey
https://github.com/danja/janey (Janet 1.37 livecoding music in the browser, published on GitHub Pages) takes the same route independently: wasm32-wasi, wasm exception handling for setjmp, no Emscripten, the same `JANET_NO_*` set. Worth taking from it:
- A reactor module (`-mexec-model=reactor`) that exports `init`/`eval`/`alloc`/`free` and keeps one Janet env alive between evals. That gives a REPL-like page without blocking stdin, which is better than one instance per Run.
- Its hand-written WASI imports are about 50 lines: `fd_write` to stdout/stderr, `fd_fdstat_get`, `clock_time_get`, empty environ and a throwing `proc_exit`, with a Proxy answering ENOSYS (EBADF for `fd_prestat_get`) for everything else. That confirms our own shim is small.
- The same `engine.js` runs in the browser and in Node tests, so CI exercises the page's real glue.
- Smaller shims: a stub `sys/wait.h` (`WEXITSTATUS`) and an empty `spawn.h` instead of a `siginfo_t` typedef, and `-std=gnu99 -D_DEFAULT_SOURCE`, which declares `timegm`. Plus `JANET_NO_CRYPTORAND`. Janet 1.43 also needs a `dup` stub, which janey's 1.37 did not.
- Link flags: `--strip-all --gc-sections -z stack-size=1048576`. With our zig that took plain Janet from 3.5 MB to 1.27 MB (about 340 KB gzipped), starting in 10 ms.
- It links wasi-sdk 25's `-lsetjmp`. Using that would add a second toolchain; vendoring wasi-libc's `rt.c` keeps us on zig alone (D-I6U4X6Q5KJD2Y4SM).

It does not help with our biggest risk: it ships no marshalled image and no third-party natives. Its workflow uses unpinned actions and deploys on every push, which our pages flow already does better.


## Now
Exercise the bundled modules and the stubs under Node; measure gzip size and native timings.

## Next
- TODO

## Evidence
<!-- Proof against success_criteria: test runs, commits, measurements. -->
- Hand build in /tmp from build/skillpath (linux-x64 build of 0.10.0-dev): the unchanged image (obj/exe/release/chirp.c) + janet.c + every non-jsec native compiled by pinned zig 0.15.2 for wasm32-wasi links to a 5.7 MB wasm and runs 'chirp -e (print 1)' under Node 22 WASI in 22 ms (+9 ms compile).
- 'chirp --help query' for sqlite, certificate, dev-proc, os/spawn, 'parse yaml': output byte-identical to the native binary of the same build; 77-92 ms each under Node.
- Natives: all compile for wasm32-wasi unchanged except spork/rawterm (needs ev, termios, sigaction). sqlite3 with FTS5 compiles; its binding needs a sqlite3_load_extension stub because the amalgamation omits it on wasi.
- Image loads with stubs: 85 core cfunctions missing from a JANET_NO_EV/NET/PROCESSES/FFI/FILEWATCH/SYMLINKS/UMASK janet (ev/*, net/*, ffi/*, filewatch/*, os/spawn|execute|shell|proc-*|pipe|open|posix-*|sigaction|getpid|readlink|symlink|umask), plus every binding of jsec/* and spork/rawterm, are registered under their names as one cfunction that panics. 222 names. The image needed no change.

## Harvest
<!-- Candidates found along the way. Finalize promotes or drops every unchecked item:
     - [ ] decision: …   → record decision
     - [ ] learning: …   → record learning
     - [ ] backlog: …    → record backlog
     - [ ] process: …    → retrospective (change the process, or drop it)
-->
- [ ] - [ ] decision: missing cfunctions are stubbed under their names so the one image built on the host loads in wasm; no second image build
- [ ] - [ ] learning: a wasm janet lacks 85 core cfunctions; an image from a full janet unmarshals only if each is registered under its name

## Log
- 2026-11-10 initialized
- 2026-11-10 phase initialize → execute
