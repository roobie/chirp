---
phase: initialize
parent: U-HM3MZPOZSVLCXGNP
owner:
  - BR
  - claude
created: 2026-11-24
success_criteria:
  - A local build with one :notices entry removed fails and names the pin that has no notice.
  - test/smoke/run.janet runs every .janet file beside it except itself; a new file runs without a list edit.
  - The three patches are a :patches list in config.jdn, each with its pin, file, reason and retiring backlog item, and the stub C source is a file build.janet reads.
  - CI builds all five targets twice with matching sha256, and each NOTICES file is byte-identical to the previous main build's.
---

# task/build-guards

## Purpose
Make the build and the smoke driver catch the two omissions that are silent today, and move the build's remaining inline data out of build.janet (review findings 3 and 8).

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
