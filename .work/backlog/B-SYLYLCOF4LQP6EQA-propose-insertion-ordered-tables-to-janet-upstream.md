---
created: 2026-10-25
---

# B-SYLYLCOF4LQP6EQA Propose insertion-ordered tables to Janet upstream

## Why
An ordered table in Janet core would let every encoder keep key order without a separate type, and chirp's omap could then go. janet-lang/janet#925 was closed in 2022, with bakpakin saying "For tables maybe, but for structs probably not going to happen".

## Notes
chirp's omap (src/omap/omap.h) and its use by json and yaml are the evidence to bring. Only worth raising once omap has been used for a while.
