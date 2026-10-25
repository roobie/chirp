---
status: accepted
date: 2026-10-25
read_if:
  - changing how find matches or ranks records
refs:
  - .claude/skills/dev-proc/scripts/find.janet#find-records
---

# D-SEP44EOKHRFGMAWT find ranks records with SQLite FTS5

## Context
The Node find had its own stopwords, a light stemmer, a synonym table and inverse-frequency scoring. Porting it would have meant owning a small search engine, and chirp already bundles FTS5 (BR, 2026-10-25).

## Decision
find indexes titles and `read_if` cues in an in-memory FTS5 table and ranks the hits by bm25. Hits on a cue count double hits on a title.

## Why
The Porter stemmer and bm25 do what the hand-written pieces approximated, and they are maintained upstream. Hand-tuning the old scorer was the other option. Its synonym table had a single entry, and it showed how much hand-tuning would cost to keep going. Only the output format had to stay the same, because callers read that format, not the ranking.

## Consequences
Rankings differ from Node's. On this repo the top hits agree for most queries and differ for some broad ones. Query words are matched as quoted terms, so FTS syntax in the input never reaches the engine. FTS5 has no stopword list, so a short one is kept beside the query code.
