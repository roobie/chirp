---
phase: execute
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - claude
created: 2026-11-11
success_criteria:
  - test/wasm/page.mjs removes Chrome's profile only after Chrome's exit event, with no retrying removal
  - The page test passes locally against a built site, run several times in a row
---

# task/wasm-page-teardown

## Purpose
TODO: why this unit exists, in one or two sentences.

## Scope
In: TODO
Out: TODO

## Context & constraints
TODO: what is already true, what must stay true, resources available.

### Origin
Promoted from backlog: B-ZRD2QVEPG55JNVHB Wait for Chrome to exit before removing its profile in the wasm page test

### Why
The wasm CI job fails now and then at teardown: the page test removes Chrome's profile directory right after killing Chrome, while Chrome is still writing to it, and the removal fails with ENOTEMPTY. It has failed main (35c02d9) and PR #18 that way; each time a rerun passed. A flaky job teaches everyone to rerun instead of read.

### Notes
- refs: test/wasm/page.mjs, the teardown after the page checks.
- Wait for the child's exit event before removing the profile; a retrying removal would hide the race rather than end it.
- Meant for a later PR that collects small fixes.


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
