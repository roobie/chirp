---
phase: initialize
parent: U-HM3MZPOZSVLCXGNP
owner:
  - BR
  - claude
created: 2026-11-24
success_criteria:
  - src/chirp/paths.janet holds the OS test, the directory of a path and the directory of the file being compiled, with a test beside it; ca, update, skills, repl, main and the https overlay use it and define none of their own.
  - rg shows one windows? definition and one directory-of-path helper under src/chirp; src/tar/tar.janet and the smoke scripts keep theirs.
  - Smoke is green on all four native runners, windows included.
---

# task/path-helpers

## Purpose
src/chirp has one OS test and one directory-of-path helper, so the next caller cannot pick the variant that forgets a backslash (review finding 7).

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
