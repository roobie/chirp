---
created: 2026-10-25
---

# B-JQKB2VOCY6XQW5V6 Ordered decode in the yaml module

## Why
`yaml/decode` returns tables, so the key order of a mapping is lost. Anything that rewrites a document has to keep its keys where the author put them. dev-proc's front matter is one example: it scans the text a second time to recover the order.

## Notes
- One option is a flag that returns ordered pairs, or a struct-like value that keeps insertion order, for mappings.
- spork/json has the same gap on the JSON side.
