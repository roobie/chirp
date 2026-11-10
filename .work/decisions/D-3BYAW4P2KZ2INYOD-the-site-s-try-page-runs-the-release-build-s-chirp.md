---
status: accepted
date: 2026-11-10
read_if:
  - changing the try page or how chirp.wasm is hosted
  - adding a WASI call chirp.wasm needs
  - releasing chirp.wasm as a download
refs:
  - site/try.mjs
  - site/try-worker.mjs
  - src/wasm/wasi.mjs
  - test/wasm/page.mjs
  - .github/workflows/pages.yml
---

# D-3BYAW4P2KZ2INYOD The site's try page runs the release build's chirp.wasm, one fresh instance per command

## Context
Slice U-AQBBSZTAPQCZKFDY. The site shows only the Markdown help topics (D-ME7B5XOAG245FN65), while the binary has the full help with search; a visitor also has no way to run chirp before downloading it. The wasm32-wasi target (D-T6TVFVI3SEQKWL7F, D-HA7ATG3IF6P73TOI) runs the real image with help output identical to native.

## Decision
The site gets a try page that loads chirp.wasm from the same CI build as the release, compiles it once and runs every script and every `--help query`/`--help read` in a fresh instance in a worker, as a command line runs a fresh process. Its WASI host, src/wasm/wasi.mjs, is written in the repo, gives only args, a clock and stdio, and is the same file the Node smoke test runs. chirp.wasm is published on the site with its own notices, not as a release file.

## Why
One instance per command keeps the page's semantics those of the CLI (`chirp -` with the script on stdin), so no code is written for the browser; a persistent instance would need a new entry point to keep one env and help index alive, for a gain of about 100 ms per search. A worker lets Stop end a script that never returns. A host of our own rather than a WASI library keeps the page free of third-party code and small enough to read; the smoke test and the page sharing it means CI checks what visitors run. Shipping the wasm on the site and not in the release keeps the release's files and self-update unchanged.

## Consequences
- Search costs a rebuild of the FTS5 index per query (80-160 ms in Node). A reactor entry point is the next step if that matters.
- Files, the network and processes raise; the page says so.
- CI needs Node 22 and Chrome (preinstalled on the runner) for the wasm job and before every Pages deploy.
