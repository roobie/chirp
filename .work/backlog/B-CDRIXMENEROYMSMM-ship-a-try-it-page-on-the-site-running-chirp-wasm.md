---
created: 2026-11-10
---

# B-CDRIXMENEROYMSMM Ship a try-it page on the site running chirp.wasm, with the full help

## Why
Spike U-NEUAT66PBEWJRSWL said go. The repo's build already writes a reproducible bin/chirp.wasm (wasm32-wasi target, marked SPIKE in tools/build/config.jdn) that runs the real chirp image: the format modules, SQLite FTS5 and `--help query`/`--help read` with output byte-identical to the native build. A page hosting it gives people a way to try chirp before downloading, and gives the site the full help with the same search as the binary, with no second search engine and no exported database.

## Notes
Spike numbers (Node 22): 5.7 MB raw, 1.7 MB gzip; `-e` 26-32 ms plus 13 ms compile; `--help query` 80-160 ms because the FTS5 index is rebuilt per run.

Milestone-sized; likely slices:
- A reactor-style entry (as danja/janey: `-mexec-model=reactor`, exported init/eval/alloc/free) that keeps one env and one help index alive, as `--help serve` does (D-T52C67MPJMJZQ5RK); it also gives a REPL-like page with no blocking stdin.
- A small hand-written browser WASI shim (fd_write, clocks, random_get, args/environ, an in-memory fs) and the page, shared with a Node test as janey does.
- CI: build the target, a wasm smoke run that covers an error path (D-HA7ATG3IF6P73TOI), pages.yml copying chirp.wasm into the site; decide whether the wasm is built in the release workflow or by pages.
- Promote D-T6TVFVI3SEQKWL7F and D-HA7ATG3IF6P73TOI to accepted, record the target decision, and update D-ME7B5XOAG245FN65 for the page.
- Say plainly on the page what is unavailable (processes, network, threads, https, the REPL's line editor) and what persists (nothing).
- Size: try wasm-opt-free wins first (dropping unused natives from this target), and check brotli on Pages.

Depends on or pairs with B-GUXSNK7MDKPJWBUW (upstream janet wasi fixes, cryptorand), B-7WXYORKRHKWIAOVW (NOTICES) and B-RS4LEZTDHMQIMIFM (sqlite guard).
