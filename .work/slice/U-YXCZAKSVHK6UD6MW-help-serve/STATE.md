---
phase: execute
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - claude
created: 2026-10-29
success_criteria:
  - chirp --help serve [--host H] [--port N] serves the baked-in help on 127.0.0.1:3111 (or H:N) with nothing on disk, and prints the URL
  - the page lists the topics, searches as you type (and as a plain form without JS), and renders any entry, with links between entries staying on the server
  - pages use the site's stylesheet, baked into the binary
  - user text (queries, snippets, docstrings) is HTML-escaped; unknown paths and ids get 404
  - a smoke test starts the server on a free port and checks index, search, read, the stylesheet and a 404, and passes on a CI build
  - chirp -h, the help topic and CHANGELOG mention it
---

# slice/help-serve

## Purpose
GitHub issue #1: browse and search chirp's offline help in a browser, served by chirp itself from the text already in the binary.

## Scope
In: `chirp --help serve [--host H] [--port N]`; the in-memory FTS5 index built once per server; HTML from md4c; site/style.css baked in and shared; smoke test, help, changelog.
Out: opening a browser; the FTS5 hyphen problem (B-F3UWCYQL25PUZXO2); changing the static site's own build.

## Context & constraints
- BR (2026-10-29): 127.0.0.1:3111 default, `--port` overrides; later added `--host` so binding 0.0.0.0 is an explicit choice; server-rendered HTML with a small inline live search that degrades to a form; share site/style.css.
- Subcommand form follows D-AS3ZNOCRFCSXZSED: a word after `--help`.
- D-6MHEZUS5HUJXWV6A: the index is built at runtime from baked-in data. A server builds it once at start, not per query.
- Host, port and the stylesheet path are data in chirp.jdn; the stylesheet is read at build time like help topics (reproducible, sorted, nothing read at runtime).

## Now
Implemented and reviewed; pushing to CI.

## Next
- CI green on all targets, install, milestone 0.5.0 + comment on #1, finalize

## Evidence
- local linux-x64 build: `smoke: all checks passed`, including help-serve: index, search, fragment, read (topic, section → topic link, docstring, percent-encoded id), 400 on a bad FTS5 query, escaped `<script>`, style.css as text/css, 404s, bad options exit 2, a taken port exits 1
- by hand: `--host 0.0.0.0 --port 3999` prints its URL, serves /read/https 200, and echoes `<script>` escaped
- `chirp site/build.janet` still builds every page with the extended style.css

## Harvest
- [ ] decision: serve builds the FTS5 index once per process and shares help.janet's search; pages reuse site/style.css baked in at build time
- [ ] learning: spork's http/server sets SO_REUSEPORT, so a second server on a taken port binds silently; serve uses net/server with no-reuse to fail loudly
- [ ] learning: spork/http drops the connection when a handler throws; wrap routing in protect to answer 500
- [ ] backlog: search snippets show raw markdown (fences, newlines); render or strip them for the web UI

## Log
- 2026-10-29 initialized
- 2026-10-29 phase initialize → execute
