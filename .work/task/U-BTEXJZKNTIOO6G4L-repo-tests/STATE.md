---
phase: initialize
parent: U-HM3MZPOZSVLCXGNP
owner:
  - BR
  - claude
created: 2026-11-24
success_criteria:
  - chirp tools/test.janet finds and runs every *.test.janet in the repo, the vendored dev-proc tests included, and passes from a checkout with an installed chirp in under 30 seconds.
  - Tests beside update.janet, help.janet, skills.janet and source.janet cover version order, sums parsing, trust resolution, section splitting, the query grammar, relative paths and install differences; a deliberately broken version comparison fails the driver.
  - The CI job is named checks, does not need the build job, runs a released linux-x64 chirp fetched from a :chirp pin in pins.jdn after checking its sha256, and calls the driver with no per-test list.
  - cut.janet and the chirp-release skill move the :chirp pin after a release, and the README says how to run the tests.
---

# task/repo-tests

## Purpose
Test chirp's own Janet logic in seconds, without a container build, and run the repo checks in CI without waiting for one (review finding 4; DESIGN.md of the milestone).

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
