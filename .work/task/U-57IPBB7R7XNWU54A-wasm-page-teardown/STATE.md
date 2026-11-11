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
Done pending owner/reviewer; commit made.

## Next
Harvest/finalize by the driver.

## Evidence
<!-- Proof against success_criteria: test runs, commits, measurements. -->
- page.mjs awaits Chrome's exit event (stopChrome) before rmSync, no retry. Built chirp.wasm with tools/build/container.sh wasm32-wasi, built+checked site, ran 'CHROME=/usr/bin/chromium node test/wasm/page.mjs <site>' 8 times in a row: all 'page checks ok', exit 0, no chirp-page-* dirs left in tmp.
- On main after cherry-pick plus an already-exited guard: 3 more page.mjs runs against the built site, all 'page checks ok', no chirp-page-* left in tmp

## Harvest
<!-- Candidates found along the way. Finalize promotes or drops every unchecked item:
     - [ ] decision: …   → record decision
     - [ ] learning: …   → record learning
     - [ ] backlog: …    → record backlog
     - [ ] process: …    → retrospective (change the process, or drop it)
-->
- [x] learning (dropped, untested guess; see commit): SIGKILL of the main Chrome process may leave helper processes writing to the profile; the fallback is only reached if SIGTERM is ignored for 10s

## Log
- 2026-11-11 initialized
- 2026-11-11 phase initialize → execute
- 2026-11-11 page.mjs: stopChrome() awaits the exit event, SIGKILL fallback after 10s, then rmSync
