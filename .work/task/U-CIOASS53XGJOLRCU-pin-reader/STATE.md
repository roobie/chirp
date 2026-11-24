---
phase: execute
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
In: `tools/build/pin.sh`, its test, and the four places that read `pins.jdn` with `sed`.
Out: reading `pins.jdn` from Janet, which parses it; the file's layout, which stays one pin per line.

## Context & constraints
The reader stays shell: `container.sh` runs on a host with only Docker, and `container-inner.sh` runs before janet is built. The container's `sed` is busybox's. Design in the milestone's DESIGN.md (U-HM3MZPOZSVLCXGNP), finding 6.


## Next
Wait for the wave's CI run to show the checks job and all builds green, then finalize.

## Evidence
<!-- Proof against success_criteria: test runs, commits, measurements. -->
- rg 'sed -n' tools test .github finds only tools/build/pin.sh; container.sh, container-inner.sh, run-windows.sh and build-image.yml call it.
- chirp tools/build/pin.test.janet: ok (37 values), every pin and key equal to Janet's parse, a missing pin or key exits 1; it is in the CI checks list. dash and busybox sh give the same values.
- A local container build of linux-x64 with the new reader pulled the pinned build image, checked out the janet pin and went on into OpenSSL, so both in-container reads resolve.

## Harvest
<!-- Candidates found along the way. Finalize promotes or drops every unchecked item:
     - [ ] decision: …   → record decision
     - [ ] learning: …   → record learning
     - [ ] backlog: …    → record backlog
     - [ ] process: …    → retrospective (change the process, or drop it)
-->

## Log
- 2026-11-24 initialized
- 2026-11-24 phase initialize → execute
