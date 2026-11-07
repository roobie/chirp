---
phase: execute
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - claude
created: 2026-11-07
success_criteria:
  - pins.jdn pins janet at e4b504568364b5aaeae2a764294b25ed84b402f4 (tag v1.43.0)
  - chirp --version reports Janet 1.43.0
  - CI builds all four targets twice with matching sha256 and every smoke check passes on each native runner
  - CHANGELOG.md Unreleased names the Janet 1.43.0 upgrade
---

# slice/janet-1-43

## Purpose
Move the janet pin from v1.42.1-85 (dc0f243b) to the v1.43.0 tag (e4b50456): upstream's fuzzing fixes to janet_verify, unmarshal, peg and string formatting, and the closure-count compile check. Ships as chirp 0.9.0.

## Scope
In: TODO
Out: TODO

## Context & constraints
TODO: what is already true, what must stay true, resources available.


## Now
Pin moved and Unreleased written; waiting for CI on the pin commit.

## Next
CI green on all four targets, then finalize the slice and cut 0.9.0 (chirp-release).

## Evidence
<!-- Proof against success_criteria: test runs, commits, measurements. -->
- Local linux-x64 build of the e4b50456 pin: chirp --version reports Janet 1.43.0-chirp-e4b50456 and every smoke check passes (the local double build ran out of disk; CI owns the hash comparison).
- Janet dc0f243b..v1.43.0 touches boot.janet only in bundle install/uninstall: no change to run-main (L-BU3RJX7SGGPRKTTA) or cli-main's REPL branch (D-MK7YV2MMJT7324MV).

## Harvest
<!-- Candidates found along the way. Finalize promotes or drops every unchecked item:
     - [ ] decision: …   → record decision
     - [ ] learning: …   → record learning
     - [ ] backlog: …    → record backlog
     - [ ] process: …    → retrospective (change the process, or drop it)
-->

## Log
- 2026-11-07 initialized
- 2026-11-07 phase initialize → execute
- 2026-11-08 pin moved to v1.43.0; local linux-x64 smoke green
