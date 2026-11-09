---
phase: execute
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - pi
created: 2026-11-09
success_criteria:
  - '`(doc tarray/new)` in chirp says what offset, size and stride count, that a buffer or string is copied while a ta/buffer or typed array is shared, and the byte order'
  - the tasks topic has a parse-a-binary-header example that runs in the tasks smoke check
  - an upstream issue text for janet-lang/spork is drafted for BR (the docstring, and the offset over a typed array that starts past its first byte)
---

# task/tarray-docs

## Purpose
`(doc tarray/new)` says only 'Create new typed array.' (#9); what offset counts and whether the buffer is shared took probing.

## Scope
In: a doc-only overlay of spork/tarray `new` (D-DBGBXVNNTRBBRHMQ), the tasks topic's binary-data section, an upstream issue draft.
Out: fixing upstream's offset arithmetic over a view (a behaviour change; upstream's to fix).

## Context & constraints
Pinned spork tarray.c equals master. Verified on 0.10.0-dev: offset is bytes over a buffer, string or ta/buffer, elements of the parent's type over a typed array; a buffer or string is memcpy'd; byte order is the host's; a typed array over another that starts past its first byte fails ('< -1 required', sign reversed in cfun_typed_array_new).

### Origin
Promoted from backlog: B-IURYPGJRZ7Z2SMYA Document that tarray/new's offset counts bytes (#9)

### Why
GitHub #9 (usage-feedback): `(doc tarray/new)` says only "Create new typed array." and does not say that `offset` counts bytes while size and stride count elements, or that a plain buffer (from `slurp`, say) works as the backing store. Parsing a binary header took trial and error.

### Notes
- The docstring is spork's (src/tarray.c), and chirp does not patch docs into pins, so the docstring fix belongs upstream at janet-lang/spork; the repo's token cannot file there, so BR files it.
- chirp can help on its own side with a help topic (src/chirp/help/) on reading binary data: tarray over a slurped buffer, byte offsets, endianness, and `buffer/` and `int/` helpers. The issue suggests a "parse a binary header" example.


## Now
Pushed; waiting for CI.

## Next
- tasks example, CHANGELOG, upstream draft, finalize

## Evidence
<!-- Proof against success_criteria: test runs, commits, measurements. -->
- linux-x64 build: (doc tarray/new) prints the overlay docstring; --help read spork/tarray/new has 'offset counts bytes' (help smoke asserts it); tasks smoke runs 29 examples incl. the GLB header ('version 2, 1024 bytes'); --help query 'binary header' lists tasks/work-with-binary-data first. Smoke run passes.

## Harvest
<!-- Candidates found along the way. Finalize promotes or drops every unchecked item:
     - [ ] decision: …   → record decision
     - [ ] learning: …   → record learning
     - [ ] backlog: …    → record backlog
     - [ ] process: …    → retrospective (change the process, or drop it)
-->

## Log
- 2026-11-09 initialized
- 2026-11-09 phase initialize → execute
