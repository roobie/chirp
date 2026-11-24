---
phase: initialize
parent: U-HM3MZPOZSVLCXGNP
owner:
  - BR
  - claude
created: 2026-11-24
success_criteria:
  - tools/build/pin.sh <pin> <key> prints one value; container.sh, container-inner.sh, test/smoke/run-windows.sh and build-image.yml use it, and no other sed reads pins.jdn.
  - tools/build/pin.test.janet compares the helper with Janet's parse for every pin and key, and runs in the test driver or the CI checks.
  - A container build resolves the same image digest and janet commit as before.
---

# task/pin-reader

## Purpose
Read pins.jdn from shell in one tested place, so a layout change fails a test and not a build (review finding 6).

## Scope
In: TODO
Out: TODO

## Context & constraints
TODO: what is already true, what must stay true, resources available.


## Next
<!-- The cursor of the unit being worked: what is about to happen, and for a held unit the reason first.
     Rewrite it freely. A unit with open children keeps none: its present is its children. -->

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
- 2026-11-24 initialized
