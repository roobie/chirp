---
status: accepted
date: 2026-10-24
read_if:
  - changing chirp help or what it indexes
  - shipping data files or databases inside the image
refs:
  - src/chirp/help.janet#collect
  - src/chirp/help.janet#query
  - src/chirp/main.janet#help-entries
---

# D-6MHEZUS5HUJXWV6A The help index is built at runtime in memory from baked-in text

## Context
`chirp help query` needs full-text search over the help markdown and the docstrings of every bundled module and of Janet core. It must work offline, with nothing on disk, and the image must stay reproducible (L-AGD7ZVHWYRGFIEDF).

## Decision
The image carries the help entries as plain Janet data, collected at build time in sorted order. Each query builds a throwaway in-memory SQLite FTS5 index from that data and searches it.

## Why
A prebuilt database blob in the image would tie reproducibility to SQLite's file format and page layout, and it is an opaque artefact to review. Writing an index to disk on first use would need a cache location, invalidation and permissions on every OS. The corpus is a few thousand short entries, so indexing it on each query costs little next to process start-up. Plain data also keeps the markdown moddable: adding a topic is a file drop, picked up by the next build.

## Consequences
- FTS5 is compiled into the bundled SQLite, so user scripts get it as well.
- Every query pays the indexing cost. If the corpus grows a lot, revisit this before adding a cache.
- A help file stem must not equal a bundled module name, and ids must be unique. The build fails otherwise.
