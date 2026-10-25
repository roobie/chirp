---
status: accepted
date: 2026-10-25
read_if:
  - changing json/decode or moving the spork pin
refs:
  - src/omap/json.c#json_omap_decode
  - test/smoke/omap.janet
---

# D-ZXXSPKUCZ4IOIQPN The ordered JSON decoder is a copy of spork's, held to it by a parity corpus

## Context
spork/json's decoder builds tables, and it offers no hook for building something else. spork is never forked (D-ZBIADZDYXYPWLX5L), so the ordered decode cannot be a change to spork's own source.

## Decision
The ordered decode is a copy of spork's C decoder that builds omaps for objects. A smoke corpus checks that it gives the same values and the same errors as spork's on every input.

## Why
Writing the decoder in Janet would be slower and would differ from spork's in error text and edge cases. A copy keeps behaviour identical, and the corpus turns any drift into a failing check rather than a silent difference. It is the cheaper debt until spork offers an option of its own.

## Consequences
When the spork pin moves, the copy has to be compared with spork's decoder and brought in step, with the corpus as the guard. The copy goes away if spork accepts an ordered option (backlog B-FIMDJ2SCVREG6KFT).
