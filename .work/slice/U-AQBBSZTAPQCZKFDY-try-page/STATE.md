---
phase: execute
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - pi
created: 2026-11-10
success_criteria:
  - CI builds wasm32-wasi twice and the compare job shows both copies identical; a wasm smoke job runs chirp.wasm under Node through the same WASI shim the page uses, covering a module, --help query, an error path and a stub
  - The site has a try page that runs code and searches and reads the full help through chirp.wasm, checked in headless Chrome on the built site
  - pages.yml publishes chirp.wasm from the release run's artifact and site/check.janet fails a site whose try page or wasm is missing
  - release.yml leaves the wasm out of release files; native targets build byte-identical to before
  - The wasm decisions are accepted and the target is no longer marked spike
---

# slice/try-page

## Purpose
Publish a try-it page on the GitHub Pages site that runs chirp.wasm in the browser: run Janet code, and search and read the full help with the binary's own index.

## Scope
In: TODO
Out: TODO

## Context & constraints
TODO: what is already true, what must stay true, resources available.

### Origin
Promoted from backlog: B-CDRIXMENEROYMSMM Ship a try-it page on the site running chirp.wasm, with the full help

### Why
Spike U-NEUAT66PBEWJRSWL said go. The repo's build already writes a reproducible bin/chirp.wasm (wasm32-wasi target, marked SPIKE in tools/build/config.jdn) that runs the real chirp image: the format modules, SQLite FTS5 and `--help query`/`--help read` with output byte-identical to the native build. A page hosting it gives people a way to try chirp before downloading, and gives the site the full help with the same search as the binary, with no second search engine and no exported database.

### Notes
Spike numbers (Node 22): 5.7 MB raw, 1.7 MB gzip; `-e` 26-32 ms plus 13 ms compile; `--help query` 80-160 ms because the FTS5 index is rebuilt per run.

Milestone-sized; likely slices:
- A reactor-style entry (as danja/janey: `-mexec-model=reactor`, exported init/eval/alloc/free) that keeps one env and one help index alive, as `--help serve` does (D-T52C67MPJMJZQ5RK); it also gives a REPL-like page with no blocking stdin.
- A small hand-written browser WASI shim (fd_write, clocks, random_get, args/environ, an in-memory fs) and the page, shared with a Node test as janey does.
- CI: build the target, a wasm smoke run that covers an error path (D-HA7ATG3IF6P73TOI), pages.yml copying chirp.wasm into the site; decide whether the wasm is built in the release workflow or by pages.
- Promote D-T6TVFVI3SEQKWL7F and D-HA7ATG3IF6P73TOI to accepted, record the target decision, and update D-ME7B5XOAG245FN65 for the page.
- Say plainly on the page what is unavailable (processes, network, threads, https, the REPL's line editor) and what persists (nothing).
- Size: try wasm-opt-free wins first (dropping unused natives from this target), and check brotli on Pages.

Depends on or pairs with B-GUXSNK7MDKPJWBUW (upstream janet wasi fixes, cryptorand), B-7WXYORKRHKWIAOVW (NOTICES) and B-RS4LEZTDHMQIMIFM (sqlite guard).


## Now
CI wired (build matrix, wasm job, pages, release skip); decisions accepted and D-3BYAW4P2KZ2INYOD recorded. Next: commit, push main, watch CI.

## Next
- TODO

## Evidence
<!-- Proof against success_criteria: test runs, commits, measurements. -->
- Local: wasm smoke 14/14 incl. help byte-equal to native; site build + check.janet ok (16 pages), and check fails when wasi.mjs is removed; page.mjs 9/9 in headless Chrome.
- linux-x64 NOTICES unchanged (0c154cd3...). The linux-x64 binary changed only by site/style.css, which the image embeds for --help serve (strings diff shows only the new try-page rules).

## Harvest
<!-- Candidates found along the way. Finalize promotes or drops every unchecked item:
     - [ ] decision: …   → record decision
     - [ ] learning: …   → record learning
     - [ ] backlog: …    → record backlog
     - [ ] process: …    → retrospective (change the process, or drop it)
-->

## Log
- 2026-11-10 initialized
- 2026-11-10 phase initialize → execute
- 2026-11-10 Page, WASI host and both tests written: site/try.md, try.mjs, try-worker.mjs; src/wasm/wasi.mjs replaces node:wasi in run.mjs; test/wasm/smoke.mjs (14 checks incl. byte-equal help vs native) and test/wasm/page.mjs (9 checks via CDP in headless Chrome) pass locally.
- 2026-11-10 Took in B-7WXYORKRHKWIAOVW (wasm NOTICES): the site now distributes chirp.wasm, so its notices must be right. notices.jdn: :openssl true on jsec and OpenSSL; wasi-libc, its musl, cloudlibc and emmalloc for wasm32-wasi only.
- 2026-11-10 CHANGELOG: Unreleased entry for the try page.
