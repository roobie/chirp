---
phase: execute
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - claude
created: 2026-11-11
success_criteria:
  - The path by which a config.jdn edit the image never reads changes the linux-x64 binary is named, with a reproduction (before/after hashes and the differing bytes or image entries)
  - Either a fix lands so such an edit leaves the binary's sha256 unchanged (shown by two builds), or the cause is recorded as a learning and the fix is gated on the owner with the evidence
---

# task/config-jdn-hash-input

## Purpose
TODO: why this unit exists, in one or two sentences.

## Scope
In: TODO
Out: TODO

## Context & constraints
TODO: what is already true, what must stay true, resources available.

### Origin
Promoted from backlog: B-U6C4GF5ICCTMVVBL Find how config.jdn content reaches the image

### Why
Adding a key to tools/build/config.jdn that the image never reads moved the linux-x64 hash (484a2667… → 9714e68b…). Builds still agree with each other, so reproducibility holds, but an unexplained input to the image is the kind of thing that later breaks it. Until it is understood, any config.jdn edit is a hash change, and releases from before and after it can't be compared.

### Notes
- tools/build/image.janet parses config.jdn in the image-building process. A likely cause is that the parsed data's allocation shifts the hash order of something that does get marshalled. L-ZI52YKRRPPUHTQEI shows the same kind of effect through the gensym counter, but parsing data calls no gensym, so that alone does not explain it.
- Repro: add an unused key to config.jdn, build linux-x64, and compare.


## Now
TODO: what is in flight right now. Rewrite this freely; it is a cursor, not a history.

## Next
- TODO

## Evidence
<!-- Proof against success_criteria: test runs, commits, measurements. -->

## Harvest
<!-- Candidates found along the way. Finalize promotes or drops every unchecked item:
     - [ ] decision: …   → record decision
     - [ ] learning: …   → record learning
     - [ ] backlog: …    → record backlog
     - [ ] process: …    → retrospective (change the process, or drop it)
-->

## Log
- 2026-11-11 initialized
- 2026-11-11 phase initialize → execute
