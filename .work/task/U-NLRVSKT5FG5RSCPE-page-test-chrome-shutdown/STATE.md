---
phase: execute
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - claude
created: 2026-11-11
success_criteria:
  - The test shuts Chrome down so that no Chrome process is left writing the profile before it is removed, without retrying or ignoring the removal error
  - test/wasm/page.mjs passes 30 runs in a row locally against a built site
  - The ci run on main after the fix is green
---

# task/page-test-chrome-shutdown

## Purpose
The wasm page test fails CI with ENOTEMPTY removing Chrome's profile even after Chrome's main process exits (run 43112709457, after all 9 checks passed): Chrome's helper processes still write the profile. The release is blocked on a green CI.

## Scope
In: TODO
Out: TODO

## Context & constraints
TODO: what is already true, what must stay true, resources available.


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
