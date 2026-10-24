---
phase: execute
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - claude
created: 2026-10-24
success_criteria:
  - `chirp help query '<fts5 query>'` prints ranked hits (id, title, snippet) from bundled markdown sections and from the docstrings of every bundled module, with no files on disk
  - `chirp help read <id>` prints a whole markdown file (`<file>`), one section (`<file>/<section>`) or one binding's docstring (`<module>/<name>`); an unknown id says so and exits non-zero
  - `chirp help` with no further arguments prints usage and the list of markdown topics
  - An FTS5 syntax error in a query prints a short message and exits non-zero, with no stack trace
  - FTS5 is enabled in the bundled SQLite, so user scripts can create fts5 tables too
  - The help files cover at least chirp itself, HTTPS (User-Agent, client `:ca`, Windows certificates), SQLite and TOML
  - The smoke suite checks query, read and the error path; CI is green on all four targets with the double build matching
---

# slice/bundled-help

## Purpose
Let a script author, human or agent, find out how to do something in chirp from the binary alone, offline, with a free-text search, not by knowing which module to `(doc …)`.

## Scope
In: `chirp help`, `help query`, `help read`; markdown help files in the repo, baked into the image; indexing of bundled module docstrings; FTS5 enabled in the sqlite3 native build; smoke checks; README mention.
Out: man pages, HTML output, network fetches of docs, and docs for unbundled modules.

## Context & constraints
- BR chose, on 2026-10-24, to index markdown plus docstrings, at `##`-section granularity.
- The pinned janet-lang/sqlite3 build sets no `SQLITE_ENABLE_FTS5`. natives.jdn already takes `:defines`, so enabling it is a data edit, and it moves the hashes.
- Build the index at runtime in an in-memory database from data baked into the image. The corpus is small, so this costs little, and it keeps a binary database blob out of the image and its reproducibility (L-AGD7ZVHWYRGFIEDF).
- Markdown files are content, so they are moddable. Adding one is a file drop, with no code change. File iteration is sorted, so the image stays reproducible.
- Docstrings come from the envs chirp already bundles (`src/chirp/main.janet#bundled`). Their ids are `<module>/<name>`.
- Claiming the first argument `help` means a script file named `help` must be run as `./help`. Accepted.
- The slice touches `src/chirp/main.janet`, as the spork-https overlay slice (U-O25BRXG46K5BCRAS) does. Code starts after the overlay lands.
- The HTTPS help file describes the overlay's behaviour, so it lands after the overlay too.

## Now
Initialized; waiting for the spork-https overlay to land before coding.

## Next
- Delegate: the FTS5 define, the help files, the main.janet dispatch and index, and the smoke checks. Review, build, push, CI.

## Evidence

## Harvest
- [ ] decision: the help index is built at runtime in memory from baked-in markdown and docstrings, not shipped as a prebuilt database

## Log
- 2026-10-24 initialized; corpus and granularity chosen by BR
- 2026-10-24 phase initialize → execute
